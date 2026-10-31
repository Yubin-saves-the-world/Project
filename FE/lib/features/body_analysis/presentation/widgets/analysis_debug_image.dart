import 'dart:convert';
import 'package:flutter/material.dart';

/// Decoding happens before Image.errorBuilder, so malformed base64 needs its own guard.
class AnalysisDebugImage extends StatelessWidget {
  const AnalysisDebugImage({
    super.key,
    required this.encoded,
    required this.semanticLabel,
  });
  final String encoded, semanticLabel;

  @override
  Widget build(BuildContext context) {
    const fallback = Center(child: Text('이미지를 표시하지 못했어요.'));
    // Match the 10 MB photo budget and avoid decoding unbounded server data.
    if (encoded.isEmpty || encoded.length > 14 * 1024 * 1024) return fallback;
    try {
      return Image.memory(
        base64Decode(encoded),
        fit: BoxFit.contain,
        semanticLabel: semanticLabel,
        errorBuilder: (context, error, stack) => fallback,
      );
    } on FormatException {
      return fallback;
    }
  }
}
