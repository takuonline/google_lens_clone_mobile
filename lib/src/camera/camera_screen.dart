import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
// import 'package:extended_image/extended_image.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
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

  final availableCameras;

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
//
// double normalize(double x,double a,double b){
//   return (b-a)* (x-math.min(x))/(math.max(x)-math.min(x)) + a
//
// }

// [ 240, 320 ]  og py img

// (392.7, 583.0)   img inside renderbox shape

// (392.7, 642.3)   renderbox shape

// 583.0

class _CameraViewState extends State<CameraView>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? controller;
  XFile? imageFile;
  XFile? videoFile;
  VideoPlayerController? videoController;
  VoidCallback? videoPlayerListener;
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
  Uint8List? imgData;
  XFile? pictureTaken;
  String? imgLabel;
  // Counting pointers (number of user fingers on screen)
  int _pointers = 0;
  Rect? initialCropArea;
  List productData = [];

  @override
  void initState() {
    super.initState();
    getAvailableCameras();
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
  }

  Future<void> getAvailableCameras() async {
    cameras = await widget.availableCameras;
    // return cameras;

    // var a =await widget.availableCameras();
    print(cameras);
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
    final CameraController? cameraController = controller;

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

  String? getHealthCheck() {
    ApiService? api = context.read<ApiService?>();
    api?.getHealthCheck();
  }

  Uint8List _base64ToImgData(String base64String) {
    return base64Decode(base64String);
  }

  Future<String> ImgDataToBase64(Uint8List file, {int? height}) async {
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
    double actualImgPercentage = 1.2;

    setState(() {
      imgLabel = null;
      productData.clear();
    });
    ApiService? api = context.read<ApiService?>();

    final base64Img = await ImgDataToBase64(pictureTaken);
    final Map<String, dynamic>? res = await api?.postImage(base64Img);

    if (res != null) {
      logger.d(res["label"]);
      // logger.d(res["similar_products"]);

      String? label = res["title"];
      String? outputImg = res["output_img"];
      List<dynamic> imShape = res["im_shape"];
      logger.i(res["bounds"]);
      logger.i(res["im_shape"]);
      List<dynamic> bounds = res["bounds"].map((v) => v.toDouble()).toList();

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
            logger.i(xScaleFactor);
            logger.i(yScaleFactor);
            logger.i(box.size);
            // final pos = box.localToGlobal(Offset.zero);
            // logger.i(box);
            // logger.i(pos);
            // logger.i(keyContext.size);

            // logger.i(box.s
            // ize.width);

            // logger.i("width  height");
            // logger.i(width);
            // logger.i(height);

            // double enlarge_factor = 1.3;
            // double x_adjustment = box.size.width * 0.1;

            double x1 = bounds[0] * xScaleFactor;
            double x2 = bounds[2] * xScaleFactor;

            // double y_adjustment =  box.size.width * 0.02;
            double y1 = bounds[1] * yScaleFactor;
            double y2 = bounds[3] * yScaleFactor;

// for emulator
//             double enlarge_factor = 1.3;
//             double x_adjustment = box.size.width * 0.1;
//             double x1 = math.max(bounds[0] - x_adjustment,box.size.width  );
//             double x2 =  math.max(bounds[2] * enlarge_factor - x_adjustment,box.size.width  )  ;
//
//             // double y_adjustment =  box.size.width * 0.02;
//             double y1 =  math.max(bounds[1],box.size.height) ;
//             double y2 =  math.max(bounds[3] * enlarge_factor,box.size.height );

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

      if (outputImg != null) {
        logger.i(res["bounds"]);
        setState(() {
          imgData = _base64ToImgData(outputImg);
        });
      } else {
        setState(() {
          imgData = null;
        });
      }
    }
  }

  void onTakePictureButtonPressed() async {
    pictureTaken = await takePicture();
    // setState(() {
    //   cropController.rect = initialCropArea!;
    // });

    setState(() {});
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
      floatingActionButton: _captureControlWidget(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: WillPopScope(
        onWillPop: () async {
          logger.w("Will pop scope");
          setState(() {
            pictureTaken = null;
          });
          return false;
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            SizedBox(
              height: size.height * .8,
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
                                      maxCrossAxisExtent: 200,
                                      // childAspectRatio: 3 / 2,
                                      crossAxisSpacing: 5,
                                      mainAxisSpacing: 5),
                              controller: scrollController,
                              itemCount: productData.length,
                              itemBuilder: (BuildContext context, int index) {
                                // logger.i(productData.runtimeType);
                                // logger.i(productData);

                                final Map<String, dynamic> prod =
                                    productData[index];

                                final bool showImg = !prod["img"]
                                    .toString()
                                    .toLowerCase()
                                    .contains("missing_product");

                                return Card(
                                    elevation: 10,
                                    margin: const EdgeInsets.only(
                                        top: 5,
                                        left: 10,
                                        right: 10,
                                        bottom: 10),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        children: [
                                          Text(
                                              "${index + 1}  " + prod["title"]),
                                          const SizedBox(
                                            height: 10,
                                          ),
                                          showImg
                                              ? Image.network(
                                                  prod["img"],
                                                  height: 70,
                                                )
                                              : Image.network(
                                                  "https://www.pnp.co.za" +
                                                      prod["img"]
                                                          .toString()
                                                          .replaceAll("140x140",
                                                              "400x400"),
                                                  height: 70,
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
            Container(
              // padding: EdgeInsets.all(2),
              // margin: EdgeInsets.all(20),

              color: Colors.red,
              child: Text(imgLabel ?? ""),
            ),

            _captureControlWidget(),
            // _modeControlRowWidget(),
            _cameraTogglesRowWidget(),

            // if (imgData != null)
            //   Container(
            //     child: imgData,
            //   )
          ],
        ),
      ),
    );
  }

  Widget _buildCropWidget() {
    return Container(
      // decoration: BoxDecoration(
      //   color: Colors.yellow
      // ),
      child: Crop(
        key: cropAreaKey,
        onCropped: onCropped,
        image: File(pictureTaken!.path).readAsBytesSync(),

        onMoved: (rect) {
          logger.i(rect.toString());
        },
        // initialAreaBuilder: (rect)  {
        //
        //
        //   return rect;
        // },
        //   logger.i(rect.toString());
        //   return initialCropArea!;
        //
        // },
        // radius: 40,
        // initialArea: initialCropArea,
        // baseColor: Colors.blue.shade900,
        baseColor: Colors.white,

        controller: cropController,
      ),
    );
  }

  /// Display the preview from the camera (or a message if the preview is not available).
  Widget _cameraPreviewWidget() {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return const Text(
        'Tap a camera',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
        ),
      );
    } else {
      // final size = MediaQuery.of(context).size;
      // final aspectRation = controller!.value.aspectRatio;
      // final deviceRatio = size.width / size.height;
      final scale = 1 /
          (controller!.value.aspectRatio *
              MediaQuery.of(context).size.aspectRatio);

      return Listener(
        onPointerDown: (_) => _pointers++,
        onPointerUp: (_) => _pointers--,
        child: CameraPreview(
          controller!,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: _handleScaleStart,
                onScaleUpdate: _handleScaleUpdate,
                onTapDown: (details) => onViewFinderTap(details, constraints),
              );
            },
          ),
        ),
      );

      //
      //   Transform.scale(
      //     scale: scale,
      //     child: ClipRRect(
      //       borderRadius:
      //           const BorderRadius.vertical(bottom: Radius.circular(20)),
      //       child: ,
      //     ),
      //   ),
      // );

      //   child: Transform.scale(
      //     scale: aspectRation / deviceRatio,
      //     child: AspectRatio(
      //       aspectRatio: aspectRation,
      //       child: ,
      //     ),
      //   ),
      // );

    }
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = _currentScale;
  }

  Future<void> _handleScaleUpdate(ScaleUpdateDetails details) async {
    // When there are not exactly two fingers on screen don't scale
    if (controller == null || _pointers != 2) {
      return;
    }

    _currentScale = (_baseScale * details.scale)
        .clamp(_minAvailableZoom, _maxAvailableZoom);

    await controller!.setZoomLevel(_currentScale);
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
              onPressed: controller != null ? onFlashModeButtonPressed : null,
            ),
            IconButton(
              icon: Icon(controller?.value.isCaptureOrientationLocked ?? false
                  ? Icons.screen_lock_rotation
                  : Icons.screen_rotation),
              color: Colors.blue,
              onPressed: controller != null
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
              color: controller?.value.flashMode == FlashMode.off
                  ? Colors.orange
                  : Colors.blue,
              onPressed: controller != null
                  ? () => onSetFlashModeButtonPressed(FlashMode.off)
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.flash_auto),
              color: controller?.value.flashMode == FlashMode.auto
                  ? Colors.orange
                  : Colors.blue,
              onPressed: controller != null
                  ? () => onSetFlashModeButtonPressed(FlashMode.auto)
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.flash_on),
              color: controller?.value.flashMode == FlashMode.always
                  ? Colors.orange
                  : Colors.blue,
              onPressed: controller != null
                  ? () => onSetFlashModeButtonPressed(FlashMode.always)
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.highlight),
              color: controller?.value.flashMode == FlashMode.torch
                  ? Colors.orange
                  : Colors.blue,
              onPressed: controller != null
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
    final CameraController? cameraController = controller;

    return pictureTaken == null
        ? FloatingActionButton(
            child: const Icon(Icons.camera_alt),
            // color: Colors.blue,
            onPressed: cameraController != null &&
                    cameraController.value.isInitialized &&
                    !cameraController.value.isRecordingVideo
                ? onTakePictureButtonPressed
                : null,
          )
        : FloatingActionButton(
            onPressed: () {
              cropController.crop();
              // setState(() {
              //   double width = MediaQuery.of(context).size.width;
              //   double height = MediaQuery.of(context).size.height;

              // final Image img =  Image.memory(File(pictureTaken!.path).readAsBytesSync(),);
              // logger.i(img.image);
              // logger.i(img.width);

              // Rect.fromPoints(Offset(width * 0.5, height * .5), Offset(width * 0.5, height * .5));
              //     .fromCenter(
              //     center: Offset(width * 0.5, height * .5),
              //     width: 30,
              //     height: 40
              // );
              // }
              // );
            }, // ,
            child: const Icon(Icons.search),
          );
  }

  /// Display a row of toggle to select the camera (or a message if no camera is available).
  Widget _cameraTogglesRowWidget() {
    final List<Widget> toggles = <Widget>[];

    void onChanged(CameraDescription? description) {
      if (description == null) {
        return;
      }
      setState(() {
        pictureTaken = null;
      });
      onNewCameraSelected(description);
    }

    if (widget.availableCameras.isEmpty) {
      return const Text('No camera found');
    } else {
      // for (CameraDescription cameraDescription in widget.availableCameras) {
      //   controller != null && controller!.value.isRecordingVideo
      //                   ? null
      //                   :  onChanged(cameraDescription);
      //   break;
      // }

      // dynamically generate list of available cameras
      for (CameraDescription cameraDescription in widget.availableCameras) {
        toggles.add(
          SizedBox(
            width: 90.0,
            child: RadioListTile<CameraDescription>(
              title: Icon(getCameraLensIcon(cameraDescription.lensDirection)),
              groupValue: controller?.description,
              value: cameraDescription,
              onChanged:
                  controller != null && controller!.value.isRecordingVideo
                      ? null
                      : onChanged,
            ),
          ),
        );
      }
    }

    return Row(mainAxisSize: MainAxisSize.min, children: toggles);
  }

  String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  void showInSnackBar(String message) {
    // ignore: deprecated_member_use
    _scaffoldKey.currentState?.showSnackBar(SnackBar(content: Text(message)));
  }

  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    if (controller == null) {
      return;
    }

    final CameraController cameraController = controller!;

    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    cameraController.setExposurePoint(offset);
    cameraController.setFocusPoint(offset);
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    if (controller != null) {
      await controller!.dispose();
    }

    final CameraController cameraController = CameraController(
      cameraDescription,
      kIsWeb ? ResolutionPreset.max : ResolutionPreset.medium,
      enableAudio: enableAudio,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    controller = cameraController;

    // If the controller is updated then update the UI.
    cameraController.addListener(() {
      if (mounted) setState(() {});
      if (cameraController.value.hasError) {
        showInSnackBar(
            'Camera error ${cameraController.value.errorDescription}');
      }
    });

    try {
      await cameraController.initialize();
      await Future.wait([
        // The exposure mode is currently not supported on the web.
        // ...(!kIsWeb
        //     ? [
        //         cameraController
        //             .getMinExposureOffset()
        //             .then((value) => _minAvailableExposureOffset = value),
        //         cameraController
        //             .getMaxExposureOffset()
        //             .then((value) => _maxAvailableExposureOffset = value)
        //       ]
        //     : []),
        cameraController
            .getMaxZoomLevel()
            .then((value) => _maxAvailableZoom = value),
        cameraController
            .getMinZoomLevel()
            .then((value) => _minAvailableZoom = value),
      ]);
    } on CameraException catch (e) {
      _showCameraException(e);
    }

    if (mounted) {
      setState(() {});
    }
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
      if (controller != null) {
        final CameraController cameraController = controller!;
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
    if (controller == null) {
      return;
    }

    try {
      await controller!.setFlashMode(mode);
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    }
  }

  Future<void> setFocusMode(FocusMode mode) async {
    if (controller == null) {
      return;
    }

    try {
      await controller!.setFocusMode(mode);
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    }
  }

  Future<XFile?> takePicture() async {
    final CameraController? cameraController = controller;
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
