import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_colors.dart';

class ImageHelper {
  static final ImagePicker _picker = ImagePicker();

  /// Static memory cache of decoded image bytes keyed by the clean base64 string hash.
  /// This prevents repeated `base64Decode` calls and prevents Flutter's `MemoryImage`
  /// from treating every widget rebuild as a brand new image, eliminating flicker.
  static final Map<int, Uint8List> _decodedBytesCache = {};

  /// Gets cached decoded bytes or decodes and caches them.
  static Uint8List? getDecodedBytes(String? base64String) {
    if (base64String == null || base64String.trim().isEmpty) return null;
    try {
      String cleanBase64 = base64String.trim();
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }
      final key = cleanBase64.hashCode;
      if (_decodedBytesCache.containsKey(key)) {
        return _decodedBytesCache[key];
      }

      final Uint8List bytes = base64Decode(cleanBase64);
      // Keep cache bounded to prevent memory growth
      if (_decodedBytesCache.length > 50) {
        _decodedBytesCache.remove(_decodedBytesCache.keys.first);
      }
      _decodedBytesCache[key] = bytes;
      return bytes;
    } catch (e) {
      debugPrint('Error decoding base64 image: $e');
      return null;
    }
  }

  /// Picks an image from Gallery or Camera and converts it to a Base64 string.
  /// No cloud buckets used - stores directly in database TEXT fields.
  static Future<String?> pickImageAsBase64({
    ImageSource source = ImageSource.gallery,
    double maxWidth = 800,
    double maxHeight = 800,
    int imageQuality = 70,
  }) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );

      if (file == null) return null;

      final Uint8List bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      // Pre-populate the cache with the known bytes
      _decodedBytesCache[base64String.hashCode] = bytes;
      return base64String;
    } catch (e) {
      debugPrint('Error picking image to base64: $e');
      return null;
    }
  }

  /// Builds a widget displaying an image from either a Network URL or Base64 string, with fallback placeholder.
  /// Uses cached bytes and gaplessPlayback: true so it never flickers or re-decodes on button clicks.
  static Widget buildBase64Image(
    String? imageSource, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    BorderRadius? borderRadius,
  }) {
    if (imageSource == null || imageSource.trim().isEmpty) {
      return placeholder ??
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: borderRadius ?? BorderRadius.circular(8),
            ),
            child: const Icon(Icons.image_outlined, color: AppColors.primary, size: 28),
          );
    }

    final trimmed = imageSource.trim();
    Widget image;

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      image = Image.network(
        trimmed,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (ctx, err, stack) {
          return placeholder ?? const Icon(Icons.broken_image_rounded, color: Colors.grey);
        },
      );
    } else {
      final bytes = getDecodedBytes(trimmed);
      if (bytes == null) {
        return placeholder ??
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: borderRadius ?? BorderRadius.circular(8),
              ),
              child: const Icon(Icons.image_outlined, color: AppColors.primary, size: 28),
            );
      }

      image = Image.memory(
        bytes,
        key: ValueKey(bytes.hashCode),
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (ctx, err, stack) {
          return placeholder ?? const Icon(Icons.broken_image_rounded, color: Colors.grey);
        },
      );
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius, child: image);
    }
    return image;
  }

  /// Builds a CircleAvatar directly from either a Network URL or Base64 string.
  static Widget buildBase64Avatar(
    String? imageSource, {
    double radius = 24,
    String? fallbackInitial,
  }) {
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withOpacity(0.12),
      child: Text(
        fallbackInitial ?? 'S',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
          fontSize: radius * 0.8,
        ),
      ),
    );

    if (imageSource == null || imageSource.trim().isEmpty) {
      return fallback;
    }

    final trimmed = imageSource.trim();

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.primary.withOpacity(0.12),
        backgroundImage: NetworkImage(trimmed),
        onBackgroundImageError: (_, _) {},
        child: null,
      );
    }

    final bytes = getDecodedBytes(trimmed);
    if (bytes == null) {
      return fallback;
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withOpacity(0.12),
      backgroundImage: MemoryImage(bytes),
    );
  }
}
