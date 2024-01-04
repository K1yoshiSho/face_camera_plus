import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:image/image.dart' as imglib;
import 'package:flutter/foundation.dart';
import 'package:wakelock/wakelock.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

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
              autoCapture: false,
              size: size,
              controller: smartFaceController,
              showCaptureControl: true,
              // sensorOrientation: 270,
              // previewOrientation: 180,
              defaultCameraLens: CameraLensDirection.front,
              onCapture: (File? image) {
                // setState(() => _capturedImage = image);
              },
              onFaceDetected: (Face? face, CameraImage? image) async {
                Uint8List imageBytes = image!.planes[0].bytes;
                //convert bytedata to image
                imglib.Image? bitmap = convertYUV420toImageColor(image);
                final Directory? tempDir = Directory('/storage/emulated/0/Download');
                final String tempPath = "${tempDir?.path}/${DateTime.now().millisecondsSinceEpoch}.jpg";

                //then save on your directories use path_provider package to get all directories you are able to save in a device
                File(tempPath).writeAsBytesSync(imglib.encodeJpg(bitmap!));
                setState(() => _capturedImage = File(tempPath));
                smartFaceController.stopCamera();
              },
              messageBuilder: (context, face) {
                if (face?.face == null) {
                  return _message('Place your face in the camera: ${_cameras}');
                } else if (face != null && !face.wellPositioned) {
                  return _message('Center your face in the square: ${_cameras}');
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
