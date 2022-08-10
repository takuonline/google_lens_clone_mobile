// import 'dart:async';
// import 'dart:io';
// import 'dart:typed_data';
// import 'package:extended_image/extended_image.dart';
// import 'package:logger/logger.dart';
//
// import 'package:camera/camera.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:video_player/video_player.dart';
// import 'package:image/image.dart' as image_lib;
//
// import 'dart:convert';
//
// import '../networking/api.dart';
//
// class CameraView extends StatefulWidget {
//   static const routeName = "/camera";
//
//   const CameraView({
//     Key? key,
//     required this.availableCameras,
//   }) : super(key: key);
//
//   // const CameraExampleView({required this.availableCameras});
//
//   final availableCameras;
//
//   @override
//   _CameraViewState createState() {
//     return _CameraViewState();
//   }
// }
//
// /// Returns a suitable camera icon for [direction].
// IconData getCameraLensIcon(CameraLensDirection direction) {
//   switch (direction) {
//     case CameraLensDirection.back:
//       return Icons.camera_rear;
//     case CameraLensDirection.front:
//       return Icons.camera_front;
//     case CameraLensDirection.external:
//       return Icons.camera;
//     default:
//       throw ArgumentError('Unknown lens direction');
//   }
// }
//
// void logError(String code, String? message) {
//   if (message != null) {
//     print('Error: $code\nError Message: $message');
//   } else {
//     print('Error: $code');
//   }
// }
//
// class _CameraViewState extends State<CameraView>
//     with WidgetsBindingObserver, TickerProviderStateMixin {
//   CameraController? controller;
//   XFile? imageFile;
//   XFile? videoFile;
//   VideoPlayerController? videoController;
//   VoidCallback? videoPlayerListener;
//   bool enableAudio = true;
//   final GlobalKey<ExtendedImageEditorState> editorKey =
//       GlobalKey<ExtendedImageEditorState>();
//
//   late AnimationController _flashModeControlRowAnimationController;
//   late Animation<double> _flashModeControlRowAnimation;
//   late AnimationController _exposureModeControlRowAnimationController;
//   late AnimationController _focusModeControlRowAnimationController;
//   double _minAvailableZoom = 1.0;
//   double _maxAvailableZoom = 1.0;
//   double _currentScale = 1.0;
//   double _baseScale = 1.0;
//   Uint8List? imgData;
//   XFile? pictureTaken;
//   String? imgLabel;
//   // Counting pointers (number of user fingers on screen)
//   int _pointers = 0;
//
//   @override
//   void initState() {
//     super.initState();
//     getAvailableCameras();
//     _ambiguate(WidgetsBinding.instance)?.addObserver(this);
//
//     _flashModeControlRowAnimationController = AnimationController(
//       duration: const Duration(milliseconds: 300),
//       vsync: this,
//     );
//     _flashModeControlRowAnimation = CurvedAnimation(
//       parent: _flashModeControlRowAnimationController,
//       curve: Curves.easeInCubic,
//     );
//     _exposureModeControlRowAnimationController = AnimationController(
//       duration: const Duration(milliseconds: 300),
//       vsync: this,
//     );
//
//     _focusModeControlRowAnimationController = AnimationController(
//       duration: const Duration(milliseconds: 300),
//       vsync: this,
//     );
//   }
//
//   Future<void> getAvailableCameras() async {
//     cameras = await widget.availableCameras;
//     // return cameras;
//
//     // var a =await widget.availableCameras();
//     print(cameras);
//   }
//
//   @override
//   void dispose() {
//     _ambiguate(WidgetsBinding.instance)?.removeObserver(this);
//     _flashModeControlRowAnimationController.dispose();
//     _exposureModeControlRowAnimationController.dispose();
//     super.dispose();
//   }
//
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     final CameraController? cameraController = controller;
//
//     // App state changed before we got the chance to initialize.
//     if (cameraController == null || !cameraController.value.isInitialized) {
//       return;
//     }
//
//     if (state == AppLifecycleState.inactive) {
//       cameraController.dispose();
//     } else if (state == AppLifecycleState.resumed) {
//       onNewCameraSelected(cameraController.description);
//     }
//   }
//
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//   List<CameraDescription> cameras = [];
//   final logger = Logger();
//
//   String? getHealthCheck() {
//     ApiService? api = context.read<ApiService?>();
//     api?.getHealthCheck();
//   }
//
//   Uint8List imageFromBase64String(String base64String) {
//     return base64Decode(base64String);
//   }
//
//   clipImg(){
//
//     final ExtendedImageEditorState? state = editorKey.currentState;
//     final EditActionDetails? action = state?.editAction!;
//
//     final Rect? rect = state?.getCropRect();
//     rect?.shift(Offset(90, 50));
//
//
//     // final Uint8List? rawClipImageData = state?.rawImageData;
//
//   }
//
//   void onTakePictureButtonPressed() async {
//     ApiService? api = context.read<ApiService?>();
//
//     setState(() async {
//       pictureTaken = await takePicture();
//     });
//
//     if (pictureTaken != null) {
//       final base64Img = await imageToBase64(pictureTaken!);
//       logger.i(base64Img.runtimeType);
//       final Map<String, dynamic>? res = await api?.postImage(base64Img);
//
//       if (res != null) {
//         String? label = res["title"];
//         String? output_img = res["output_img"];
//         if (label != null) {
//           setState(() {
//             imgLabel = label;
//           });
//           logger.i(label);
//         } else {
//           setState(() {
//             imgLabel = null;
//           });
//         }
//
//         if (output_img != null) {
//           logger.i(res["bounds"]);
//           setState(() {
//             imgData = imageFromBase64String(output_img);
//           });
//         } else {
//           setState(() {
//             imgData = null;
//           });
//         }
//       }
//     }
//
//     // if (mounted) {
//     //   setState(() {
//     //     imageFile = file;
//     //     videoController?.dispose();
//     //     videoController = null;
//     //   });
//     //   if (file != null) showInSnackBar('Picture saved to ${file.path}');
//     // }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     MediaQueryData queryData;
//     queryData = MediaQuery.of(context);
//     return Scaffold(
//       floatingActionButton: pictureTaken != null
//           ? FloatingActionButton(
//               onPressed: clipImg,
//               child: Icon(Icons.camera),
//             )
//           : null,
//       key: _scaffoldKey,
//       // appBar: AppBar(
//       //   title: const Text('Camera example'),
//       // ),
//       body: Column(
//         mainAxisAlignment: MainAxisAlignment.start,
//         mainAxisSize: MainAxisSize.max,
//         children: <Widget>[
//           Expanded(
//             child: Stack(
//                 alignment: Alignment.topCenter,
//               children: [
//                 Container(
//                   child: _cameraPreviewWidget(),
//
//                   // decoration: BoxDecoration(
//                   //   color: Colors.black,
//                   //   border: Border.all(
//                   //     color:
//                   //         controller != null && controller!.value.isRecordingVideo
//                   //             ? Colors.redAccent
//                   //             : Colors.grey,
//                   //     width: 3.0,
//                   //   ),
//                   // ),
//
//
//                 ),
//                 if (pictureTaken != null)
//                   Positioned.fill(
//                     child: Align(
//                       alignment: Alignment.topCenter,
//                       child: ExtendedImage.file(
//                         File(pictureTaken!.path),
//
//                         width: 400,
//                         border: null,
//
//                         height: double.infinity,
//                         alignment: Alignment.bottomRight,
//
//                         // borderRadius: BorderRadius.circular(50),
//
//                         // width: 400,
//                         shape: BoxShape.rectangle,
//                         fit: BoxFit.contain,
//                         mode: ExtendedImageMode.editor,
//                         extendedImageEditorKey: editorKey,
//
//                         initEditorConfigHandler: (state) {
//
//                           return EditorConfig(
//                             maxScale: 8.0,
//
//                             // initialCropAspectRatio: ,
//                             //          cornerSize: Size(40,20),
//
//                              cropRectPadding: EdgeInsets.all(50.0),
//                             hitTestSize: 20.0,
//                             // cropAspectRatio: queryData.devicePixelRatio
//                           );
//                         },
//                       ),
//                     ),
//                   )
//               ],
//             ),
//           ),
//           Container(
//             child: Text(imgLabel ?? ""),
//           ),
//           _captureControlRowWidget(),
//           // _modeControlRowWidget(),
//           _cameraTogglesRowWidget(),
//
//           // if (imgData != null)
//           //   Container(
//           //     child: imgData,
//           //   )
//         ],
//       ),
//     );
//   }
//
//   /// Display the preview from the camera (or a message if the preview is not available).
//   Widget _cameraPreviewWidget() {
//     final CameraController? cameraController = controller;
//
//     if (cameraController == null || !cameraController.value.isInitialized) {
//       return const Text(
//         'Tap a camera',
//         style: TextStyle(
//           color: Colors.white,
//           fontSize: 24.0,
//           fontWeight: FontWeight.w900,
//         ),
//       );
//     } else {
//       return Listener(
//         onPointerDown: (_) => _pointers++,
//         onPointerUp: (_) => _pointers--,
//         child: CameraPreview(
//           controller!,
//           child: LayoutBuilder(
//               builder: (BuildContext context, BoxConstraints constraints) {
//             return GestureDetector(
//               behavior: HitTestBehavior.opaque,
//               onScaleStart: _handleScaleStart,
//               onScaleUpdate: _handleScaleUpdate,
//               onTapDown: (details) => onViewFinderTap(details, constraints),
//             );
//           }),
//         ),
//       );
//     }
//   }
//
//   void _handleScaleStart(ScaleStartDetails details) {
//     _baseScale = _currentScale;
//   }
//
//   Future<void> _handleScaleUpdate(ScaleUpdateDetails details) async {
//     // When there are not exactly two fingers on screen don't scale
//     if (controller == null || _pointers != 2) {
//       return;
//     }
//
//     _currentScale = (_baseScale * details.scale)
//         .clamp(_minAvailableZoom, _maxAvailableZoom);
//
//     await controller!.setZoomLevel(_currentScale);
//   }
//
//   /// Display the thumbnail of the captured image or video.
//   Widget _thumbnailWidget() {
//     final VideoPlayerController? localVideoController = videoController;
//
//     return Expanded(
//       child: Align(
//         alignment: Alignment.centerRight,
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: <Widget>[
//             localVideoController == null && imageFile == null
//                 ? Container()
//                 : SizedBox(
//                     child: (localVideoController == null)
//                         ? (
//                             // The captured image on the web contains a network-accessible URL
//                             // pointing to a location within the browser. It may be displayed
//                             // either with Image.network or Image.memory after loading the image
//                             // bytes to memory.
//                             kIsWeb
//                                 ? Image.network(imageFile!.path)
//                                 : Image.file(File(imageFile!.path)))
//                         : Container(
//                             child: Center(
//                               child: AspectRatio(
//                                   aspectRatio:
//                                       localVideoController.value.size != null
//                                           ? localVideoController
//                                               .value.aspectRatio
//                                           : 1.0,
//                                   child: VideoPlayer(localVideoController)),
//                             ),
//                             decoration: BoxDecoration(
//                                 border: Border.all(color: Colors.pink)),
//                           ),
//                     width: 64.0,
//                     height: 64.0,
//                   ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   /// Display a bar with buttons to change the flash and exposure modes
//   Widget _modeControlRowWidget() {
//     return Column(
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           mainAxisSize: MainAxisSize.max,
//           children: <Widget>[
//             IconButton(
//               icon: Icon(Icons.flash_on),
//               color: Colors.blue,
//               onPressed: controller != null ? onFlashModeButtonPressed : null,
//             ),
//             IconButton(
//               icon: Icon(controller?.value.isCaptureOrientationLocked ?? false
//                   ? Icons.screen_lock_rotation
//                   : Icons.screen_rotation),
//               color: Colors.blue,
//               onPressed: controller != null
//                   ? onCaptureOrientationLockButtonPressed
//                   : null,
//             ),
//           ],
//         ),
//         _flashModeControlRowWidget(),
//       ],
//     );
//   }
//
//   Widget _flashModeControlRowWidget() {
//     return SizeTransition(
//       sizeFactor: _flashModeControlRowAnimation,
//       child: ClipRect(
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           mainAxisSize: MainAxisSize.max,
//           children: [
//             IconButton(
//               icon: Icon(Icons.flash_off),
//               color: controller?.value.flashMode == FlashMode.off
//                   ? Colors.orange
//                   : Colors.blue,
//               onPressed: controller != null
//                   ? () => onSetFlashModeButtonPressed(FlashMode.off)
//                   : null,
//             ),
//             IconButton(
//               icon: Icon(Icons.flash_auto),
//               color: controller?.value.flashMode == FlashMode.auto
//                   ? Colors.orange
//                   : Colors.blue,
//               onPressed: controller != null
//                   ? () => onSetFlashModeButtonPressed(FlashMode.auto)
//                   : null,
//             ),
//             IconButton(
//               icon: Icon(Icons.flash_on),
//               color: controller?.value.flashMode == FlashMode.always
//                   ? Colors.orange
//                   : Colors.blue,
//               onPressed: controller != null
//                   ? () => onSetFlashModeButtonPressed(FlashMode.always)
//                   : null,
//             ),
//             IconButton(
//               icon: Icon(Icons.highlight),
//               color: controller?.value.flashMode == FlashMode.torch
//                   ? Colors.orange
//                   : Colors.blue,
//               onPressed: controller != null
//                   ? () => onSetFlashModeButtonPressed(FlashMode.torch)
//                   : null,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   /// Display the control bar with buttons to take pictures and record videos.
//   Widget _captureControlRowWidget() {
//     final CameraController? cameraController = controller;
//
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//       mainAxisSize: MainAxisSize.max,
//       children: <Widget>[
//         IconButton(
//           icon: const Icon(Icons.camera_alt),
//           color: Colors.blue,
//           onPressed: cameraController != null &&
//                   cameraController.value.isInitialized &&
//                   !cameraController.value.isRecordingVideo
//               ? onTakePictureButtonPressed
//               : null,
//         ),
//       ],
//     );
//   }
//
//   /// Display a row of toggle to select the camera (or a message if no camera is available).
//   Widget _cameraTogglesRowWidget() {
//     final List<Widget> toggles = <Widget>[];
//
//     final onChanged = (CameraDescription? description) {
//       if (description == null) {
//         return;
//       }
//
//       onNewCameraSelected(description);
//     };
//
//     if (widget.availableCameras.isEmpty) {
//       return const Text('No camera found');
//     } else {
//       // for (CameraDescription cameraDescription in widget.availableCameras) {
//       //   controller != null && controller!.value.isRecordingVideo
//       //                   ? null
//       //                   :  onChanged(cameraDescription);
//       //   break;
//       // }
//
//       // dynamically generate list of available cameras
//       for (CameraDescription cameraDescription in widget.availableCameras) {
//         toggles.add(
//           SizedBox(
//             width: 90.0,
//             child: RadioListTile<CameraDescription>(
//               title: Icon(getCameraLensIcon(cameraDescription.lensDirection)),
//               groupValue: controller?.description,
//               value: cameraDescription,
//               onChanged:
//                   controller != null && controller!.value.isRecordingVideo
//                       ? null
//                       : onChanged,
//             ),
//           ),
//         );
//       }
//     }
//
//     return Row(children: toggles);
//   }
//
//   String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();
//
//   void showInSnackBar(String message) {
//     // ignore: deprecated_member_use
//     _scaffoldKey.currentState?.showSnackBar(SnackBar(content: Text(message)));
//   }
//
//   void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
//     if (controller == null) {
//       return;
//     }
//
//     final CameraController cameraController = controller!;
//
//     final offset = Offset(
//       details.localPosition.dx / constraints.maxWidth,
//       details.localPosition.dy / constraints.maxHeight,
//     );
//     cameraController.setExposurePoint(offset);
//     cameraController.setFocusPoint(offset);
//   }
//
//   void onNewCameraSelected(CameraDescription cameraDescription) async {
//     if (controller != null) {
//       await controller!.dispose();
//     }
//
//     final CameraController cameraController = CameraController(
//       cameraDescription,
//       kIsWeb ? ResolutionPreset.max : ResolutionPreset.medium,
//       enableAudio: enableAudio,
//       imageFormatGroup: ImageFormatGroup.jpeg,
//     );
//
//     controller = cameraController;
//
//     // If the controller is updated then update the UI.
//     cameraController.addListener(() {
//       if (mounted) setState(() {});
//       if (cameraController.value.hasError) {
//         showInSnackBar(
//             'Camera error ${cameraController.value.errorDescription}');
//       }
//     });
//
//     try {
//       await cameraController.initialize();
//       await Future.wait([
//         // The exposure mode is currently not supported on the web.
//         // ...(!kIsWeb
//         //     ? [
//         //         cameraController
//         //             .getMinExposureOffset()
//         //             .then((value) => _minAvailableExposureOffset = value),
//         //         cameraController
//         //             .getMaxExposureOffset()
//         //             .then((value) => _maxAvailableExposureOffset = value)
//         //       ]
//         //     : []),
//         cameraController
//             .getMaxZoomLevel()
//             .then((value) => _maxAvailableZoom = value),
//         cameraController
//             .getMinZoomLevel()
//             .then((value) => _minAvailableZoom = value),
//       ]);
//     } on CameraException catch (e) {
//       _showCameraException(e);
//     }
//
//     if (mounted) {
//       setState(() {});
//     }
//   }
//
//   Future<String> imageToBase64(XFile file, {int? height}) async {
//     final image = image_lib.decodeImage(await file.readAsBytes())!;
//     // final resizedImage = copyResize(image, height: height ?? 800);
//     return base64Encode(image_lib.encodeJpg(image));
//   }
//
//   void onFlashModeButtonPressed() {
//     if (_flashModeControlRowAnimationController.value == 1) {
//       _flashModeControlRowAnimationController.reverse();
//     } else {
//       _flashModeControlRowAnimationController.forward();
//       _exposureModeControlRowAnimationController.reverse();
//       _focusModeControlRowAnimationController.reverse();
//     }
//   }
//
//   void onSetFlashModeButtonPressed(FlashMode mode) {
//     setFlashMode(mode).then((_) {
//       if (mounted) setState(() {});
//       showInSnackBar('Flash mode set to ${mode.toString().split('.').last}');
//     });
//   }
//
//   void onCaptureOrientationLockButtonPressed() async {
//     try {
//       if (controller != null) {
//         final CameraController cameraController = controller!;
//         if (cameraController.value.isCaptureOrientationLocked) {
//           await cameraController.unlockCaptureOrientation();
//           showInSnackBar('Capture orientation unlocked');
//         } else {
//           await cameraController.lockCaptureOrientation();
//           showInSnackBar(
//               'Capture orientation locked to ${cameraController.value.lockedCaptureOrientation.toString().split('.').last}');
//         }
//       }
//     } on CameraException catch (e) {
//       _showCameraException(e);
//     }
//   }
//
//   Future<void> setFlashMode(FlashMode mode) async {
//     if (controller == null) {
//       return;
//     }
//
//     try {
//       await controller!.setFlashMode(mode);
//     } on CameraException catch (e) {
//       _showCameraException(e);
//       rethrow;
//     }
//   }
//
//   Future<void> setFocusMode(FocusMode mode) async {
//     if (controller == null) {
//       return;
//     }
//
//     try {
//       await controller!.setFocusMode(mode);
//     } on CameraException catch (e) {
//       _showCameraException(e);
//       rethrow;
//     }
//   }
//
//   Future<XFile?> takePicture() async {
//     final CameraController? cameraController = controller;
//     if (cameraController == null || !cameraController.value.isInitialized) {
//       showInSnackBar('Error: select a camera first.');
//       return null;
//     }
//
//     if (cameraController.value.isTakingPicture) {
//       // A capture is already pending, do nothing.
//       return null;
//     }
//
//     try {
//       XFile file = await cameraController.takePicture();
//       return file;
//     } on CameraException catch (e) {
//       _showCameraException(e);
//       return null;
//     }
//   }
//
//   void _showCameraException(CameraException e) {
//     logError(e.code, e.description);
//     showInSnackBar('Error: ${e.code}\n${e.description}');
//   }
// }
//
// /// This allows a value of type T or T? to be treated as a value of type T?.
// ///
// /// We use this so that APIs that have become non-nullable can still be used
// /// with `!` and `?` on the stable branch.
// // TODO(ianh): Remove this once we roll stable in late 2021.
// T? _ambiguate<T>(T? value) => value;
