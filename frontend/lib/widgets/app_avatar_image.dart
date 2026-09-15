import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Universal Avatar & Profile Image Widget
/// Handles all image storage formats seamlessly:
/// 1. Supabase Cloud CDN URLs (https://...)
/// 2. Local Backend Disk Fallback (/uploads/...)
/// 3. Direct Base64 data URIs (data:image/...) or raw Base64
/// 4. Local device file paths from camera/gallery picker (/data/user/...)
class AppAvatarImage extends StatefulWidget {
  final String? photoUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget fallback;
  final BorderRadius? borderRadius;
  final bool isCircle;

  const AppAvatarImage({
    super.key,
    required this.photoUrl,
    required this.width,
    required this.height,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.isCircle = true,
  });

  @override
  State<AppAvatarImage> createState() => _AppAvatarImageState();
}

class _AppAvatarImageState extends State<AppAvatarImage> {
  String? _resolvedBackendBase;

  @override
  void initState() {
    super.initState();
    _loadBaseUrlIfNeeded();
  }

  @override
  void didUpdateWidget(covariant AppAvatarImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) {
      _loadBaseUrlIfNeeded();
    }
  }

  void _loadBaseUrlIfNeeded() {
    final photo = widget.photoUrl?.trim() ?? '';
    if (photo.startsWith('/uploads/')) {
      ApiService().baseUrl.then((base) {
        if (mounted) {
          setState(() {
            _resolvedBackendBase = base;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawPhoto = widget.photoUrl?.trim();

    if (rawPhoto == null || rawPhoto.isEmpty) {
      return widget.fallback;
    }

    Widget content;

    // 1. Full Network URL (Supabase CDN or External HTTPS)
    if (rawPhoto.startsWith('http://') || rawPhoto.startsWith('https://')) {
      content = Image.network(
        rawPhoto,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (ctx, err, stack) => widget.fallback,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      );
    }
    // 2. Relative Server Path (/uploads/...)
    else if (rawPhoto.startsWith('/uploads/')) {
      final base = _resolvedBackendBase ?? '';
      final fullUrl = base.isNotEmpty ? '$base$rawPhoto' : rawPhoto;
      content = Image.network(
        fullUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (ctx, err, stack) => widget.fallback,
      );
    }
    // 3. Base64 Data URI or Raw Base64 String
    else if (rawPhoto.startsWith('data:image/') ||
        (!rawPhoto.startsWith('/') && !rawPhoto.contains(':\\') && rawPhoto.length > 80)) {
      try {
        final cleanBase64 = rawPhoto.contains(',') ? rawPhoto.split(',')[1].trim() : rawPhoto.trim();
        final bytes = base64Decode(cleanBase64.replaceAll(RegExp(r'[\r\n\s]'), ''));
        content = Image.memory(
          bytes,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (ctx, err, stack) => widget.fallback,
        );
      } catch (_) {
        content = widget.fallback;
      }
    }
    // 4. Local Device File Path (Camera / Gallery Picker cache)
    else if (!kIsWeb && (rawPhoto.startsWith('/') || rawPhoto.contains(':\\'))) {
      try {
        final file = File(rawPhoto);
        if (file.existsSync()) {
          content = Image.file(
            file,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            errorBuilder: (ctx, err, stack) => widget.fallback,
          );
        } else {
          content = widget.fallback;
        }
      } catch (_) {
        content = widget.fallback;
      }
    } else {
      content = widget.fallback;
    }

    if (widget.isCircle) {
      return ClipOval(child: content);
    } else if (widget.borderRadius != null) {
      return ClipRRect(borderRadius: widget.borderRadius!, child: content);
    }
    return content;
  }
}
