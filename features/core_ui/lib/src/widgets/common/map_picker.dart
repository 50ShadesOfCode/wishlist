import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPicker extends StatefulWidget {
  const MapPicker({super.key, this.initial, required this.onPicked});

  final LatLng? initial;
  final ValueChanged<LatLng> onPicked;

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
    final center = _picked ?? const LatLng(41.3111, 69.2406);
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
              //urlTemplate: 'http://tile.openstreetmap.org/{z}/{x}/{y}.png',
              urlTemplate: 'https://tile.tracestrack.com/_/{z}/{x}/{y}.webp?key=cddcacc4f087563b33be09cfba45747f',
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
