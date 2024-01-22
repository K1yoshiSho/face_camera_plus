import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceBox {
  final Face? face;
  final Size? imageSize;
  final Size? widgetSize;

  const FaceBox({
    required this.face,
    required this.imageSize,
    required this.widgetSize,
  });
}
