// import 'dart:math';
import 'dart:developer';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../models/detected_image.dart';

class FaceIdentifier {
  static Future<DetectedFace?> scanImage({required CameraImage cameraImage, required CameraDescription camera}) async {
    final WriteBuffer allBytes = WriteBuffer();
    for (Plane plane in cameraImage.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize = Size(cameraImage.width.toDouble(), cameraImage.height.toDouble());

    final InputImageRotation imageRotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation0deg;

    final InputImageFormat inputImageFormat = InputImageFormatValue.fromRawValue(cameraImage.format.raw) ?? InputImageFormat.nv21;

    final inputImageData = InputImageMetadata(
      size: imageSize,
      bytesPerRow: cameraImage.planes[0].bytesPerRow,
      format: inputImageFormat,
      rotation: imageRotation,
    );

    final visionImage = InputImage.fromBytes(
      bytes: bytes,
      metadata: inputImageData,
    );
    DetectedFace? result;
    final face = await _detectFace(visionImage: visionImage);
    if (face != null) {
      result = face;
    }

    return result;
  }

  static Future<DetectedFace?> _detectFace({required visionImage}) async {
    final options = FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
    );
    final faceDetector = FaceDetector(options: options);
    try {
      final List<Face> faces = await faceDetector.processImage(visionImage);
      final faceDetect = _extractFace(faces);
      return faceDetect;
    } catch (error) {
      debugPrint(error.toString());
      return null;
    }
  }

  static DetectedFace _extractFace(List<Face> faces) {
    if (faces.isEmpty) {
      return const DetectedFace(wellPositioned: false, face: null);
    }

    final face = faces.first;
    final leftEar = face.landmarks[FaceLandmarkType.leftEar];
    final rightEar = face.landmarks[FaceLandmarkType.rightEar];

    final wellPositioned = !(face.headEulerAngleY! > 2 || face.headEulerAngleY! < -2) &&
        !(face.headEulerAngleZ! > 30 || face.headEulerAngleZ! < -30) &&
        (leftEar?.position.y ?? -1) >= 0 &&
        (leftEar?.position.x ?? -1) >= 0 &&
        (rightEar?.position.y ?? -1) >= 0 &&
        (rightEar?.position.x ?? -1) >= 0 &&
        (face.leftEyeOpenProbability == null || face.leftEyeOpenProbability! >= 0.5) &&
        (face.rightEyeOpenProbability == null || face.rightEyeOpenProbability! >= 0.5);

    return DetectedFace(wellPositioned: wellPositioned, face: face);
  }
}
