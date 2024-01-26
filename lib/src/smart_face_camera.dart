import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../face_camera.dart';

import 'handlers/face_identifier.dart';
import 'paints/face_painter.dart';
import 'paints/hole_painter.dart';
import 'res/builders.dart';
import 'utils/logger.dart';

/// A widget that wraps the [CameraPreview] widget and provides a face detection overlay.

/// This class is used to control the InnerDrawer.
class SmartFaceController {
  late _SmartFaceCameraState _smartFaceCameraState;

  // This method is used to attach the _InnerDrawerState to the InnerDrawerController.
  // ignore: library_private_types_in_public_api
  void attach(_SmartFaceCameraState smartFaceCameraState) {
    _smartFaceCameraState = smartFaceCameraState;
  }

  Future<void> takePicture({FaceBox? detectedFaceBox}) async {
    _smartFaceCameraState._onTakePictureButtonPressed(detectedFaceBox: detectedFaceBox);
  }

  Future<void> startCamera() async {
    _smartFaceCameraState._startImageStream();
  }

  Future<void> stopCamera() async {
    if (_smartFaceCameraState._controller!.value.isStreamingImages) {
      _smartFaceCameraState._controller?.stopImageStream();
    }
  }
}

class SmartFaceCamera extends StatefulWidget {
  final ImageResolution imageResolution;
  final SmartFaceController controller;
  final CameraLensDirection? defaultCameraLens;
  final CameraFlashMode defaultFlashMode;
  final bool enableAudio;
  final bool autoCapture;
  final bool showCaptureControl;
  final String? message;
  final TextStyle messageStyle;
  final CameraOrientation? orientation;
  final void Function(FaceBox? faceBox, File? image) onCapture;
  final void Function(Face? face, CameraImage? cameraImage)? onFaceDetected;
  final void Function() onError;
  final void Function()? onInactive;
  final void Function()? onResumed;
  final Widget? captureControlIcon;
  final Widget? lensControlIcon;
  final FlashControlBuilder? flashControlBuilder;
  final MessageBuilder? messageBuilder;
  final bool isLoading;
  final bool isError;
  final bool isFetched;
  final bool isStateEnabled;
  final Size size;
  final int? sensorOrientation;
  final int? previewOrientation;

  const SmartFaceCamera({
    this.imageResolution = ImageResolution.medium,
    this.defaultCameraLens,
    this.enableAudio = true,
    this.autoCapture = false,
    this.showCaptureControl = true,
    this.message,
    this.defaultFlashMode = CameraFlashMode.auto,
    this.orientation = CameraOrientation.portraitUp,
    this.messageStyle = const TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w400),
    required this.onCapture,
    this.onFaceDetected,
    this.captureControlIcon,
    this.lensControlIcon,
    this.flashControlBuilder,
    this.messageBuilder,
    super.key,
    required this.controller,
    this.isLoading = false,
    this.isError = false,
    this.isFetched = false,
    this.isStateEnabled = false,
    required this.size,
    this.sensorOrientation,
    this.previewOrientation,
    required this.onError,
    this.onInactive,
    this.onResumed,
  });

  @override
  State<SmartFaceCamera> createState() => _SmartFaceCameraState();
}

class _SmartFaceCameraState extends State<SmartFaceCamera> with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _controller;

  bool _alreadyCheckingImage = false;
  bool _isDisposed = false;
  bool _isPhotoTaking = false;

  DetectedFace? _detectedFace;
  FaceBox? _detectedFaceBox;

  @override
  void initState() {
    super.initState();
    widget.controller.attach(this);
    WidgetsBinding.instance.addObserver(this);
    _initializeCameraController();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      if (cameraController.value.isStreamingImages) {
        cameraController.stopImageStream();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _isDisposed = true;
          });
        });
      }
      widget.onInactive?.call();
    } else if (state == AppLifecycleState.resumed) {
      if (!cameraController.value.isStreamingImages) {
        _initializeCameraController();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _isDisposed = false;
          });
        });
      }
      widget.onResumed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final CameraController? cameraController = _controller;

    return Stack(
      alignment: Alignment.center,
      children: [
        if (cameraController != null && cameraController.value.isInitialized && !_isDisposed) ...[
          SizedBox(
            width: widget.size.width,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _cameraDisplayWidget(),
                Builder(
                  builder: (context) {
                    if (widget.messageBuilder != null) {
                      return widget.messageBuilder!.call(context, _detectedFace);
                    }
                    if (widget.message != null) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 55, vertical: 15),
                        child: Text(widget.message!, textAlign: TextAlign.center, style: widget.messageStyle),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                if (_detectedFace != null) ...[
                  SizedBox(
                    width: cameraController.value.previewSize!.width,
                    height: cameraController.value.previewSize!.height,
                    child: CustomPaint(
                      size: widget.size,
                      painter: FacePainter(
                        face: _detectedFace!.face,
                        imageSize: Size(
                          _controller!.value.previewSize!.height,
                          _controller!.value.previewSize!.width,
                        ),
                        isError: widget.isError,
                        isLoading: widget.isLoading,
                        isFetched: widget.isFetched,
                        isStateEnable: widget.isStateEnabled,
                      ),
                    ),
                  ),
                  // if (_detectedFaceBox?.face != null)
                  //   CustomPaint(
                  //     painter: DotPainter(
                  //       offset: scaleRect(
                  //         rect: _detectedFaceBox!.face!.boundingBox,
                  //         imageSize: _detectedFaceBox!.imageSize!,
                  //         widgetSize: _detectedFaceBox!.widgetSize!,
                  //       ).center,
                  //     ),
                  //   ),
                  // CustomPaint(
                  //   painter: SquarePainter(
                  //     rect: scaleRect(
                  //       rect: _detectedFaceBox!.face!.boundingBox,
                  //       imageSize: _detectedFaceBox!.imageSize!,
                  //       widgetSize: _detectedFaceBox!.widgetSize!,
                  //     ),
                  //   ),
                  // ),
                ]
              ],
            ),
          )
        ] else ...[
          const Text(
            'Не удалось определить камеру',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.w400,
            ),
          ),
          CustomPaint(
            size: widget.size,
            painter: HolePainter(),
          )
        ],
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Visibility(
              visible: widget.showCaptureControl,
              child: _captureControlWidget(),
            ),
          ),
        )
      ],
    );
  }

  Future<void> _initializeCameraController() async {
    List<CameraDescription> cameras = FaceCamera.cameras;
    CameraDescription cameraDescription = cameras.firstWhere((element) => element.lensDirection == widget.defaultCameraLens);
    final CameraController cameraController = CameraController(
      CameraDescription(
        name: cameraDescription.name,
        lensDirection: CameraLensDirection.front,
        sensorOrientation: widget.sensorOrientation ?? cameraDescription.sensorOrientation,
      ),
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
    );

    _controller = cameraController;

    cameraController.addListener(() {
      if (mounted) {
        setState(() {});
      }
      if (cameraController.value.hasError) {
        showInSnackBar('Camera error ${cameraController.value.errorDescription}');
      }
    });

    try {
      await cameraController.initialize().then((_) {
        _startImageStream();
        setState(() {});
      });
    } on CameraException catch (e) {
      switch (e.code) {
        case 'CameraAccessDenied':
          showInSnackBar('You have denied camera access.');
          break;
        case 'CameraAccessDeniedWithoutPrompt':
          // iOS only
          showInSnackBar('Please go to Settings app to enable camera access.');
          break;
        case 'CameraAccessRestricted':
          // iOS only
          showInSnackBar('Camera access is restricted.');
          break;
        case 'AudioAccessDenied':
          showInSnackBar('You have denied audio access.');
          break;
        case 'AudioAccessDeniedWithoutPrompt':
          // iOS only
          showInSnackBar('Please go to Settings app to enable audio access.');
          break;
        case 'AudioAccessRestricted':
          // iOS only
          showInSnackBar('Audio access is restricted.');
          break;
        default:
          _showCameraException(e);
          break;
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  void showInSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Render camera.
  Widget _cameraDisplayWidget() {
    final CameraController? cameraController = _controller;
    if (cameraController != null && cameraController.value.isInitialized) {
      return Transform.rotate(
        angle: ((widget.previewOrientation ?? cameraController.description.sensorOrientation + 90) % 360) * (math.pi / 180),
        child: CameraPreview(
          cameraController,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  /// Display the control buttons to take pictures.
  Widget _captureControlWidget() {
    final CameraController? cameraController = _controller;

    return IconButton(
      iconSize: 40,
      icon: widget.captureControlIcon ??
          const CircleAvatar(
            radius: 40,
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.camera_alt, size: 35),
            ),
          ),
      onPressed: cameraController != null && cameraController.value.isInitialized ? _onTakePictureButtonPressed : null,
    );
  }

  String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    if (_controller == null) {
      return;
    }

    final CameraController cameraController = _controller!;

    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    cameraController.setExposurePoint(offset);
    cameraController.setFocusPoint(offset);
  }

  void _onTakePictureButtonPressed({FaceBox? detectedFaceBox}) async {
    final CameraController? cameraController = _controller;
    try {
      await Future<void>.delayed(Duration.zero);
      if (cameraController != null && cameraController.value.isStreamingImages && !_isPhotoTaking) {
        await Future<void>.delayed(const Duration(milliseconds: 200)).then(
          (value) {
            _isPhotoTaking = true;
            takePicture().then((XFile? file) {
              if (file != null) {
                widget.onCapture(
                    _detectedFaceBox != null
                        ? FaceBox(
                            face: _detectedFaceBox?.face,
                            imageSize: _detectedFaceBox?.imageSize,
                            widgetSize: _detectedFaceBox?.widgetSize,
                          )
                        : null,
                    File(file.path));
                _isPhotoTaking = false;
              }
            });
          },
        );
      }
    } catch (e) {
      widget.onError();
      logError(e.toString());
    }
  }

  Future<XFile?> takePicture() async {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      // showInSnackBar('Error: select a camera first.');
      return null;
    }

    if (cameraController.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }

    try {
      XFile file = await cameraController.takePicture();
      return file;
    } on Exception catch (e) {
      logError("From: takePicture()");
      widget.onError();
      _showCameraException(e);
      return null;
    }
  }

  void _showCameraException(Exception e) {
    logError(e.toString());
    // showInSnackBar('Error: ${e.code}\n${e.description}');
  }

  void _startImageStream() {
    final CameraController? cameraController = _controller;
    if (cameraController != null && !cameraController.value.isStreamingImages) {
      cameraController.startImageStream(_processImage);
    }
  }

  void _processImage(CameraImage cameraImage) async {
    final CameraController? cameraController = _controller;
    if (!_alreadyCheckingImage && mounted) {
      _alreadyCheckingImage = true;
      try {
        await FaceIdentifier.scanImage(cameraImage: cameraImage, camera: cameraController!.description).then((result) async {
          if (mounted) {
            setState(() {
              _detectedFace = result;
              _detectedFaceBox = FaceBox(
                face: result?.face,
                imageSize: Size(
                  _controller!.value.previewSize!.height,
                  _controller!.value.previewSize!.width,
                ),
                widgetSize: widget.size,
              );
            });

            if (result != null) {
              try {
                if (result.wellPositioned) {
                  if (widget.onFaceDetected != null) {
                    widget.onFaceDetected!.call(result.face, cameraImage);
                  }
                  if (widget.autoCapture) {
                    _onTakePictureButtonPressed(detectedFaceBox: _detectedFaceBox);
                  }
                }
              } catch (e) {
                widget.onError();
                logError(e.toString());
              }
            }
          }
        });
        _alreadyCheckingImage = false;
      } catch (ex, stack) {
        widget.onError();
        logError('$ex, $stack');
      }
    }
  }
}

Rect scaleRect({required Rect rect, required Size imageSize, required Size widgetSize, double? scaleX, double? scaleY}) {
  // Значения по умолчанию для масштабирования, если они не предоставлены
  scaleX ??= widgetSize.width / imageSize.width;
  scaleY ??= widgetSize.height / imageSize.height;

  return Rect.fromLTRB(
    (widgetSize.width - rect.left.toDouble() * scaleX), // Левая сторона
    rect.top.toDouble() * scaleY, // Верхняя сторона
    widgetSize.width - rect.right.toDouble() * scaleX, // Правая сторона
    rect.bottom.toDouble() * scaleY, // Нижняя сторона
  );
}

class DotPainter extends CustomPainter {
  final Offset offset;
  final double dotSize;
  final Color dotColor;

  DotPainter({required this.offset, this.dotSize = 10.0, this.dotColor = Colors.red});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(offset.dx, offset.dy - 50), dotSize, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class SquarePainter extends CustomPainter {
  final RRect rect;
  final Color squareColor;

  SquarePainter({required this.rect, this.squareColor = Colors.blue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = squareColor
      ..style = PaintingStyle.fill; // Используйте PaintingStyle.stroke, если нужен только контур

    canvas.drawRRect(rect, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
