// =============================================================
// FICHIER : lib/presentation/wireframes/t_collective_mode_page.dart
// ROLE   : Mode collectif - verification de trios par numero
// COUCHE : Presentation > Wireframes
// =============================================================
//
// QU'EST-CE QUE LE MODE COLLECTIF ?
// ---------------------------------
// Outil de verification dans le jeu physique :
// le joueur saisit (ou scanne) le numero d'un trio et l'app
// verifie si le trio est valide via la fonction SQL
// verify_collective_trio().
//
// Utile lors des parties en groupe autour de la table pour
// resoudre les disputes ("est-ce un trio valide ?").
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:trialgo/core/network/supabase_client.dart';
import 'package:trialgo/presentation/providers/profile_provider.dart';

class TCollectiveModePage extends ConsumerStatefulWidget {
  const TCollectiveModePage({super.key});

  @override
  ConsumerState<TCollectiveModePage> createState() =>
      _TCollectiveModePageState();
}

class _TCollectiveModePageState extends ConsumerState<TCollectiveModePage> {
  final _numberController = TextEditingController();

  bool _verifying = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  // =============================================================
  // VERIFICATION VIA RPC
  // =============================================================
  // Appelle verify_collective_trio(p_game_id, p_node_index).
  // La fonction SQL retourne :
  //   { exists, node_index, depth, emettrice_label, cable_label, receptrice_label }
  // =============================================================

  Future<void> _verify() async {
    final text = _numberController.text.trim();
    final index = int.tryParse(text);
    if (index == null) {
      setState(() {
        _error = 'Veuillez entrer un numero valide';
        _result = null;
      });
      return;
    }

    final profile = ref.read(profileProvider);
    final gameId = profile.selectedGameId;
    if (gameId == null) {
      setState(() {
        _error = 'Aucun jeu selectionne';
        _result = null;
      });
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
      _result = null;
    });

    try {
      final response = await supabase.rpc('verify_collective_trio', params: {
        'p_game_id': gameId,
        'p_node_index': index,
      });

      if (!mounted) return;
      setState(() {
        _verifying = false;
        _result = response as Map<String, dynamic>;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = 'Erreur : $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1035),
        title: Text(
          'Mode Collectif',
          style: GoogleFonts.rajdhani(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Description.
            Text(
              'Entrez le numero d\'un trio pour verifier s\'il est valide.',
              style: GoogleFonts.exo2(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Champ numero.
            TextField(
              controller: _numberController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.rajdhani(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '#',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.2),
                  fontSize: 24,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                contentPadding: const EdgeInsets.all(20),
                enabledBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  borderRadius: BorderRadius.circular(14),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                      color: Color(0xFFFF6B35), width: 2),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Bouton verifier.
            ElevatedButton(
              onPressed: _verifying ? null : _verify,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _verifying
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'VERIFIER',
                      style: GoogleFonts.rajdhani(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
            ),

            const SizedBox(height: 28),

            // Resultat.
            if (_error != null) _buildError(_error!),
            if (_result != null) _buildResult(_result!),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_rounded, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: GoogleFonts.exo2(color: Colors.red.shade100)),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(Map<String, dynamic> result) {
    final exists = result['exists'] as bool? ?? false;

    if (!exists) {
      return _buildError(
          result['message'] as String? ?? 'Trio inexistant pour ce jeu');
    }

    final nodeIndex = result['node_index'] as int?;
    final depth = result['depth'] as int?;
    final eLabel = result['emettrice_label'] as String?;
    final cLabel = result['cable_label'] as String?;
    final rLabel = result['receptrice_label'] as String?;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF66BB6A).withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF66BB6A).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded,
                  color: Color(0xFF66BB6A), size: 28),
              const SizedBox(width: 12),
              Text(
                'Trio N$nodeIndex valide',
                style: GoogleFonts.rajdhani(
                  color: const Color(0xFF66BB6A),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _row('Profondeur', 'D$depth'),
          _row('Emettrice', eLabel ?? '-'),
          _row('Cable', cLabel ?? '-'),
          _row('Receptrice', rLabel ?? '-'),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.exo2(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.rajdhani(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
