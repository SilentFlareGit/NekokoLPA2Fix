import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:file_picker/file_picker.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController controller = MobileScannerController(
    formats: [BarcodeFormat.qrCode],
  );

  bool _scanned = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Scan QR Code',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (_scanned) return;
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  setState(() => _scanned = true);
                  Navigator.pop(context, barcode.rawValue);
                  break;
                }
              }
            },
          ),
          // Scanner Overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.primary, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          // Guidance Text
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Center the QR code in the frame',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
          // Flash toggle
          Positioned(
            top: 20,
            right: 20,
            child: CircleAvatar(
              backgroundColor: Colors.black38,
              child: IconButton(
                color: Colors.white,
                icon: ValueListenableBuilder(
                  valueListenable: controller,
                  builder: (context, state, child) {
                    switch (state.torchState) {
                      case TorchState.off:
                        return const Icon(Icons.flash_off, color: Colors.grey);
                      case TorchState.on:
                        return const Icon(Icons.flash_on, color: Colors.yellow);
                      case TorchState.unavailable:
                        return const Icon(Icons.flash_off, color: Colors.red);
                      case TorchState.auto:
                        return const Icon(
                          Icons.flash_auto,
                          color: Colors.white,
                        );
                    }
                  },
                ),
                onPressed: () => controller.toggleTorch(),
              ),
            ),
          ),
          // Gallery selector
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Center(
              child: FilledButton.icon(
                onPressed: () async {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.image,
                  );
                  if (result != null && result.files.single.path != null) {
                    final path = result.files.single.path!;
                    final capture = await controller.analyzeImage(path);
                    if (capture != null && capture.barcodes.isNotEmpty) {
                      final code = capture.barcodes.first.rawValue;
                      if (code != null && context.mounted) {
                        Navigator.pop(context, code);
                      }
                    } else {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("No QR code found in selected image."),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.image),
                label: const Text("Select from Gallery"),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.8,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
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
