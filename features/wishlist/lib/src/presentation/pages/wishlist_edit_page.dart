import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/wishlist_item.dart';
import '../bloc/wishlist_bloc.dart';
import '../bloc/wishlist_event.dart';

class WishlistEditPage extends StatefulWidget {
  const WishlistEditPage({
    super.key,
    required this.ownerId,
    this.existing,
  });

  final String ownerId;
  final WishlistItem? existing;

  @override
  State<WishlistEditPage> createState() => _WishlistEditPageState();
}

class _WishlistEditPageState extends State<WishlistEditPage> {
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

  void _save() {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final v = _formKey.currentState!.value;
    final item = WishlistItem(
      id: widget.existing?.id ?? generateId(),
      ownerId: widget.ownerId,
      name: v['name'] as String,
      description: v['description'] as String?,
      imageUrls: _images,
      latitude: _place?.latitude,
      longitude: _place?.longitude,
      placeLabel: v['place'] as String?,
      isHidden: _hidden,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    if (widget.existing == null) {
      context.read<WishlistBloc>().add(WishlistAdd(item));
    } else {
      context.read<WishlistBloc>().add(WishlistUpdate(item));
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add wish' : 'Edit wish'),
        actions: [
          if (widget.existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                context.read<WishlistBloc>().add(
                  WishlistDelete(widget.existing!.id),
                );
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
                label: 'Pick images',
                outlined: true,
                icon: Icons.photo_library_outlined,
                onPressed: _pickImages,
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'name',
                validator: FormBuilderValidators.required(),
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'description',
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'place',
                decoration: const InputDecoration(
                  labelText: 'Place label (e.g. store name)',
                ),
              ),
              const SizedBox(height: 12),
              const Text('Mark place on map where this item sells'),
              const SizedBox(height: 8),
              MapPicker(
                initial: _place,
                onPicked: (p) => setState(() => _place = p),
              ),
              SwitchListTile(
                title: const Text('Hide from others'),
                value: _hidden,
                onChanged: (v) => setState(() => _hidden = v),
              ),
              const SizedBox(height: 12),
              AppButton(label: 'Save', onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
