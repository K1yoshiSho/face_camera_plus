import 'dart:io';
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
          body: Builder(builder: (context) {
            // if (_capturedImage != null) {
            //   return Center(
            //     child: Stack(
            //       alignment: Alignment.bottomCenter,
            //       children: [
            //         Image.file(
            //           _capturedImage!,
            //           width: double.maxFinite,
            //           fit: BoxFit.fitWidth,
            //         ),
            //         ElevatedButton(
            //             onPressed: () => setState(() => _capturedImage = null),
            //             child: const Text(
            //               'Capture Again',
            //               textAlign: TextAlign.center,
            //               style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            //             ))
            //       ],
            //     ),
            //   );
            // }
            return SmartFaceCamera(
              autoCapture: false,
              size: size,
              controller: smartFaceController,
              defaultCameraLens: CameraLensDirection.front,
              onCapture: (File? image) {
                setState(() => _capturedImage = image);
              },
              onFaceDetected: (Face? face) {
                //Do something
              },
              messageBuilder: (context, face) {
                if (face == null) {
                  return _message('Place your face in the camera');
                }
                if (!face.wellPositioned) {
                  return _message('Center your face in the square');
                }

                if (face.wellPositioned) {
                  return _message('Face detected');
                }
                return const SizedBox.shrink();
              },
            );
          })),
    );
  }

  Widget _message(String msg) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 55, vertical: 15),
        child: Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w400)),
      );
}
