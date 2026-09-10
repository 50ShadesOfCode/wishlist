import 'package:carousel_slider/carousel_slider.dart';
import 'package:material_ui/material_ui.dart';

import '../../theme/app_dimens.dart';

class ItemCarousel extends StatefulWidget {
  const ItemCarousel({super.key, required this.imageUrls, this.height = 220});

  final List<String> imageUrls;
  final double height;

  @override
  State<ItemCarousel> createState() => _ItemCarouselState();
}

class _ItemCarouselState extends State<ItemCarousel> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(AppDimens.radiusM),
        ),
        child: const Center(child: Icon(Icons.image, size: 48)),
      );
    }
    return Column(
      children: [
        CarouselSlider.builder(
          itemCount: widget.imageUrls.length,
          itemBuilder: (context, i, _) => ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusM),
            child: Image.network(
              widget.imageUrls[i],
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, _, _) =>
                  const Center(child: Icon(Icons.broken_image)),
            ),
          ),
          options: CarouselOptions(
            height: widget.height,
            viewportFraction: 1,
            enableInfiniteScroll: widget.imageUrls.length > 1,
            onPageChanged: (i, _) => setState(() => _index = i),
          ),
        ),
        if (widget.imageUrls.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.imageUrls.length,
              (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _index == i ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _index == i
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
