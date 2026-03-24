---
noteId: "de6dc710260e11f1b82a415705fd6862"
tags: []

---

# CHAPITRE 4 — LE DATA LAYER (La Couche Technique)

> Le Data Layer est la couche qui PARLE a Supabase. Elle convertit
> les donnees JSON en objets Dart (Models) et implemente les contrats
> definis par le Domain Layer (Repository implementations).

---

## 4.1 OBJECTIF

A la fin de ce chapitre, nous aurons :
- 2 Models : CardModel, CardTrioModel (entites + serialisation JSON)
- 3 Repository implementations : carte, trio, session
- 2 Datasources : authentification, signalement images
- 1 Service : generation des distracteurs
- La couche Data complete qui connecte le Domain a Supabase

---

## 4.2 LE FLUX DE DONNEES

```
SUPABASE (PostgreSQL)
       |
       | JSON brut (Map<String, dynamic>)
       v
  DATASOURCE   <-- Appels API bruts
       |
       | JSON brut
       v
  REPOSITORY IMPL   <-- Conversion JSON -> Model
       |
       | CardModel (= CardEntity)
       v
    USECASE   <-- Logique metier
       |
       | CardEntity
       v
  PROVIDER   <-- Gestion d'etat
       |
       | CardEntity
       v
    WIDGET   <-- Affichage
```

Le JSON remonte de Supabase, est converti en objet Dart dans le Repository,
et arrive au Widget sous forme d'entite propre.

---

## 4.3 LES MODELS — Entity + JSON

### Pourquoi un Model separe de l'Entity ?

| Aspect | Entity (Domain) | Model (Data) |
|--------|-----------------|--------------|
| Couche | Domain | Data |
| Connait JSON ? | NON | OUI |
| Connait Supabase ? | NON | NON (mais connait le format) |
| fromJson() ? | NON | OUI |
| toJson() ? | NON | OUI |
| Heritage | Classe de base | Herite de l'Entity |

### CardModel — Concepts cles

**Heritage** : `class CardModel extends CardEntity`
- CardModel EST un CardEntity (substitution de Liskov)
- Partout ou on attend un CardEntity, on peut passer un CardModel

**Factory constructor** : `factory CardModel.fromJson(Map<String, dynamic> json)`
- Cree une instance a partir d'un dictionnaire JSON
- Gere les conversions de types :
  - `String -> enum` : `CardType.values.byName(json['card_type'])`
  - `List<dynamic> -> List<String>` : `List<String>.from(json['theme_tags'] ?? [])`
  - `num -> double` : `(json['difficulty_score'] ?? 0.5).toDouble()`
  - `null -> valeur par defaut` : operateur `??`

**Convention de nommage** :
- PostgreSQL : `snake_case` (image_path, card_type)
- Dart : `camelCase` (imagePath, cardType)
- La conversion se fait dans fromJson/toJson

### Exemple de conversion complete

```
JSON Supabase                        Objet Dart
-----------                          ----------
{                                    CardModel(
  "id": "550e...",            ->       id: "550e...",
  "card_type": "emettrice",   ->       cardType: CardType.emettrice,
  "distance_level": 1,        ->       distanceLevel: 1,
  "image_path": "emettrices/  ->       imagePath: "emettrices/
    savane/lion_base.webp",               savane/lion_base.webp",
  "theme_tags": ["animal",   ->       themeTags: ["animal",
    "lion"],                              "lion"],
  "difficulty_score": 0.5     ->       difficultyScore: 0.5,
  "is_active": true           ->       isActive: true,
}                                    )
```

---

## 4.4 LES REPOSITORY IMPLEMENTATIONS

### Le pattern implements

```dart
// Interface (Domain) : QUOI faire
abstract class CardRepository {
  Future<CardEntity> getCardById(String id);
}

// Implementation (Data) : COMMENT le faire
class CardRepositoryImpl implements CardRepository {
  @override
  Future<CardEntity> getCardById(String id) async {
    final json = await supabase.from('cards').select().eq('id', id).single();
    return CardModel.fromJson(json);
  }
}
```

### Le SDK Supabase — Requetes chainables

Chaque methode du SDK retourne un builder qu'on enchaine :

| Methode SDK | SQL equivalent | Exemple |
|-------------|---------------|---------|
| `.from('table')` | FROM table | `.from('cards')` |
| `.select()` | SELECT * | `.select('id, image_path')` |
| `.insert({...})` | INSERT INTO | `.insert({'name': 'lion'})` |
| `.update({...})` | UPDATE SET | `.update({'score': 100})` |
| `.eq('col', val)` | WHERE col = val | `.eq('card_type', 'cable')` |
| `.neq('col', val)` | WHERE col != val | `.neq('id', 'uuid')` |
| `.not('col', 'in', list)` | WHERE col NOT IN | `.not('id', 'in', ids)` |
| `.limit(n)` | LIMIT n | `.limit(10)` |
| `.single()` | (1 resultat) | erreur si 0 ou 2+ |
| `.maybeSingle()` | (0 ou 1) | null si 0 |

### Execution en parallele avec Future.wait

```dart
// LENT : sequentiel (300ms)
final e = await getCardById(emettriceId);  // 100ms
final c = await getCardById(cableId);      // 100ms
final r = await getCardById(receptriceId); // 100ms

// RAPIDE : parallele (100ms)
final results = await Future.wait([
  getCardById(emettriceId),   // [0]
  getCardById(cableId),       // [1]
  getCardById(receptriceId),  // [2]
]);
```

---

## 4.5 LES DATASOURCES

### SupabaseAuthDatasource

Gere l'authentification complete :

| Methode | API Supabase | Retour |
|---------|-------------|--------|
| `signUp()` | POST /auth/v1/signup | AuthResponse (user, session=null) |
| `signIn()` | POST /auth/v1/token | AuthResponse (user, session+JWT) |
| `signInWithGoogle()` | OAuth redirect | void (session via callback) |
| `signOut()` | POST /auth/v1/logout | void |
| `getProfile()` | SELECT user_profiles | Map ou null |
| `createProfile()` | INSERT user_profiles | Map |
| `updateProfile()` | UPDATE user_profiles | void |

### Gestion des erreurs Supabase

```dart
try {
  await supabase.auth.signInWithPassword(...);
} on AuthException catch (e) {
  // "on AuthException" : n'attrape QUE ce type
  // e.message contient le message d'erreur Supabase
  if (e.message.contains('Invalid login credentials')) {
    throw AuthFailure.invalidCredentials();
  }
}
```

`on Type catch (e)` vs `catch (e)` :
- `on Type catch (e)` : n'attrape que les exceptions du type specifie
- `catch (e)` : attrape TOUTES les exceptions

---

## 4.6 LE SERVICE DISTRACTEUR

Le DistractorService encapsule la logique de selection des 9 images incorrectes.

### Regles par type de carte masquee

| Carte masquee | Distracteurs | Priorite |
|---------------|-------------|----------|
| Receptrice (config A) | 9 autres Receptrices | Meme distance, memes tags |
| Cable (config B) | 9 autres Cables | Meme categorie, puis autres |
| Emettrice (config C) | 9 autres Emettrices | Memes tags partiels |

### Strategie pour les Cables

```
Total voulu : 9 distracteurs

Etape 1 : 4-5 de la MEME categorie (ex: geometrique)
  -> miroir_v, rotation_90, rotation_180, ... (visuellement proches)

Etape 2 : 4-5 d'AUTRES categories (couleur, dimension, complexe)
  -> teinte_rouge, agrandissement_2x, ... (visuellement differents)

Resultat : melange de distracteurs proches et eloignes
  -> Defi equilibre pour le joueur
```

---

## 4.7 FICHIERS CREES

```
lib/data/
  models/
    card_model.dart                     ✅  CardEntity + fromJson/toJson
    card_trio_model.dart                ✅  CardTrioEntity + fromJson/toJson
  repositories/
    card_repository_impl.dart           ✅  Implementation Supabase (cards)
    card_trio_repository_impl.dart      ✅  Implementation Supabase (trios)
    game_session_repository_impl.dart   ✅  Implementation Supabase (sessions)
  datasources/
    supabase_auth_datasource.dart       ✅  Auth + profil
    supabase_card_datasource.dart       ✅  Signalement images
  services/
    distractor_service.dart             ✅  Generation des distracteurs
```

**Resultat `flutter analyze` : No issues found!**

---

## 4.8 RECAPITULATIF

### Concepts Dart appris

| Concept | Utilisation |
|---------|-------------|
| `extends` (heritage) | CardModel extends CardEntity |
| `implements` (interface) | CardRepositoryImpl implements CardRepository |
| `factory` constructor | CardModel.fromJson() |
| `super.xxx` | Passer des parametres au constructeur parent |
| `@override` | Reimplementer une methode d'interface |
| `.map().toList()` | Transformer une liste |
| `~/` (division entiere) | 9 ~/ 2 = 4 |
| `!` (null assertion) | Affirmer qu'une valeur nullable n'est pas null |
| `on Type catch (e)` | Attraper un type specifique d'exception |
| `try/catch(_)` silencieux | Ignorer volontairement une erreur |
| Spread `[...list1, ...list2]` | Fusionner deux listes |
| `..shuffle()` (cascade) | Melanger et retourner la liste |
| `.maybeSingle()` | 0 ou 1 resultat (null si 0) |
| `.neq()` | Filtre de non-egalite SQL |
| `.toIso8601String()` | Date -> format ISO standard |

### Prochain chapitre

**Chapitre 5 : Authentification** — Nous allons creer :
- Le provider Riverpod d'authentification (AuthNotifier)
- La page de connexion/inscription (AuthPage)
- La page d'activation du code (ActivationPage)
- Le flux complet : inscription -> verification email -> code -> menu
