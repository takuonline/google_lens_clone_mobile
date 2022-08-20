import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as image_lib;
import 'package:crop_your_image/crop_your_image.dart';
import 'dart:convert';
import '../networking/api.dart';
import 'dart:math' as math;

class CameraView extends StatefulWidget {
  static const routeName = "/camera";

  const CameraView({
    Key? key,
    required this.availableCameras,
  }) : super(key: key);

  // const CameraExampleView({required this.availableCameras});

  final List<CameraDescription> availableCameras;

  @override
  _CameraViewState createState() {
    return _CameraViewState();
  }
}

/// Returns a suitable camera icon for [direction].
IconData getCameraLensIcon(CameraLensDirection direction) {
  switch (direction) {
    case CameraLensDirection.back:
      return Icons.camera_rear;
    case CameraLensDirection.front:
      return Icons.camera_front;
    case CameraLensDirection.external:
      return Icons.camera;
    default:
      throw ArgumentError('Unknown lens direction');
  }
}

void logError(String code, String? message) {
  if (message != null) {
    print('Error: $code\nError Message: $message');
  } else {
    print('Error: $code');
  }
}

class _CameraViewState extends State<CameraView>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _controller;

  bool enableAudio = true;
  final cropController = CropController();
  GlobalKey cropAreaKey = GlobalKey();

  late AnimationController _flashModeControlRowAnimationController;
  late Animation<double> _flashModeControlRowAnimation;
  late AnimationController _exposureModeControlRowAnimationController;
  late AnimationController _focusModeControlRowAnimationController;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentScale = 1.0;
  double _baseScale = 1.0;
  XFile? pictureTaken;
  String? imgLabel;
  // Counting pointers (number of user fingers on screen)
  int _pointers = 0;
  Rect? initialCropArea;
  List productData = [];
  bool isLoading = false;
  CameraLensDirection lenseDirection = CameraLensDirection.back;
   late Future<void>  _initializeControllerFuture;
  @override
  void initState() {
    super.initState();

    _ambiguate(WidgetsBinding.instance)?.addObserver(this);

    _flashModeControlRowAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _flashModeControlRowAnimation = CurvedAnimation(
      parent: _flashModeControlRowAnimationController,
      curve: Curves.easeInCubic,
    );
    _exposureModeControlRowAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _focusModeControlRowAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // initialize camera
    initCamera();
  }

  void initCamera() {
    late final CameraDescription selectedCamera;

    for (CameraDescription cameraDescription in widget.availableCameras) {
      if (_controller != null &&
          _controller!.value.isRecordingVideo &&
          cameraDescription.lensDirection == lenseDirection) {
        continue;
      } else {
        selectedCamera = cameraDescription;
        break;
      }
    }

    onNewCameraSelected(selectedCamera);
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    final CameraController? oldController = _controller;
    if (oldController != null) {
      // `controller` needs to be set to null before getting disposed,
      // to avoid a race condition when we use the controller that is being
      // disposed. This happens when camera permission dialog shows up,
      // which triggers `didChangeAppLifecycleState`, which disposes and
      // re-creates the controller.
      _controller = null;
      await oldController.dispose();
    }

    final CameraController cameraController = CameraController(
      cameraDescription,
      kIsWeb ? ResolutionPreset.max : ResolutionPreset.medium,
      // enableAudio: enableAudio,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _controller = cameraController;

    // If the controller is updated then update the UI.
    cameraController.addListener(() {
      if (mounted) setState(() {});
      if (cameraController.value.hasError) {
        showInSnackBar(
            'Camera error ${cameraController.value.errorDescription}');
      }
    });

    try {
      _initializeControllerFuture =  cameraController.initialize();
      await Future.wait(<Future<Object?>>[
        // The exposure mode is currently not supported on the web.
        ...!kIsWeb ? <Future<Object?>>[] : <Future<Object?>>[],
        cameraController
            .getMaxZoomLevel()
            .then((double value) => _maxAvailableZoom = value),
        cameraController
            .getMinZoomLevel()
            .then((double value) => _minAvailableZoom = value),
      ]);
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

  @override
  void dispose() {
    _ambiguate(WidgetsBinding.instance)?.removeObserver(this);
    _flashModeControlRowAnimationController.dispose();
    _exposureModeControlRowAnimationController.dispose();
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
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      onNewCameraSelected(cameraController.description);
    }
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<CameraDescription> cameras = [];
  final logger = Logger();

  getHealthCheck() {
    ApiService? api = context.read<ApiService?>();
    api?.getHealthCheck();
  }

  Uint8List _base64ToImgData(String base64String) {
    return base64Decode(base64String);
  }

  Future<String> imgDataToBase64(Uint8List file, {int? height}) async {
    final image = image_lib.decodeImage(await file)!;
    return base64Encode(image_lib.encodeJpg(image));
  }

  onCropped(Uint8List croppedImgData) {
    logger.d("onCropped");
    _getDetection(croppedImgData, true);
  }

  void _getDetection(Uint8List pictureTaken, bool isUserFineTuned) async {
    // double width = MediaQuery.of(context).size.width;
    // double height = MediaQuery.of(context).size.height;
    // area of the Crop widget output that's actually the image and not the padding
    // double actualImgPercentage = 0.9076755410244435;
    // double actualImgPercentage = 1.2;

    setState(() {
      imgLabel = null;
      productData.clear();
      isLoading = true;
    });
    ApiService? api = context.read<ApiService?>();

    final base64Img = await imgDataToBase64(pictureTaken);
    final Map<String, dynamic>? res = await api?.postImage(base64Img);

    if (res != null) {
      String? label = res["title"];
      List<dynamic> imShape = res["im_shape"];
      List<dynamic> bounds = res["bounds"].map((v) => v.toDouble()).toList();

      // logger.i(res["bounds"]);
      // logger.i(res["im_shape"]);
      // logger.i(res["label"]);
      // logger.d(res["similar_products"]);

      setState(() {
        productData = res["similar_products"];

        if (!isUserFineTuned) {
          //TODO: use dynamic size of Crop widget instead of phone screen size
          final keyContext = cropAreaKey.currentContext;
          if (keyContext != null) {
            // size of crop image Widget
            final box = keyContext.findRenderObject() as RenderBox;
            final double xScaleFactor = box.size.width / imShape[1];
            final double yScaleFactor =
                box.size.height / imShape[0]; // * actualImgPercentage;


            double x1 = bounds[0] * xScaleFactor;
            double x2 = bounds[2] * xScaleFactor;

            double y1 = bounds[1] * yScaleFactor;
            double y2 = bounds[3] * yScaleFactor;

            setState(() {
              isLoading = false;
            });

            cropController.rect = Rect.fromPoints(
                Offset(
                  x1,
                  y1,
                ),
                Offset(x2, y2));
          }

          // when user has not adjusted the crop area manually
          // cropController.rect = Rect.fromPoints(
          //     Offset(bounds[0] - width * 0.17, bounds[1] - height * 0.06),
          //     Offset(bounds[2] - width * 0.10, bounds[3]));
        }
      });

      if (label != null) {
        setState(() {
          imgLabel = label;
        });
        logger.i(label);
      } else {
        setState(() {
          imgLabel = null;
        });
      }

      setState(() {
        isLoading = false;
      });
    }
  }

  void onTakePictureButtonPressed() async {
    pictureTaken = await takePicture();

    setState(() {
      isLoading = true;
    });
    logger.d("Pic taken");
    if (pictureTaken != null) {
      _getDetection(await pictureTaken!.readAsBytes(), false);
    }

    // if (mounted) {
    //   setState(() {
    //     imageFile = file;
    //     videoController?.dispose();
    //     videoController = null;
    //   });
    //   if (file != null) showInSnackBar('Picture saved to ${file.path}');
    // }
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData queryData;
    queryData = MediaQuery.of(context);
    final size = queryData.size;

    return Scaffold(
      key: _scaffoldKey,
      // floatingActionButton: ,
      // floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: WillPopScope(
        onWillPop: () async {
          logger.w("Will pop scope");
          setState(() {
            isLoading = false;
            pictureTaken = null;
          });
          return false;
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            SizedBox(
              height: size.height * .85,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  pictureTaken == null
                      ? Container(
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(20)),
                          ),
                          child: _cameraPreviewWidget(),
                        )
                      : _buildCropWidget(),

                  // if (pictureTaken != null
                  // // && initialCropArea != null
                  // ) _buildCropWidget(),

                  if (pictureTaken != null && productData.isNotEmpty)
                    SizedBox.expand(
                      child: DraggableScrollableSheet(
                        maxChildSize: 1,
                        minChildSize: .1,
                        initialChildSize: .1,
                        builder: (BuildContext context,
                            ScrollController scrollController) {
                          return Container(
                            padding: const EdgeInsets.only(top: 20),
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(30)),
                              color: Colors.white,
                            ),
                            child: GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 250,
                                      // childAspectRatio: 2/3,
                                      crossAxisSpacing: 4,
                                      mainAxisSpacing: 4),
                              controller: scrollController,
                              itemCount: productData.length,
                              itemBuilder: (BuildContext context, int index) {
                                final Map<String, dynamic> prod =
                                    productData[index];
                                final bool showImg = !prod["img"]
                                    .toString()
                                    .toLowerCase()
                                    .contains("missing_product");

                                return Card(
                                    elevation: 1,
                                    margin: const EdgeInsets.only(
                                        top: 5,
                                        left: 10,
                                        right: 10,
                                        bottom: 10),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        children: [
                                          Text("${index + 1}.  " +
                                              prod["title"]),
                                          const SizedBox(
                                            height: 20,
                                          ),
                                          showImg
                                              ? Image.network(
                                                  prod["img"],
                                                  height: 90,
                                                )
                                              : Image.network(
                                                  "https://www.pnp.co.za" +
                                                      prod["img"]
                                                          .toString()
                                                          .replaceAll("140x140",
                                                              "400x400"),
                                                  height: 90,
                                                )

                                          // const FlutterLogo(
                                          //         size: 50,
                                          //       )
                                        ],
                                      ),
                                    ));
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            if (imgLabel != null)
              Container(
                padding: EdgeInsets.all(2),
                // margin: EdgeInsets.all(20),

                color: Colors.red,
                child: Text(imgLabel ?? ""),
              ),

            if (isLoading) LinearProgressIndicator(),

            Container(
              decoration:
                  BoxDecoration(borderRadius: BorderRadius.circular(300)),
              child: _captureControlWidget(),
            ),

            // _captureControlWidget(),
            // _modeControlRowWidget(),
            // _cameraTogglesRowWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildCropWidget() {
    return Crop(
      key: cropAreaKey,
      onCropped: onCropped,
      image: File(pictureTaken!.path).readAsBytesSync(),
      initialArea: Rect.zero,
      // onMoved: (rect) {
      //   // logger.i(rect.toString());
      // },
      baseColor: Colors.white,
      controller: cropController,
    );
  }

  Widget _cameraPreviewWidget() {
    return FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              _controller != null) {
            final scale = 1 /
                (_controller!.value.aspectRatio *
                    MediaQuery.of(context).size.aspectRatio);

            // If the Future is complete, display the preview.
            return Listener(
              onPointerDown: (_) => _pointers++,
              onPointerUp: (_) => _pointers--,
              child: Transform.scale(
                scale: scale,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(20)),
                  child: CameraPreview(
                    _controller!,
                    child: LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onScaleStart: _handleScaleStart,
                          onScaleUpdate: _handleScaleUpdate,
                          onTapDown: (details) =>
                              onViewFinderTap(details, constraints),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        });

    //   child: Transform.scale(
    //     scale: aspectRation / deviceRatio,
    //     child: AspectRatio(
    //       aspectRatio: aspectRation,
    //       child: ,
    //     ),
    //   ),
    // );
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = _currentScale;
  }

  Future<void> _handleScaleUpdate(ScaleUpdateDetails details) async {
    // When there are not exactly two fingers on screen don't scale
    if (_controller == null || _pointers != 2) {
      return;
    }

    _currentScale = (_baseScale * details.scale)
        .clamp(_minAvailableZoom, _maxAvailableZoom);

    await _controller!.setZoomLevel(_currentScale);
  }

  /// Display a bar with buttons to change the flash and exposure modes
  Widget _modeControlRowWidget() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.flash_on),
              color: Colors.blue,
              onPressed: _controller != null ? onFlashModeButtonPressed : null,
            ),
            IconButton(
              icon: Icon(_controller?.value.isCaptureOrientationLocked ?? false
                  ? Icons.screen_lock_rotation
                  : Icons.screen_rotation),
              color: Colors.blue,
              onPressed: _controller != null
                  ? onCaptureOrientationLockButtonPressed
                  : null,
            ),
          ],
        ),
        _flashModeControlRowWidget(),
      ],
    );
  }

  Widget _flashModeControlRowWidget() {
    return SizeTransition(
      sizeFactor: _flashModeControlRowAnimation,
      child: ClipRect(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          mainAxisSize: MainAxisSize.max,
          children: [
            IconButton(
              icon: const Icon(Icons.flash_off),
              color: _controller?.value.flashMode == FlashMode.off
                  ? Colors.orange
                  : Colors.blue,
              onPressed: _controller != null
                  ? () => onSetFlashModeButtonPressed(FlashMode.off)
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.flash_auto),
              color: _controller?.value.flashMode == FlashMode.auto
                  ? Colors.orange
                  : Colors.blue,
              onPressed: _controller != null
                  ? () => onSetFlashModeButtonPressed(FlashMode.auto)
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.flash_on),
              color: _controller?.value.flashMode == FlashMode.always
                  ? Colors.orange
                  : Colors.blue,
              onPressed: _controller != null
                  ? () => onSetFlashModeButtonPressed(FlashMode.always)
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.highlight),
              color: _controller?.value.flashMode == FlashMode.torch
                  ? Colors.orange
                  : Colors.blue,
              onPressed: _controller != null
                  ? () => onSetFlashModeButtonPressed(FlashMode.torch)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  /// Display the control bar with buttons to take pictures and record videos.
  FloatingActionButton _captureControlWidget() {
    final CameraController? cameraController = _controller;

    return pictureTaken == null
        ? FloatingActionButton(
            child: const Icon(Icons.camera_alt),

            onPressed: cameraController != null &&
                    cameraController.value.isInitialized &&
                    !cameraController.value.isRecordingVideo
                ? onTakePictureButtonPressed
                : null,
          )
        : FloatingActionButton(
            onPressed: () => cropController.crop(), // ,
            child: const Icon(Icons.search),
          );
  }

  // Widget _selectGoodCamera() {}

  /// Display a row of toggle to select the camera (or a message if no camera is available).
  // Widget _cameraTogglesRowWidget() {
  //   final List<Widget> toggles = <Widget>[];
  //   late final CameraDescription selectedCamera;
  //
  //   void onChanged(CameraDescription? description) {
  //     if (description == null) {
  //       return;
  //     }
  //     setState(() {
  //       pictureTaken = null;
  //     });
  //     onNewCameraSelected(description);
  //   }
  //
  //   if (widget.availableCameras.isEmpty) {
  //     return const Center(child: Text('No camera found'));
  //   } else {
  //     // find good camera
  //     for (CameraDescription cameraDescription in widget.availableCameras) {
  //       if (_controller != null &&
  //           _controller!.value.isRecordingVideo &&
  //           cameraDescription.lensDirection == lenseDirection) {
  //         continue;
  //       } else {
  //         selectedCamera = cameraDescription;
  //         break;
  //       }
  //     }
  //
  //     onChanged(selectedCamera);
  //
  //     // dynamically generate list of available cameras
  //     // for (CameraDescription cameraDescription in widget.availableCameras) {
  //     //   logger.i(cameraDescription.name);
  //     //   logger.i(cameraDescription.lensDirection);
  //     //   logger.i(cameraDescription.sensorOrientation);
  //     //   logger.i(cameraDescription.toString());
  //
  //
  //
  //
  //     // toggles.add(
  //     //   SizedBox(
  //     //     width: 70.0,
  //     //     child: RadioListTile<CameraDescription>(
  //     //       title: Icon(getCameraLensIcon(cameraDescription.lensDirection)),
  //     //       groupValue: controller?.description,
  //     //       value: cameraDescription,
  //     //       onChanged:
  //     //           controller != null && controller!.value.isRecordingVideo
  //     //               ? null
  //     //               : onChanged,
  //     //     ),
  //     //   ),
  //     // );
  //     // }
  //   }
  //
  //   return Row(mainAxisSize: MainAxisSize.min, children: []);
  // }

  String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  void showInSnackBar(String message) {
    // ignore: deprecated_member_use
    _scaffoldKey.currentState?.showSnackBar(SnackBar(content: Text(message)));
  }

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

  void onFlashModeButtonPressed() {
    if (_flashModeControlRowAnimationController.value == 1) {
      _flashModeControlRowAnimationController.reverse();
    } else {
      _flashModeControlRowAnimationController.forward();
      _exposureModeControlRowAnimationController.reverse();
      _focusModeControlRowAnimationController.reverse();
    }
  }

  void onSetFlashModeButtonPressed(FlashMode mode) {
    setFlashMode(mode).then((_) {
      if (mounted) setState(() {});
      showInSnackBar('Flash mode set to ${mode.toString().split('.').last}');
    });
  }

  void onCaptureOrientationLockButtonPressed() async {
    try {
      if (_controller != null) {
        final CameraController cameraController = _controller!;
        if (cameraController.value.isCaptureOrientationLocked) {
          await cameraController.unlockCaptureOrientation();
          showInSnackBar('Capture orientation unlocked');
        } else {
          await cameraController.lockCaptureOrientation();
          showInSnackBar(
              'Capture orientation locked to ${cameraController.value.lockedCaptureOrientation.toString().split('.').last}');
        }
      }
    } on CameraException catch (e) {
      _showCameraException(e);
    }
  }

  Future<void> setFlashMode(FlashMode mode) async {
    if (_controller == null) {
      return;
    }

    try {
      await _controller!.setFlashMode(mode);
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    }
  }

  Future<void> setFocusMode(FocusMode mode) async {
    if (_controller == null) {
      return;
    }

    try {
      await _controller!.setFocusMode(mode);
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    }
  }

  Future<XFile?> takePicture() async {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      showInSnackBar('Error: select a camera first.');
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
      _showCameraException(e);
      return null;
    }
  }

  void _showCameraException(CameraException e) {
    logError(e.code, e.description);
    showInSnackBar('Error: ${e.code}\n${e.description}');
  }
}

/// This allows a value of type T or T? to be treated as a value of type T?.
///
/// We use this so that APIs that have become non-nullable can still be used
/// with `!` and `?` on the stable branch.
// TODO(ianh): Remove this once we roll stable in late 2021.
T? _ambiguate<T>(T? value) => value;
