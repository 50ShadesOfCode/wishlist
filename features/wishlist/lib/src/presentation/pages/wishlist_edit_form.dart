import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/wishlist_item.dart';
import '../bloc/wishlist_bloc.dart';
import '../bloc/wishlist_event.dart';
import '../bloc/wishlist_state.dart';

/// Rejects picked images larger than this (after picker compression) before
/// they are attached to the wish.
const maxItemImageBytes = 10 * 1024 * 1024;

/// Maximum images attached to one wish (bounded multi-pick).
const maxItemImages = 10;

/// Location fix timeout: never hang the locate button indefinitely when GPS
/// stalls (e.g. indoors).
const locationTimeout = Duration(seconds: 15);

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

  /// Generated once per form instance: retries and rebuilds reuse the same
  /// id, so double-taps can never create duplicates.
  late final String _formId =
      widget.existing?.id ?? generateId();

  /// True between dispatching a save/delete and its completion. The pop
  /// happens only when the bloc reports success (see the BlocListener).
  bool _awaitingResult = false;

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
    late final List<XFile> files;
    try {
      files = await picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
        // Bounded multi-pick: hundreds of full-res images would OOM the
        // upload loop and DOS the storage bucket.
        limit: maxItemImages,
      );
    } catch (_) {
      // Permission denial etc.: stay silent, keep current images.
      return;
    }
    if (!mounted) return;
    // Byte-size guard per file: oversized picks are dropped before they are
    // attached (and later uploaded) to the wish.
    final accepted = <String>[];
    for (final f in files) {
      try {
        if (await f.length() <= maxItemImageBytes) accepted.add(f.path);
      } catch (_) {
        // Unreadable pick: skip it.
      }
    }
    if (!mounted) return;
    if (accepted.length < files.length) {
      showAppSnack(context, 'image_too_large'.tr());
    }
    setState(() => _images.addAll(accepted));
  }

  /// Resolves the device position for the map locate button. Throws a
  /// human-readable message on denial so the picker can report it. A
  /// permanent denial throws a distinct settings message — the caller
  /// surfaces it with an affordance to open the system settings.
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
      throw const LocationSettingsNeeded();
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(timeLimit: locationTimeout),
    ).timeout(
      locationTimeout,
      onTimeout: () => throw 'location_failed'.tr(),
    );
    return LatLng(pos.latitude, pos.longitude);
  }

  void _save() {
    if (_awaitingResult) return;
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final v = _formKey.currentState!.value;
    var placeLabel = v['place'] as String?;
    if ((placeLabel == null || placeLabel.trim().isEmpty) && _place != null) {
      // Keep label and pin consistent: a pin without a label gets coordinates.
      placeLabel = formatCoords(_place!);
      _formKey.currentState!.fields['place']?.didChange(placeLabel);
    }
    final item = WishlistItem(
      id: _formId,
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
    // The pop happens in the BlocListener on success only: failures surface
    // via AppErrorListener with the input intact for a retry.
    _awaitingResult = true;
    if (widget.existing == null) {
      BlocProvider.of<WishlistBloc>(context).add(WishlistAdd(item));
    } else {
      BlocProvider.of<WishlistBloc>(context).add(WishlistUpdate(item));
    }
  }

  void _delete() {
    final existing = widget.existing;
    if (existing == null || _awaitingResult) return;
    _awaitingResult = true;
    BlocProvider.of<WishlistBloc>(context).add(WishlistDelete(existing.id));
  }

  /// Pops only on the success emission that answers our pending save/delete.
  /// Failures keep the form (and its input) open; the error itself surfaces
  /// through [AppErrorListener].
  void _onBlocState(BuildContext context, WishlistState s) {
    if (!_awaitingResult || s.isLoading) return;
    if (s.error != null) {
      _awaitingResult = false;
      return;
    }
    _awaitingResult = false;
    // context.pop (not Navigator.pop): this page lives under a
    // StatefulShellRoute where Navigator.pop would escape the branch.
    if (context.mounted) context.pop();
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
              onPressed: _awaitingResult ? null : _delete,
            ),
        ],
      ),
      body: AppErrorListener<WishlistBloc, WishlistState>(
        errorOf: (s) => s.error,
        child: BlocListener<WishlistBloc, WishlistState>(
          listener: _onBlocState,
          child: BlocBuilder<WishlistBloc, WishlistState>(
            builder: (context, state) => SingleChildScrollView(
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
                      isLoading: state.isLoading,
                      onPressed: state.isLoading ? null : _pickImages,
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
                      decoration: InputDecoration(
                        labelText: 'description'.tr(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FormBuilderTextField(
                      name: 'place',
                      decoration: InputDecoration(
                        labelText: 'place_label'.tr(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('mark_place'.tr()),
                    const SizedBox(height: 8),
                    MapPicker(
                      initial: _place,
                      onPicked: (p) => setState(() => _place = p),
                      onLocateMe: _locateMe,
                      onOpenLocationSettings: () async {
                        await Geolocator.openAppSettings();
                      },
                      settingsLabel: 'open_settings'.tr(),
                    ),
                    SwitchListTile(
                      title: Text('hide_from_others'.tr()),
                      value: _hidden,
                      onChanged: state.isLoading
                          ? null
                          : (v) => setState(() => _hidden = v),
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'save'.tr(),
                      isLoading: state.isLoading,
                      onPressed: state.isLoading ? null : _save,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
