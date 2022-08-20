import 'package:camera/camera.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_lense_clone/src/networking/api.dart';

import 'src/app.dart';
import 'src/settings/settings_controller.dart';
import 'src/settings/settings_service.dart';
import 'package:provider/provider.dart';
// List<CameraDescription> cameras = [];









void main() async {


  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Set up the SettingsController, which will glue user settings to multiple
  // Flutter Widgets.

  final settingsController = SettingsController(SettingsService());

  WidgetsFlutterBinding.ensureInitialized();
  // Obtain a list of the available cameras on the device.
  List<CameraDescription> cameras = await availableCameras();

  // Load the user's preferred theme while the splash screen is displayed.
  // This prevents a sudden theme change when the app is first displayed.
  await settingsController.loadSettings();

  // Run the app and pass in the SettingsController. The app listens to the
  // SettingsController for changes, then passes it further down to the
  // SettingsView.
  runApp(MultiProvider(
      providers: [
        ChangeNotifierProvider<ApiService>(create: (_) => ApiService()),
      ],
      child: MyApp(
          settingsController: settingsController, availableCameras: cameras)));
}
