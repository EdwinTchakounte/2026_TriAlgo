// =============================================================
// FICHIER : lib/presentation/wireframes/t_qr_scanner_page.dart
// ROLE   : Scanner 3 QR codes de cartes (mode collectif)
// COUCHE : Presentation > Wireframes
// =============================================================
//
// REFONTE (vs version precedente) :
// ---------------------------------
//   - Migration vers design system (tokens + PageScaffold)
//   - Cadre de visee anime (pulse)
//   - Slots gravees "tablettes" (gradient dore) au lieu de cases plates
//   - Haptic + son click a chaque scan accepte
//
// CONTRAT INCHANGE :
// ------------------
//   Navigator.pop(List<String>) avec 3 UUIDs scannes, ou
//   Navigator.pop(null) si annulation.
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/motion.dart';
import 'package:trialgo/core/design_system/tokens/radius.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';
import 'package:trialgo/data/services/audio_service.dart';
import 'package:trialgo/presentation/providers/audio_provider.dart';
import 'package:trialgo/presentation/providers/graph_provider.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';


class TQrScannerPage extends ConsumerStatefulWidget {
  const TQrScannerPage({super.key});

  @override
  ConsumerState<TQrScannerPage> createState() => _TQrScannerPageState();
}

class _TQrScannerPageState extends ConsumerState<TQrScannerPage>
    with SingleTickerProviderStateMixin {

  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  /// Liste (uuid, label) des cartes scannees.
  final List<(String, String)> _scanned = [];

  /// Debounce entre 2 scans successifs.
  bool _busy = false;

  /// Pulse animation pour le cadre de visee.
  late final AnimationController _framePulse;

  static final RegExp _uuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  @override
  void initState() {
    super.initState();
    _framePulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _framePulse.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || _scanned.length >= 3) return;

    final code = capture.barcodes
        .firstWhere(
          (b) => b.rawValue != null && b.rawValue!.isNotEmpty,
          orElse: () => const Barcode(),
        )
        .rawValue;
    if (code == null) return;

    final tr = TLocale.of(context);
    if (!_uuidRe.hasMatch(code)) {
      _showSnack(tr('qr.not_recognized'), TColors.warning);
      return;
    }
    if (_scanned.any((s) => s.$1 == code)) {
      _showSnack(tr('qr.already_scanned'), TColors.warning);
      return;
    }

    final cards = ref.read(graphSyncServiceProvider).cards;
    final card = cards[code];
    if (card == null) {
      _showSnack(tr('qr.not_in_game'), TColors.error);
      return;
    }

    HapticFeedback.selectionClick();
    ref.read(audioServiceProvider).playSfx(SoundEffect.click);

    setState(() {
      _busy = true;
      _scanned.add((code, card.label));
    });

    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _busy = false);

    if (_scanned.length >= 3) {
      HapticFeedback.mediumImpact();
      await _controller.stop();
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      Navigator.of(context).pop(_scanned.map((s) => s.$1).toList());
    }
  }

  Future<void> _reset() async {
    HapticFeedback.lightImpact();
    setState(() => _scanned.clear());
    await _controller.start();
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = TLocale.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          tr('qr.title'),
          style: TTypography.headlineMd(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_outlined),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // --- Preview camera plein ecran ---
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // --- Cadre de visee anime ---
          Center(
            child: AnimatedBuilder(
              animation: _framePulse,
              builder: (context, _) {
                final scale = 1.0 + 0.03 * _framePulse.value;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      borderRadius: TRadius.xxlAll,
                      border: Border.all(
                        color: TColors.primaryVariant.withValues(
                          alpha: 0.5 + 0.5 * _framePulse.value,
                        ),
                        width: 3,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // --- Panel bas avec slots ---
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(TSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(TRadius.xxl),
                ),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Compteur.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tr('qr.scanned_count'),
                        style:
                            TTypography.bodySm(color: Colors.white70),
                      ),
                      Text(
                        '${_scanned.length}/3',
                        style: TTypography.numericMd(
                            color: TColors.primaryVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: TSpacing.md),

                  // 3 slots "tablette doree".
                  Row(
                    children: List.generate(3, (i) {
                      final filled = i < _scanned.length;
                      final label =
                          filled ? _scanned[i].$2 : '...';
                      return Expanded(
                        child: Padding(
                          padding:
                              EdgeInsets.only(right: i < 2 ? 8 : 0),
                          child: _buildSlot(
                            index: i + 1,
                            label: label,
                            filled: filled,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: TSpacing.md),

                  // Bouton recommencer.
                  OutlinedButton.icon(
                    onPressed: _scanned.isEmpty ? null : _reset,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(tr('qr.restart')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: TSpacing.lg,
                        vertical: TSpacing.sm,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Slot visuel d'une carte scannee (tablette doree).
  Widget _buildSlot({
    required int index,
    required String label,
    required bool filled,
  }) {
    return AnimatedContainer(
      duration: TDuration.quick,
      padding: const EdgeInsets.symmetric(
        vertical: TSpacing.sm,
        horizontal: TSpacing.xs,
      ),
      decoration: BoxDecoration(
        gradient: filled
            ? LinearGradient(
                colors: [
                  TColors.primary.withValues(alpha: 0.25),
                  TColors.primaryVariant.withValues(alpha: 0.25),
                ],
              )
            : null,
        color: filled ? null : Colors.white.withValues(alpha: 0.06),
        borderRadius: TRadius.mdAll,
        border: Border.all(
          color: filled
              ? TColors.primaryVariant.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.15),
          width: filled ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '#$index',
            style: TTypography.labelSm(color: Colors.white54),
          ),
          const SizedBox(height: TSpacing.xxs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TTypography.titleMd(
              color: filled ? Colors.white : Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}
