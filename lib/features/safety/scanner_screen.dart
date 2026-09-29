import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/snackbar.dart';
import '../../models/pass.dart';
import '../../models/user.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_inputs.dart';

/// QR scanner for gate / visitor passes with a manual-entry fallback.
///
/// Security and admin accounts verify through the security repository;
/// students can paste their own pass token to check its validity.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  MobileScannerController? _camera;
  bool _cameraActive = false;
  bool _checking = false;
  bool _showCamera = false;
  ScanResult? _result;
  final TextEditingController _manual = TextEditingController();
  final ValueNotifier<String> _lastCode = ValueNotifier<String>('');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_cameraActive) {
      final bool? arg = ModalRoute.of(context)?.settings.arguments as bool?;
      if (arg == true) _showCamera = true;
    }
  }

  @override
  void dispose() {
    _manual.dispose();
    _lastCode.dispose();
    _camera?.dispose();
    super.dispose();
  }

  void _ensureCamera() {
    _camera ??= MobileScannerController();
    _cameraActive = true;
  }

  Future<void> _verify(String raw) async {
    final String code = raw.trim();
    if (code.isEmpty || _checking) return;
    if (_lastCode.value == code) return;
    _lastCode.value = code;

    final AppState state = AppScope.of(context).state;
    final AppUser? user = state.user;
    setState(() {
      _checking = true;
      _result = null;
    });

    ScanResult result;
    try {
      if (user?.canVerifyPasses == true) {
        result = await state.deps.security.verifyPass(code);
      } else {
        result = await state.deps.gatePasses.verifyQr(code);
        if (!result.isAccepted && result.status == QrScanStatus.invalid) {
          final ScanResult visitor =
              await state.deps.visitorPasses.verifyQr(code);
          if (visitor.status != QrScanStatus.invalid) result = visitor;
        }
      }
    } catch (_) {
      result = const ScanResult(
        status: QrScanStatus.invalid,
        message: 'Verification failed. Please try again.',
      );
    }

    if (!mounted) return;
    setState(() {
      _result = result;
      _checking = false;
    });

    if (result.isAccepted) {
      showAVITSnackBar(context,
          message: result.message, tone: AVITSnackTone.success);
    } else {
      showAVITSnackBar(context,
          message: result.message, tone: AVITSnackTone.error);
    }
    if (_showCamera) {
      await Future<void>.delayed(const Duration(seconds: 3));
      if (mounted) _lastCode.value = '';
    }
  }

  AVITStatusTone _toneFor(QrScanStatus status) => switch (status) {
        QrScanStatus.valid => AVITStatusTone.success,
        QrScanStatus.expired => AVITStatusTone.warning,
        QrScanStatus.used => AVITStatusTone.info,
        QrScanStatus.revoked => AVITStatusTone.danger,
        QrScanStatus.invalid => AVITStatusTone.danger,
      };

  IconData _iconFor(QrScanStatus status) => switch (status) {
        QrScanStatus.valid => Icons.verified_rounded,
        QrScanStatus.expired => Icons.schedule_rounded,
        QrScanStatus.used => Icons.task_alt_rounded,
        QrScanStatus.revoked => Icons.block_rounded,
        QrScanStatus.invalid => Icons.gpp_bad_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    if (_showCamera) _ensureCamera();

    return Scaffold(
      appBar: AVITAppBar(
        title: 'Verify Pass',
        subtitle: 'Scan or paste a QR token',
        actions: <Widget>[
          IconButton(
            tooltip: _showCamera ? 'Use manual entry' : 'Use camera',
            onPressed: () {
              if (_showCamera) {
                setState(() {
                  _showCamera = false;
                  _cameraActive = false;
                });
                _camera?.stop();
              } else {
                setState(() => _showCamera = true);
              }
            },
            icon: Icon(
              _showCamera ? Icons.keyboard_rounded : Icons.qr_code_scanner,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: <Widget>[
          if (_showCamera) ...<Widget>[
            AVITCard(
              padding: EdgeInsets.zero,
              borderRadius: AppRadius.card,
              child: ClipRRect(
                borderRadius: AppRadius.card,
                child: SizedBox(
                  height: 300,
                  child: _camera == null
                      ? const ColoredBox(
                          color: Colors.black,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.white,
                            ),
                          ),
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            MobileScanner(
                              controller: _camera!,
                              onDetect: (BarcodeCapture capture) {
                                for (final Barcode barcode
                                    in capture.barcodes) {
                                  final String? value = barcode.rawValue;
                                  if (value != null && value.isNotEmpty) {
                                    _verify(value);
                                    break;
                                  }
                                }
                              },
                              errorBuilder: (BuildContext context,
                                  MobileScannerException error) {
                                return ColoredBox(
                                  color: AppColors.navyDeep,
                                  child: Center(
                                    child: Padding(
                                      padding: AppSpacing.cardPadding,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          const Icon(
                                            Icons.no_photography_rounded,
                                            color: AppColors.white,
                                            size: 34,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Camera unavailable on this device. '
                                            'Use manual entry below.',
                                            textAlign: TextAlign.center,
                                            style: text.bodySmall?.copyWith(
                                              color: AppColors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const Center(
                              child: SizedBox(
                                width: 190,
                                height: 190,
                                child: _ScanFrame(),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton.filledTonal(
                  tooltip: 'Toggle torch',
                  onPressed: () => _camera?.toggleTorch(),
                  icon: const Icon(Icons.flashlight_on_rounded),
                ),
                const SizedBox(width: AppSpacing.md),
                IconButton.filledTonal(
                  tooltip: 'Switch camera',
                  onPressed: () => _camera?.switchCamera(),
                  icon: const Icon(Icons.cameraswitch_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          AVITCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Manual entry', style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'Paste the pass token (starts with AVITQR1).',
                  style: text.labelSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                AVITTextField(
                  label: 'QR token',
                  hint: 'AVITQR1…',
                  controller: _manual,
                  required: true,
                  autocorrect: false,
                  onSubmitted: _verify,
                ),
                const SizedBox(height: AppSpacing.sm),
                AVITButton(
                  label: 'Verify pass',
                  icon: Icons.verified_user_rounded,
                  loading: _checking,
                  onPressed: _checking ? null : () => _verify(_manual.text),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_result != null) ...<Widget>[
            AVITSectionHeader(
              title: 'Verification result',
              subtitle: _result!.isAccepted ? 'Entry allowed' : 'Entry blocked',
            ),
            AVITCard(
              borderColor: _result!.isAccepted
                  ? AppColors.success
                  : AppColors.danger,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        _iconFor(_result!.status),
                        color: _result!.isAccepted
                            ? AppColors.success
                            : AppColors.danger,
                        size: 30,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          _result!.message,
                          style: text.titleSmall,
                        ),
                      ),
                      AVITStatusChip(
                        label: _result!.status.name.toUpperCase(),
                        tone: _toneFor(_result!.status),
                        compact: true,
                      ),
                    ],
                  ),
                  if (_result!.holderName.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Text('Holder: ${_result!.holderName}',
                        style: text.bodySmall),
                  ],
                  if (_result!.title.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(_result!.title, style: text.labelSmall),
                  ],
                  if (_result!.detail.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(_result!.detail, style: text.bodySmall),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FramePainter(
        color: AppColors.white.withValues(alpha: 0.9),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  const _FramePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const double len = 34;
    final Rect rect = Offset.zero & size;

    final Path path = Path()
      ..moveTo(rect.left, rect.top + len)
      ..lineTo(rect.left, rect.top)
      ..lineTo(rect.left + len, rect.top)
      ..moveTo(rect.right - len, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.top + len)
      ..moveTo(rect.right, rect.bottom - len)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.right - len, rect.bottom)
      ..moveTo(rect.left + len, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.bottom - len);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.color != color;
}
