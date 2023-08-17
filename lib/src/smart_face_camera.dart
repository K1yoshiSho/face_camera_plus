import 'dart:async';
import 'dart:io';
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

  Future<void> takePicture() async {
    _smartFaceCameraState._onTakePictureButtonPressed();
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
  final void Function(File? image) onCapture;
  final void Function(Face? face)? onFaceDetected;
  final Widget? captureControlIcon;
  final Widget? lensControlIcon;
  final FlashControlBuilder? flashControlBuilder;
  final MessageBuilder? messageBuilder;
  final bool isLoading;
  final bool isError;
  final bool isFetched;
  final bool isStateEnabled;
  final Size size;

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
    Key? key,
    required this.controller,
    this.isLoading = false,
    this.isError = false,
    this.isFetched = false,
    this.isStateEnabled = false,
    required this.size,
  }) : super(key: key);

  @override
  State<SmartFaceCamera> createState() => _SmartFaceCameraState();
}

class _SmartFaceCameraState extends State<SmartFaceCamera> with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _controller;

  bool _alreadyCheckingImage = false;

  DetectedFace? _detectedFace;

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

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCameraController();
    }
  }

  @override
  Widget build(BuildContext context) {
    final CameraController? cameraController = _controller;
    return Stack(
      alignment: Alignment.center,
      children: [
        if (cameraController != null && cameraController.value.isInitialized) ...[
          Transform.scale(
            scale: 1.0,
            child: AspectRatio(
              aspectRatio: widget.size.aspectRatio,
              child: OverflowBox(
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.fitHeight,
                  child: SizedBox(
                    width: widget.size.width,
                    height: widget.size.width * cameraController.value.aspectRatio,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        _cameraDisplayWidget(),
                        if (_detectedFace != null) ...[
                          SizedBox(
                            width: cameraController.value.previewSize!.width,
                            height: cameraController.value.previewSize!.height,
                            child: CustomPaint(
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
                          )
                        ]
                      ],
                    ),
                  ),
                ),
              ),
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
        if (widget.showCaptureControl) ...[
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _captureControlWidget(),
            ),
          )
        ]
      ],
    );
  }

  Future<void> _initializeCameraController() async {
    List<CameraDescription> cameras = await availableCameras();

    final CameraController cameraController = CameraController(
      cameras.where((element) {
        return element.lensDirection == widget.defaultCameraLens;
      }).first,
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
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
      return CameraPreview(
        cameraController,
        child: Builder(
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

  void _onTakePictureButtonPressed() async {
    final CameraController? cameraController = _controller;
    try {
      await Future<void>.delayed(Duration.zero);
      if (cameraController != null && cameraController.value.isStreamingImages) {
        cameraController.stopImageStream().whenComplete(() async {
          await Future<void>.delayed(Duration.zero).then(
            (value) {
              takePicture().then((XFile? file) {
                if (file != null) {
                  widget.onCapture(File(file.path));
                }

                Future.delayed(const Duration(milliseconds: 100)).whenComplete(() {
                  if (mounted && cameraController.value.isInitialized) {
                    try {
                      _startImageStream();
                      setState(() {});
                    } catch (e) {
                      logError(e.toString());
                    }
                  }
                });
              });
            },
          );
        });
      }
    } catch (e) {
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
    } on CameraException catch (e) {
      logError("From: takePicture()");
      _showCameraException(e);
      return null;
    }
  }

  void _showCameraException(CameraException e) {
    logError(e.code, e.description);
    // showInSnackBar('Error: ${e.code}\n${e.description}');
  }

  void _startImageStream() {
    final CameraController? cameraController = _controller;
    if (cameraController != null) {
      cameraController.startImageStream(_processImage);
    }
  }

  void _processImage(CameraImage cameraImage) async {
    final CameraController? cameraController = _controller;
    if (!_alreadyCheckingImage && mounted) {
      _alreadyCheckingImage = true;
      try {
        await FaceIdentifier.scanImage(cameraImage: cameraImage, camera: cameraController!.description).then((result) async {
          setState(() => _detectedFace = result);

          if (result != null) {
            try {
              if (result.wellPositioned) {
                if (widget.onFaceDetected != null) {
                  widget.onFaceDetected!.call(result.face);
                }
                if (widget.autoCapture) {
                  _onTakePictureButtonPressed();
                }
              }
            } catch (e) {
              logError(e.toString());
            }
          }
        });
        _alreadyCheckingImage = false;
      } catch (ex, stack) {
        logError('$ex, $stack');
      }
    }
  }
}
