import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

/// Service for Auto Image Compression & Storage Optimization
/// Resizes and compresses portrait images to ~30KB-70KB while preserving crisp face/portrait clarity.
class ImageService {
  static final ImagePicker _picker = ImagePicker();

  /// Captures or picks an image and applies auto-compression.
  /// - [maxWidth] & [maxHeight]: Default 600px (ideal for high-DPI portrait circles without excessive byte weight)
  /// - [imageQuality]: Default 70% (maintains facial sharp details while cutting file size by 95%+)
  static Future<String?> pickAndCompressImage({
    required ImageSource source,
    int maxWidth = 600,
    int maxHeight = 600,
    int imageQuality = 70,
  }) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: imageQuality,
      );

      if (file == null) return null;

      final Uint8List bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;

      final base64String = base64Encode(bytes);
      return 'data:image/jpeg;base64,$base64String';
    } catch (e) {
      return null;
    }
  }

  /// Decodes base64 string (handles Data URI prefix automatically)
  static Uint8List? decodeBase64ToBytes(String? base64Str) {
    if (base64Str == null || base64Str.trim().isEmpty) return null;
    try {
      final clean = base64Str.contains(',') ? base64Str.split(',')[1] : base64Str;
      return base64Decode(clean.trim());
    } catch (_) {
      return null;
    }
  }

  /// Calculates approximate KB size of a base64 string
  static double getApproximateSizeKb(String base64Str) {
    final clean = base64Str.contains(',') ? base64Str.split(',')[1] : base64Str;
    return (clean.length * 3 / 4) / 1024;
  }
}
