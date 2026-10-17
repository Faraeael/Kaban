import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';
import 'package:crop_image/crop_image.dart';

/// Helper that inspects an image file, attempts to auto-detect the QR bounding
/// box, crops it with a quiet-zone margin, and returns the cropped file.
/// If auto-detection fails, returns null so the UI can open the interactive cropper.
class QrCropService {
  QrCropService._();

  /// Attempts to automatically locate and crop the QR code inside [sourceImageFile].
  /// Returns the cropped [File] if detected, or `null` if no QR pattern was found.
  static Future<File?> autoDetectAndCrop({
    required File sourceImageFile,
    required String destPath,
  }) async {
    try {
      final bytes = await sourceImageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      final int32List = decoded
          .convert(numChannels: 4)
          .getBytes(order: img.ChannelOrder.abgr)
          .buffer
          .asInt32List();

      final source = RGBLuminanceSource(decoded.width, decoded.height, int32List);
      final reader = QRCodeReader();

      Result? result;
      // Try HybridBinarizer first (better on phone screenshots with varied backgrounds)
      try {
        result = reader.decode(BinaryBitmap(HybridBinarizer(source)));
      } catch (_) {
        // Fallback to GlobalHistogramBinarizer
        try {
          result = reader.decode(BinaryBitmap(GlobalHistogramBinarizer(source)));
        } catch (_) {}
      }

      if (result == null || result.resultPoints.length < 3) {
        return null;
      }

      // Calculate bounding box from result points (finder patterns)
      final points = result.resultPoints;
      var minX = points.first.x;
      var maxX = points.first.x;
      var minY = points.first.y;
      var maxY = points.first.y;

      for (final p in points) {
        if (p.x < minX) minX = p.x;
        if (p.x > maxX) maxX = p.x;
        if (p.y < minY) minY = p.y;
        if (p.y > maxY) maxY = p.y;
      }

      // The points represent finder pattern centers, not outer edges.
      // Add a generous quiet-zone margin (~25% of pattern spread) to include
      // the outer black modules and white border.
      final spread = max(maxX - minX, maxY - minY);
      final margin = spread * 0.28;

      final cropX = (minX - margin).clamp(0.0, decoded.width.toDouble()).toInt();
      final cropY = (minY - margin).clamp(0.0, decoded.height.toDouble()).toInt();
      final cropW = (maxX + margin - cropX).clamp(1.0, (decoded.width - cropX).toDouble()).toInt();
      final cropH = (maxY + margin - cropY).clamp(1.0, (decoded.height - cropY).toDouble()).toInt();

      // Ensure roughly square crop
      final side = max(cropW, cropH);
      final finalW = min(side, decoded.width - cropX);
      final finalH = min(side, decoded.height - cropY);

      final cropped = img.copyCrop(
        decoded,
        x: cropX,
        y: cropY,
        width: finalW,
        height: finalH,
      );

      final outBytes = img.encodePng(cropped);
      final destFile = File(destPath);
      await destFile.writeAsBytes(outBytes);
      return destFile;
    } catch (_) {
      return null;
    }
  }
}

/// Fallback interactive crop dialog shown when auto-detection cannot locate
/// finder patterns or user requests manual adjustment.
class InteractiveQrCropperModal extends StatefulWidget {
  final File imageFile;
  const InteractiveQrCropperModal({super.key, required this.imageFile});

  @override
  State<InteractiveQrCropperModal> createState() =>
      _InteractiveQrCropperModalState();
}

class _InteractiveQrCropperModalState extends State<InteractiveQrCropperModal> {
  final _controller = CropController(
    aspectRatio: 1.0,
    defaultCrop: const Rect.fromLTRB(0.1, 0.2, 0.9, 0.7),
  );
  bool _isProcessing = false;

  Future<void> _saveCrop() async {
    setState(() => _isProcessing = true);
    try {
      final bitmap = await _controller.croppedBitmap();
      final byteData = await bitmap.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        if (mounted) Navigator.pop(context, null);
        return;
      }
      final bytes = byteData.buffer.asUint8List();
      if (mounted) Navigator.pop(context, bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to crop: $e')),
        );
        Navigator.pop(context, null);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Crop QR Code',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_right_rounded),
            tooltip: 'Rotate',
            onPressed: () => _controller.rotateRight(),
          ),
          IconButton(
            icon: _isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_rounded, color: Color(0xFF75EEA5)),
            tooltip: 'Confirm Crop',
            onPressed: _isProcessing ? null : _saveCrop,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CropImage(
                controller: _controller,
                image: Image.file(widget.imageFile),
                gridColor: Colors.white54,
                scrimColor: Colors.black.withValues(alpha: 0.65),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              color: const Color(0xFF161616),
              child: const Text(
                'Drag corners to fit the QR code and account details. Tap ✓ when done.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
