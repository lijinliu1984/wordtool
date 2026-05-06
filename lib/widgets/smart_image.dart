import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../utils/resource_helper.dart';

class SmartImage extends StatelessWidget {
  final String? source;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? defaultWidget;
  final Color defaultBackgroundColor;
  final IconData defaultIcon;
  final Duration? fadeInDuration;
  final Map<String, String>? httpHeaders;
  final int? memCacheWidth;
  final int? memCacheHeight;

  const SmartImage({
    super.key,
    this.source,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.defaultWidget,
    this.defaultBackgroundColor = const Color(0xFFF5F5F5),
    this.defaultIcon = Icons.image_not_supported_outlined,
    this.fadeInDuration,
    this.httpHeaders,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, height: height, child: _buildImage());
  }

  Widget _buildImage() {
    if (source == null || source!.isEmpty) {
      return _buildDefaultWidget();
    }

    if (ResourceHelper.isUrl(source)) {
      return CachedNetworkImage(
        imageUrl: source!,
        width: width,
        height: height,
        fit: fit,
        httpHeaders: httpHeaders,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        maxWidthDiskCache: memCacheWidth,
        maxHeightDiskCache: memCacheHeight,
        fadeInDuration: fadeInDuration ?? const Duration(milliseconds: 200),
        placeholder: (context, url) => _buildLoadingWidget(),
        errorWidget: (context, url, error) => _buildDefaultWidget(),
      );
    }

    final file = File(source!);
    if (file.existsSync()) {
      return Image.file(
        file,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: memCacheWidth,
        cacheHeight: memCacheHeight,
      );
    }

    return _buildDefaultWidget();
  }

  Widget _buildLoadingWidget() {
    return Container(
      width: width,
      height: height,
      color: defaultBackgroundColor,
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultWidget() {
    if (defaultWidget != null) return defaultWidget!;

    return Container(
      width: width,
      height: height,
      color: defaultBackgroundColor,
      child: Center(
        child: Icon(defaultIcon, size: 40, color: Colors.grey[400]),
      ),
    );
  }
}
