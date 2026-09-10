import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPicker extends StatefulWidget {
  const MapPicker({super.key, this.initial, required this.onPicked});

  final LatLng? initial;
  final ValueChanged<LatLng> onPicked;

  /// Default map center (Tashkent) when no location is picked yet.
  static const defaultCenter = LatLng(41.3111, 69.2406);

  /// Override at build time without touching source:
  /// `flutter run --dart-define=MAP_TILE_KEY=<key>`.
  /// The default below is a throwaway key — rotate it in the Tracetrack
  /// dashboard and stop committing real keys to the repo.
  static const tileKey = String.fromEnvironment(
    'MAP_TILE_KEY',
    defaultValue: 'cddcacc4f087563b33be09cfba45747f',
  );

  static String get tileTemplate =>
      'https://tile.tracestrack.com/_/{z}/{x}/{y}.webp?key=$tileKey';

  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  LatLng? _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final center = _picked ?? MapPicker.defaultCenter;
    return SizedBox(
      height: 260,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 12,
            onTap: (_, point) {
              setState(() => _picked = point);
              widget.onPicked(point);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: MapPicker.tileTemplate,
              userAgentPackageName: 'com.wishlist.wishlist_app',
            ),
            if (_picked != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _picked!,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 36,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
