import 'package:camera/camera.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_lense_clone/src/camera/camera_screen.dart';
import 'package:google_lense_clone/src/settings/settings_controller.dart';

import 'package:google_lense_clone/src//sample_feature/sample_item_details_view.dart';
import 'package:google_lense_clone/src//sample_feature/sample_item_list_view.dart';
import 'package:google_lense_clone/src/settings/settings_view.dart';






/// The Widget that configures your application.
class MyApp extends StatelessWidget {
  const MyApp({
    Key? key,
    required this.settingsController,
    required this.availableCameras,
  }) : super(key: key);

  final availableCameras;

  final SettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    // Glue the SettingsController to the MaterialApp.
    //
    // The AnimatedBuilder Widget listens to the SettingsController for changes.
    // Whenever the user updates their settings, the MaterialApp is rebuilt.
    return AnimatedBuilder(
      animation: settingsController,
      builder: (BuildContext context, Widget? child) {
        return MaterialApp(


          // Providing a restorationScopeId allows the Navigator built by the
          // MaterialApp to restore the navigation stack when a user leaves and
          // returns to the app after it has been killed while running in the
          // background.
          restorationScopeId: 'app',

          // Provide the generated AppLocalizations to the MaterialApp. This
          // allows descendant Widgets to display the correct translations
          // depending on the user's locale.
          localizationsDelegates: const [
            // AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', ''), // English, no country code
          ],

          // Use AppLocalizations to configure the correct application title
          // depending on the user's locale.
          //
          // The appTitle is defined in .arb files found in the localization
          // directory.
          // onGenerateTitle: (BuildContext context) =>
          //     AppLocalizations.of(context)!.appTitle,

          // Define a light and dark color theme. Then, read the user's
          // preferred ThemeMode (light, dark, or system default) from the
          // SettingsController to display the correct theme.
          theme: FlexThemeData.light(scheme: FlexScheme.bahamaBlue).copyWith(),
          darkTheme: FlexThemeData.dark( scheme: FlexScheme.bahamaBlue),

          themeMode: settingsController.themeMode,
          initialRoute: SampleItemListView.routeName,

          // Define a function to handle named routes in order to support
          // Flutter web url navigation and deep linking.
          onGenerateRoute: (RouteSettings routeSettings) {
            return MaterialPageRoute<void>(
              settings: routeSettings,
              builder: (BuildContext context) {
                switch (routeSettings.name) {
                  case CameraView.routeName:
                    return CameraView(
                        availableCameras: availableCameras
                    );
                  // case StreamPredictions.routeName:
                  //   return StreamPredictions(
                  //       availableCameras: availableCameras);

                  case SettingsView.routeName:
                    return SettingsView(controller: settingsController);
                  case SampleItemDetailsView.routeName:
                    return const SampleItemDetailsView();
                  case SampleItemListView.routeName:

                  default:
                    return const SampleItemListView();
                }
              },
            );
          },
        );
      },
    );
  }
}
