import 'package:material_ui/material_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Formats a pin for display and as a fallback place label.
String formatCoords(LatLng p) =>
    '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';

class MapPicker extends StatefulWidget {
  const MapPicker({
    super.key,
    this.initial,
    required this.onPicked,
    this.onLocateMe,
    this.onLocateError,
  });

  final LatLng? initial;
  final ValueChanged<LatLng> onPicked;

  /// Optional current-location resolver (implemented by the caller so this
  /// package does not depend on geolocator). When provided, a locate button
  /// appears that moves the map and drops the pin at the user's position.
  /// Throwing (e.g. permission denied) is reported via [onLocateError].
  final Future<LatLng> Function()? onLocateMe;

  /// Shown when [onLocateMe] fails; defaults to a snackbar.
  final ValueChanged<Object>? onLocateError;

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
  bool _locating = false;
  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _place(LatLng point) {
    setState(() => _picked = point);
    widget.onPicked(point);
  }

  Future<void> _locate() async {
    final locate = widget.onLocateMe;
    if (locate == null || _locating) return;
    setState(() => _locating = true);
    try {
      final pos = await locate();
      _mapController.move(pos, 14);
      _place(pos);
    } catch (e) {
      if (widget.onLocateError != null) {
        widget.onLocateError!(e);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'location_failed'.tr()}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _picked ?? MapPicker.defaultCenter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 260,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 12,
                    onTap: (_, point) => _place(point),
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
                if (widget.onLocateMe != null)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: FloatingActionButton.small(
                      heroTag: 'map_locate',
                      tooltip: 'use_location'.tr(),
                      onPressed: _locate,
                      child: _locating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.my_location_outlined),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_picked != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              formatCoords(_picked!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
