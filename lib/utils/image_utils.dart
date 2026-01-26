import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Utility class for optimized image loading
class ImageUtils {
  /// Get a cached network image with sensible defaults
  static Widget getCachedNetworkImage({
    required String? imageUrl,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    // Return placeholder if no URL
    if (imageUrl == null || imageUrl.isEmpty) {
      return placeholder ?? _defaultPlaceholder(width, height);
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) =>
          placeholder ?? _defaultPlaceholder(width, height),
      errorWidget: (context, url, error) =>
          errorWidget ?? _defaultErrorWidget(width, height),
      fadeOutDuration: const Duration(milliseconds: 300),
      fadeInDuration: const Duration(milliseconds: 300),
    );
  }

  /// Default placeholder widget
  static Widget _defaultPlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  /// Default error widget
  static Widget _defaultErrorWidget(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: Icon(
        Icons.image_not_supported,
        color: Colors.grey[600],
      ),
    );
  }

  /// Get circle avatar with optimized image loading
  static Widget getCachedCircleAvatar({
    required String? imageUrl,
    required double radius,
    required Widget fallbackIcon,
  }) {
    return CircleAvatar(
      radius: radius,
      backgroundImage:
          imageUrl != null && imageUrl.isNotEmpty
              ? CachedNetworkImageProvider(imageUrl)
              : null,
      child: imageUrl == null || imageUrl.isEmpty ? fallbackIcon : null,
    );
  }
}
