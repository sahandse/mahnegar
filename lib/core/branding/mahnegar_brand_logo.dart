import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MahNegarBrandLogo extends StatelessWidget {
  const MahNegarBrandLogo({
    super.key,
    this.size = 48,
    this.borderRadius = 16,
    this.fit = BoxFit.cover,
  });

  final double size;
  final double borderRadius;
  final BoxFit fit;

  static final Future<Uint8List> _logoBytes = rootBundle
      .loadString('assets/branding/mahnegar_logo.webp.b64')
      .then((value) => base64Decode(value.trim()));

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: FutureBuilder<Uint8List>(
          future: _logoBytes,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Image.memory(
                snapshot.data!,
                fit: fit,
                gaplessPlayback: true,
                filterQuality: FilterQuality.high,
              );
            }

            return DecoratedBox(
              decoration: const BoxDecoration(color: Color(0xFF08152F)),
              child: const Center(
                child: Icon(Icons.nightlight_round, color: Color(0xFFFFD77A)),
              ),
            );
          },
        ),
      ),
    );
  }
}
