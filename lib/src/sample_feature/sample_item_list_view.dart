import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_lense_clone/src/camera/camera_screen.dart';
import 'package:google_lense_clone/src/networking/api.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../settings/settings_view.dart';
import 'sample_item.dart';
import 'sample_item_details_view.dart';

/// Displays a list of SampleItems.
class SampleItemListView extends StatefulWidget {
  const SampleItemListView({
    Key? key,
    this.items = const [
      SampleItem(1),
      SampleItem(2),
      SampleItem(3),
      SampleItem(4),
      SampleItem(5)
    ],
  }) : super(key: key);

  static const routeName = '/';

  final List<SampleItem> items;

  @override
  State<SampleItemListView> createState() => _SampleItemListViewState();
}

class _SampleItemListViewState extends State<SampleItemListView> {
  final logger = Logger();

  String? getHealthCheck() {
    ApiService api = ApiService();
    api.getHealthCheck();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: getHealthCheck),
      appBar: AppBar(
        title: const Text('Sample Items'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to the settings page. If the user leaves and returns
              // to the app after it has been killed while running in the
              // background, the navigation stack is restored.
              Navigator.restorablePushNamed(context, SettingsView.routeName);
            },
          ),
        ],
      ),

      // To work with lists that may contain a large number of items, it’s best
      // to use the ListView.builder constructor.
      //
      // In contrast to the default ListView constructor, which requires
      // building all Widgets up front, the ListView.builder constructor lazily
      // builds Widgets as they’re scrolled into view.
      body: ListView.builder(
        // Providing a restorationId allows the ListView to restore the
        // scroll position when a user leaves and returns to the app after it
        // has been killed while running in the background.
        restorationId: 'sampleItemListView',
        itemCount: widget.items.length,
        itemBuilder: (BuildContext context, int index) {
          final item = widget.items[index];

          String _routeName = "";
          Widget _title = Text('SampleItem ${item.id}');

          if (index == 3) {
            _routeName = CameraView.routeName;
            _title = Text('Camera Example View  ');
          } else {
            _routeName = SampleItemDetailsView.routeName;
          }

          Widget tile = ListTile(
              title: _title,
              leading:
                  // Display the Flutter Logo image asset.
                  const FlutterLogo(),
              onTap: () {
                // Navigate to the details page. If the user leaves and returns to
                // the app after it has been killed while running in the
                // background, the navigation stack is restored.
                Navigator.pushNamed(
                  context,
                  _routeName,
                );
              });

          return tile;
        },
      ),
    );
  }
}
