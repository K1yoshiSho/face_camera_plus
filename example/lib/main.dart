import 'dart:io';
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
                        onPressed: () => setState(() => _capturedImage = null),
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
              onCapture: (File? image) {
                setState(() => _capturedImage = image);
              },
              onFaceDetected: (Face? face, CameraImage? image) {
                // Uint8List imageBytes = image!.planes[0].bytes;
                // //convert bytedata to image
                // imglib.Image? bitmap = imglib.decodeImage(imageBytes);

                // //then save on your directories use path_provider package to get all directories you are able to save in a device
                // File("pathToSave").writeAsBytesSync(imglib.encodeJpg(bitmap!));
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

  Widget _message(String msg) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 55, vertical: 15),
        child: Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w400)),
      );
}
