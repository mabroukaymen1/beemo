import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlatformViewWrapper extends StatelessWidget {
  final String viewType;
  final Map<String, dynamic>? creationParams;

  const PlatformViewWrapper({
    Key? key,
    required this.viewType,
    this.creationParams,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Ensure the view has a non-zero size.
      final width = constraints.maxWidth > 0 ? constraints.maxWidth : 300.0;
      final height = constraints.maxHeight > 0 ? constraints.maxHeight : 300.0;
      return Container(
        width: width,
        height: height,
        color: Colors.transparent,
        child: AndroidView(
          viewType: viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: creationParams,
          creationParamsCodec: StandardMessageCodec(),
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          onPlatformViewCreated: _onPlatformViewCreated,
        ),
      );
    });
  }

  void _onPlatformViewCreated(int id) {
    // Optionally add logging or error handling here.
    try {
      // Do setup if needed.
    } catch (e) {
      debugPrint('Error on platform view creation: $e');
    }
  }
}
