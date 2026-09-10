import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/wishlist_item.dart';
import '../bloc/wishlist_bloc.dart';
import '../bloc/wishlist_event.dart';

/// Add/edit wish screen UI. Requires a [WishlistBloc] above it in the tree
/// (provided by [WishlistEditPage]).
class WishlistEditForm extends StatefulWidget {
  const WishlistEditForm({
    super.key,
    required this.ownerId,
    this.existing,
    this.onDiscuss,
  });

  final String ownerId;
  final WishlistItem? existing;

  /// Opens (creating if needed) the secret chat for [existing]. Null hides
  /// the discuss action. Wired by the app router, which owns navigation and
  /// the chat repository.
  final Future<void> Function(WishlistItem item)? onDiscuss;

  @override
  State<WishlistEditForm> createState() => _WishlistEditFormState();
}

class _WishlistEditFormState extends State<WishlistEditForm> {
  final _formKey = GlobalKey<FormBuilderState>();
  final List<String> _images = [];
  LatLng? _place;
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _images.addAll(e.imageUrls);
      if (e.latitude != null && e.longitude != null) {
        _place = LatLng(e.latitude!, e.longitude!);
      }
      _hidden = e.isHidden;
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage();
    setState(() => _images.addAll(files.map((f) => f.path)));
  }

  /// Resolves the device position for the map locate button. Throws a
  /// human-readable message on denial so the picker can report it.
  Future<LatLng> _locateMe() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'location_failed'.tr();
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw 'location_failed'.tr();
    }
    if (permission == LocationPermission.deniedForever) {
      throw 'location_failed'.tr();
    }
    final pos = await Geolocator.getCurrentPosition();
    return LatLng(pos.latitude, pos.longitude);
  }

  void _save() {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final v = _formKey.currentState!.value;
    var placeLabel = v['place'] as String?;
    if ((placeLabel == null || placeLabel.trim().isEmpty) && _place != null) {
      // Keep label and pin consistent: a pin without a label gets coordinates.
      placeLabel = formatCoords(_place!);
      _formKey.currentState!.fields['place']?.didChange(placeLabel);
    }
    final item = WishlistItem(
      id: widget.existing?.id ?? generateId(),
      ownerId: widget.ownerId,
      name: v['name'] as String,
      description: v['description'] as String?,
      imageUrls: _images,
      latitude: _place?.latitude,
      longitude: _place?.longitude,
      placeLabel: placeLabel,
      isHidden: _hidden,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    if (widget.existing == null) {
      BlocProvider.of<WishlistBloc>(context).add(WishlistAdd(item));
    } else {
      BlocProvider.of<WishlistBloc>(context).add(WishlistUpdate(item));
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'add_wish'.tr() : 'edit_wish'.tr(),
        ),
        actions: [
          if (widget.existing != null && widget.onDiscuss != null)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'discuss_wish'.tr(),
              onPressed: () => widget.onDiscuss!(widget.existing!),
            ),
          if (widget.existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                BlocProvider.of<WishlistBloc>(context)
                    .add(WishlistDelete(widget.existing!.id));
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: FormBuilder(
          key: _formKey,
          initialValue: {
            'name': widget.existing?.name,
            'description': widget.existing?.description,
            'place': widget.existing?.placeLabel,
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_images.isNotEmpty) ItemCarousel(imageUrls: _images),
              AppButton(
                label: 'pick_images'.tr(),
                outlined: true,
                icon: Icons.photo_library_outlined,
                onPressed: _pickImages,
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'name',
                validator: AppValidators.requiredField,
                decoration: InputDecoration(labelText: 'name'.tr()),
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'description',
                maxLines: 3,
                decoration: InputDecoration(labelText: 'description'.tr()),
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'place',
                decoration: InputDecoration(labelText: 'place_label'.tr()),
              ),
              const SizedBox(height: 12),
              Text('mark_place'.tr()),
              const SizedBox(height: 8),
              MapPicker(
                initial: _place,
                onPicked: (p) => setState(() => _place = p),
                onLocateMe: _locateMe,
              ),
              SwitchListTile(
                title: Text('hide_from_others'.tr()),
                value: _hidden,
                onChanged: (v) => setState(() => _hidden = v),
              ),
              const SizedBox(height: 12),
              AppButton(label: 'save'.tr(), onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
