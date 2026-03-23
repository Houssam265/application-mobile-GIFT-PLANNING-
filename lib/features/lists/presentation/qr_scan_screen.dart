import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/utils/join_code_parser.dart';

/// Écran plein écran : scan d’un QR (URL ou code) pour rejoindre une liste.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final b in capture.barcodes) {
      final candidates = <String>[
        if (b.rawValue != null && b.rawValue!.isNotEmpty) b.rawValue!,
        if (b.displayValue != null && b.displayValue!.isNotEmpty) b.displayValue!,
        if (b.url != null && b.url!.url.isNotEmpty) b.url!.url,
      ];
      for (final raw in candidates) {
        final code = extractJoinCode(raw);
        if (code != null) {
          _handled = true;
          _controller.stop();
          if (mounted) Navigator.of(context).pop<String>(code);
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner le QR de la liste')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.65),
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Text(
                  'Alignez le QR de partage GiftPlan. Il peut contenir un lien ou le code de la liste.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
