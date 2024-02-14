import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:image/image.dart' as imglib;
import 'package:flutter/foundation.dart';
import 'package:wakelock/wakelock.dart';
import 'package:flutter/material.dart';

import 'package:face_camera/face_camera.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FaceCamera.initialize();
  Wakelock.enable();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  File? _capturedImage;
  SmartFaceController smartFaceController = SmartFaceController();
  final _cameras = [];

  @override
  void initState() {
    addCameras();
    super.initState();
  }

  void addCameras() async {
    _cameras.addAll(await availableCameras());
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.sizeOf(context);
    return MaterialApp(
      theme: ThemeData.dark(
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('FaceCapture example app'),
        ),
        body: Builder(
          builder: (context) {
            if (_capturedImage != null) {
              return Center(
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Image.file(
                      _capturedImage!,
                      width: double.maxFinite,
                      fit: BoxFit.fitWidth,
                    ),
                    ElevatedButton(
                        onPressed: () {
                          setState(() => _capturedImage = null);
                          smartFaceController.startCamera();
                        },
                        child: const Text(
                          'Capture Again',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ))
                  ],
                ),
              );
            }
            return SmartFaceCamera(
              autoCapture: true,
              size: size,
              controller: smartFaceController,
              showCaptureControl: true,
              // sensorOrientation: 270,
              // previewOrientation: 180,
              defaultCameraLens: CameraLensDirection.front,
              onError: () {},
              onCapture: (File? image) async {
                if (image != null) {
                  setState(() => _capturedImage = image);
                }
              },
              onFaceDetected: (Face? face, CameraImage? image) async {},
              messageBuilder: (context, face) {
                if (face?.face == null) {
                  return _message('Place your face in the camera: $_cameras');
                } else if (face != null && !face.wellPositioned) {
                  return _message('Center your face in the square: $_cameras');
                } else if (face != null && face.wellPositioned) {
                  return _message('Face detected');
                }
                return const SizedBox.shrink();
              },
            );
          },
        ),
      ),
    );
  }

  Future<ui.Image> loadImage(Uint8List img) async {
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(img, (ui.Image img) {
      return completer.complete(img);
    });
    return completer.future;
  }

  Widget _message(String msg) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 55, vertical: 15),
        child: Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w400)),
      );
}

/// [fixImage] - This function fixes the orientation of the image captured by the camera.
Future<File?> fixImage((String imagePath, Offset? offset) params) async {
  // Decode the image from the given imagePath and read its bytes as input
  final imglib.Image? capturedImage = imglib.decodeImage(await File(params.$1).readAsBytes());

  // Check if the capturedImage is not null
  if (capturedImage != null) {
    // // Copy and rotate the image with angle 0 to ensure it is oriented correctly
    // final imglib.Image orientedImage = imglib.copyRotate(capturedImage, angle: 0);

    // // Flip the orientedImage horizontally
    // final imglib.Image fixedImage = imglib.flipHorizontal(capturedImage);

    // Calculate the cropping parameters
    int cropWidth = (capturedImage.width * 0.6).round();
    int cropHeight = (capturedImage.height * 0.75).round();
    int offsetX = params.$2?.dx.round() ?? ((capturedImage.width - cropWidth) ~/ 2);
    int offsetY = params.$2?.dy.toInt() ?? ((capturedImage.height - cropHeight) ~/ 2);

    // Crop the image
    final imglib.Image croppedImage = imglib.copyCrop(capturedImage, x: offsetX - 100, y: offsetY - 100, width: cropWidth, height: cropHeight);

    // Convert to grayscale
    final imglib.Image grayscaleImage = imglib.grayscale(croppedImage);

    // Write the encoded and compressed image bytes of the grayscaleImage to the original imagePath and return the file
    return await File(params.$1).writeAsBytes(imglib.encodeJpg(grayscaleImage, quality: 100));
  }

  // If capturedImage is null, return null indicating that the image could not be fixed
  return null;
}

imglib.Image? convertYUV420toImageColor(CameraImage image) {
  const shift = (0xFF << 24);

  final int width = image.width;
  final int height = image.height;
  final int uvRowStride = image.planes[1].bytesPerRow;
  final int uvPixelStride = image.planes[1].bytesPerPixel!;

  final img = imglib.Image(width: width, height: height);

  for (int x = 0; x < width; x++) {
    for (int y = 0; y < height; y++) {
      final int uvIndex = uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
      final int index = y * width + x;

      final yp = image.planes[0].bytes[index];
      final up = image.planes[1].bytes[uvIndex];
      final vp = image.planes[2].bytes[uvIndex];

      int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
      int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).round().clamp(0, 255);
      int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

      img.setPixelRgba(x, y, r, g, b, shift);
    }
  }

  imglib.Image flipped = imglib.flipHorizontal(img);

  if (width > height) {
    return imglib.copyRotate(flipped, angle: 90);
  }

  return flipped;
}
