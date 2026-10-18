// =============================================================
// FICHIER : site_provider.dart
// ROLE    : Etat de l'ecran "Vitrine" (brouillon + version publiee)
// =============================================================
//
// DEUX VERSIONS DU MEME DOCUMENT
// ------------------------------
// L'ecran manipule un BROUILLON : chaque frappe le modifie, mais
// rien ne part au serveur avant "Publier". A cote, on garde
// l'empreinte de la derniere version PUBLIEE (son JSON serialise).
//
// "Modifications non publiees" = les deux empreintes different.
// Comparer les JSON plutot que suivre un drapeau "sale" a un
// avantage : taper un caractere puis l'effacer ramene l'indicateur
// a l'etat propre, ce qu'un drapeau ne saurait pas faire.
//
// POURQUOI LE BROUILLON VIT ICI ET PAS DANS LA PAGE
// -------------------------------------------------
// La galerie se modifie depuis plusieurs endroits (televersement,
// feuille "ajouter depuis un jeu", boutons monter/descendre). Les
// centraliser dans le notifier evite de faire circuler des
// callbacks dans tous les sens.
// =============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';
import '../../domain/entities/site_content.dart';
import 'repositories_provider.dart';

class EtatVitrine {
  /// Le document en cours d'edition.
  final ContenuAccueil brouillon;

  /// Empreinte JSON de la derniere version publiee.
  final String empreintePubliee;

  /// True pendant un PUT : desactive le bouton Publier.
  final bool enPublication;

  /// True pendant un televersement d'image.
  final bool enTeleversement;

  const EtatVitrine({
    required this.brouillon,
    required this.empreintePubliee,
    this.enPublication = false,
    this.enTeleversement = false,
  });

  /// True si le brouillon differe de ce qui est en ligne.
  bool get modifie => _empreinte(brouillon) != empreintePubliee;

  EtatVitrine copyWith({
    ContenuAccueil? brouillon,
    String? empreintePubliee,
    bool? enPublication,
    bool? enTeleversement,
  }) {
    return EtatVitrine(
      brouillon: brouillon ?? this.brouillon,
      empreintePubliee: empreintePubliee ?? this.empreintePubliee,
      enPublication: enPublication ?? this.enPublication,
      enTeleversement: enTeleversement ?? this.enTeleversement,
    );
  }
}

// L'empreinte passe par toJson, donc ignore les espaces en trop et
// les champs vides : deux documents equivalents POUR LA VITRINE ont
// la meme empreinte.
String _empreinte(ContenuAccueil c) => jsonEncode(c.toJson());

class VitrineNotifier extends AsyncNotifier<EtatVitrine> {
  // Compteur pour les idLocal des images ajoutees dans cette session.
  int _seq = 0;

  @override
  Future<EtatVitrine> build() async {
    final res = await ref.read(siteRepositoryProvider).charger();
    return switch (res) {
      Ok(value: final c) =>
        EtatVitrine(brouillon: c, empreintePubliee: _empreinte(c)),
      // AsyncNotifier bascule en erreur : la page affiche le message
      // et un bouton Reessayer.
      Err(failure: final f) => throw Exception(f.message),
    };
  }

  /// Recharge depuis le serveur (abandonne le brouillon).
  Future<void> recharger() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  // Applique une transformation au brouillon courant.
  void _maj(ContenuAccueil Function(ContenuAccueil) f) {
    final courant = state.valueOrNull;
    if (courant == null) return;
    state = AsyncData(courant.copyWith(brouillon: f(courant.brouillon)));
  }

  // -----------------------------------------------------------
  // TEXTES
  // -----------------------------------------------------------

  void majHero(String cle, String valeur) => _maj(
        (c) => c.copyWith(hero: {...c.hero, cle: valeur}),
      );

  void majSection(String section, String cle, String valeur) => _maj((c) {
        final champs = {...?c.sections[section], cle: valeur};
        return c.copyWith(sections: {...c.sections, section: champs});
      });

  // -----------------------------------------------------------
  // GALERIE
  // -----------------------------------------------------------

  /// Nombre de places encore libres dans la galerie.
  int get placesLibres {
    final n = state.valueOrNull?.brouillon.galerie.length ?? 0;
    return kGalerieMax - n;
  }

  /// Ajoute des images en fin de galerie, dans la limite des places.
  /// Renvoie le nombre d'images reellement ajoutees.
  int ajouterImages(List<({String url, String nom, String code})> images) {
    final aAjouter = images.take(placesLibres).toList();
    if (aAjouter.isEmpty) return 0;
    _maj((c) => c.copyWith(galerie: [
          ...c.galerie,
          for (final i in aAjouter)
            ElementGalerie(
              idLocal: 'loc-${_seq++}',
              imageUrl: i.url,
              // Les libelles des cartes peuvent depasser les limites
              // du contrat : on tronque plutot que de faire echouer
              // la publication sur une image qu'on vient d'ajouter.
              nom: _tronquer(i.nom, kNomMax),
              code: _tronquer(i.code, kCodeMax),
            ),
        ]));
    return aAjouter.length;
  }

  void majElement(String idLocal, {String? nom, String? code}) => _maj(
        (c) => c.copyWith(galerie: [
          for (final g in c.galerie)
            g.idLocal == idLocal ? g.copyWith(nom: nom, code: code) : g,
        ]),
      );

  void supprimerElement(String idLocal) => _maj(
        (c) => c.copyWith(
          galerie: c.galerie.where((g) => g.idLocal != idLocal).toList(),
        ),
      );

  /// Deplace un element de [delta] positions (-1 = monter, +1 = descendre).
  void deplacerElement(String idLocal, int delta) => _maj((c) {
        final liste = [...c.galerie];
        final i = liste.indexWhere((g) => g.idLocal == idLocal);
        final j = i + delta;
        if (i < 0 || j < 0 || j >= liste.length) return c;
        final element = liste.removeAt(i);
        liste.insert(j, element);
        return c.copyWith(galerie: liste);
      });

  /// Televerse une image puis l'ajoute a la galerie.
  /// Renvoie null si tout s'est bien passe, sinon le message d'erreur.
  Future<String?> televerser({
    required Uint8List octets,
    required String nomFichier,
    required String typeMime,
  }) async {
    final courant = state.valueOrNull;
    if (courant == null) return 'Contenu non chargé';
    if (placesLibres <= 0) return 'La galerie est pleine ($kGalerieMax images).';

    state = AsyncData(courant.copyWith(enTeleversement: true));
    final res = await ref.read(siteRepositoryProvider).televerserImage(
          octets: octets,
          nomFichier: nomFichier,
          typeMime: typeMime,
        );
    // On relit l'etat : l'administrateur a pu taper pendant l'envoi.
    final apres = state.valueOrNull ?? courant;
    state = AsyncData(apres.copyWith(enTeleversement: false));

    switch (res) {
      case Ok(value: final url):
        ajouterImages([(url: url, nom: '', code: '')]);
        return null;
      case Err(failure: final f):
        return f.message;
    }
  }

  // -----------------------------------------------------------
  // PUBLICATION
  // -----------------------------------------------------------

  /// Publie le brouillon. Renvoie null si succes, sinon le message.
  Future<String?> publier() async {
    final courant = state.valueOrNull;
    if (courant == null) return 'Contenu non chargé';

    state = AsyncData(courant.copyWith(enPublication: true));
    final res = await ref.read(siteRepositoryProvider).publier(courant.brouillon);
    final apres = state.valueOrNull ?? courant;

    switch (res) {
      case Ok(value: final publie):
        // On garde le brouillon tel quel (et ses idLocal, donc les
        // champs de saisie ouverts) ; seule la reference change, et
        // la date de publication est reprise du serveur.
        state = AsyncData(EtatVitrine(
          brouillon: apres.brouillon.copyWith(majLe: publie.majLe),
          empreintePubliee: _empreinte(publie),
        ));
        return null;
      case Err(failure: final f):
        state = AsyncData(apres.copyWith(enPublication: false));
        return f.message;
    }
  }
}

String _tronquer(String s, int max) => s.length <= max ? s : s.substring(0, max);

final vitrineProvider =
    AsyncNotifierProvider<VitrineNotifier, EtatVitrine>(VitrineNotifier.new);
