import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FacePainter extends CustomPainter {
  final Size imageSize;
  final bool isLoading;
  final bool isError;
  final bool isFetched;
  final bool isStateEnable;
  double? scaleX, scaleY;
  Face? face;

  FacePainter({
    required this.imageSize,
    this.face,
    required this.isLoading,
    required this.isError,
    required this.isFetched,
    required this.isStateEnable,
  });
  @override
  void paint(Canvas canvas, Size size) {
    if (face == null) return;
    Paint paint;

    paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    if (isStateEnable) {
      if (isLoading) {
        paint.color = Colors.amber;
      } else if (isError) {
        paint.color = const Color(0xFFef4444);
      } else if (isFetched) {
        paint.color = const Color(0xFF68a835);
      } else {
        if (face!.headEulerAngleY! > 10 || face!.headEulerAngleY! < -10) {
          paint.color = const Color(0xFFef4444);
        } else {
          paint.color = const Color(0xFF3C4A7C);
        }
      }
    } else {
      if (face!.headEulerAngleY! > 10 || face!.headEulerAngleY! < -10) {
        paint.color = const Color(0xFFef4444);
      } else {
        paint.color = const Color(0xFF3C4A7C);
      }
    }

    // if (face!.headEulerAngleY! > 10 || face!.headEulerAngleY! < -10) {
    // paint = Paint()
    //   ..style = PaintingStyle.stroke
    //   ..strokeWidth = 5.0
    //   ..color = const Color(0xFFef4444);
    // } else {
    //   paint = Paint()
    //     ..style = PaintingStyle.stroke
    //     ..strokeWidth = 5.0
    //     ..color = const Color(0xFF68a835);
    // }

    scaleX = size.width / imageSize.width;
    scaleY = size.height / imageSize.height;

    canvas.drawRRect(_scaleRect(rect: face!.boundingBox, imageSize: imageSize, widgetSize: size, scaleX: scaleX!, scaleY: scaleY!), paint);
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    return oldDelegate.imageSize != imageSize || oldDelegate.face != face;
  }
}

RRect _scaleRect({required Rect rect, required Size imageSize, required Size widgetSize, double? scaleX, double? scaleY}) {
  return RRect.fromLTRBR((widgetSize.width - rect.left.toDouble() * scaleX!), rect.top.toDouble() * scaleY!,
      widgetSize.width - rect.right.toDouble() * scaleX, rect.bottom.toDouble() * scaleY, const Radius.circular(10));
}
