import 'dart:typed_data';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ShopImageThumb extends StatelessWidget {
  const ShopImageThumb({required this.imageUrl, this.size = 48, super.key});

  final String imageUrl;
  final double size;

  Uint8List? _decodeDataUrl(String input) {
    final comma = input.indexOf(',');
    if (comma < 0 || comma + 1 >= input.length) return null;
    try {
      return base64Decode(input.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.trim().isNotEmpty;
    final isDataUrl = imageUrl.startsWith('data:image/');

    final child = hasImage
        ? (isDataUrl
            ? Image.memory(
                _decodeDataUrl(imageUrl) ?? Uint8List(0),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined),
              )
            : CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported_outlined),
              ))
        : const Icon(Icons.inventory_2_outlined);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFFE2E8F0),
        child: child,
      ),
    );
  }
}
