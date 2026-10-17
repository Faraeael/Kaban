import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';
import 'package:finance_tracker/services/qr_crop_service.dart';

void main() {
  test('QrCropService autoDetectAndCrop locates and crops QR code with margins',
      () async {
    // 1. Generate a valid QR code bit matrix
    final qr = Encoder.encode('00020101021226540010A0000007770110000000000002120000000000005204601153036085802PH5911TEST USER6006MANILA6304ABCD', ErrorCorrectionLevel.m);
    final matrix = qr.matrix!;
    const scale = 8;
    final qrWidth = matrix.width * scale;
    final qrHeight = matrix.height * scale;

    // 2. Composite QR in the center of a simulated tall phone screenshot (e.g. 500x1000)
    final canvas = img.Image(width: 600, height: 1200);
    // Fill canvas with white background
    img.fill(canvas, color: img.ColorRgb8(245, 245, 245));

    // Draw dark mock UI headers / text bars
    img.fillRect(canvas, x1: 50, y1: 50, x2: 550, y2: 120, color: img.ColorRgb8(220, 220, 220));

    // Stamp the QR code into center (x: 180, y: 350)
    for (var x = 0; x < matrix.width; x++) {
      for (var y = 0; y < matrix.height; y++) {
        final isDark = matrix.get(x, y) == 1;
        final color = isDark ? img.ColorRgb8(0, 0, 0) : img.ColorRgb8(255, 255, 255);
        for (var dx = 0; dx < scale; dx++) {
          for (var dy = 0; dy < scale; dy++) {
            canvas.setPixel(180 + x * scale + dx, 350 + y * scale + dy, color);
          }
        }
      }
    }

    // Draw mock buttons at bottom
    img.fillRect(canvas, x1: 50, y1: 1050, x2: 550, y2: 1140, color: img.ColorRgb8(230, 90, 40));

    final sourceFile = File('test/mock_screenshot.png');
    await sourceFile.writeAsBytes(img.encodePng(canvas));

    const destPath = 'test/cropped_qr.png';
    final croppedFile = await QrCropService.autoDetectAndCrop(
      sourceImageFile: sourceFile,
      destPath: destPath,
    );

    expect(croppedFile, isNotNull);
    expect(await croppedFile!.exists(), isTrue);

    final croppedImg = img.decodeImage(await croppedFile.readAsBytes())!;
    // Cropped dimensions should be compact square around the QR (approx 200-400px), not 600x1200
    expect(croppedImg.width, greaterThanOrEqualTo(qrWidth));
    expect(croppedImg.width, lessThan(550));
    expect(croppedImg.height, greaterThanOrEqualTo(qrHeight));
    expect(croppedImg.height, lessThan(550));

    // Verify cropped image is still decodable by QR reader
    final int32List = croppedImg
        .convert(numChannels: 4)
        .getBytes(order: img.ChannelOrder.abgr)
        .buffer
        .asInt32List();
    final source = RGBLuminanceSource(croppedImg.width, croppedImg.height, int32List);
    final decoded = QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source)));
    expect(decoded.text, contains('TEST USER'));

    // Cleanup test artifacts
    if (await sourceFile.exists()) await sourceFile.delete();
    if (await croppedFile.exists()) await croppedFile.delete();
  });
}
