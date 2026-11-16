import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Animated shimmer wrapper that overlays a sweeping highlight gradient
/// across all solid child widgets.
///
/// Respects [reduceAnimations]: when enabled, the animation controller is
/// stopped and static placeholders are rendered to prevent battery/GPU load.
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final bool reduceAnimations;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.isLoading = true,
    this.reduceAnimations = false,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.isLoading && !widget.reduceAnimations) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(ShimmerLoading oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !widget.reduceAnimations) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) {
      return widget.child;
    }

    if (widget.reduceAnimations) {
      return widget.child;
    }

    final base = widget.baseColor ?? AppTheme.skeletonBaseOf(context);
    final highlight =
        widget.highlightColor ?? AppTheme.skeletonHighlightOf(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-2.0 + 4.0 * _controller.value, -0.3),
              end: Alignment(-0.5 + 4.0 * _controller.value, 0.3),
              colors: [
                base,
                highlight,
                base,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A single rounded placeholder box used in skeleton screens.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final EdgeInsetsGeometry? margin;
  final Color? color;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.margin,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppTheme.skeletonBaseOf(context);
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: bg,
        shape: shape,
        borderRadius:
            shape == BoxShape.rectangle ? (borderRadius ?? BorderRadius.circular(8)) : null,
      ),
    );
  }
}

/// Dashboard Skeleton Loader.
/// Displays 3 discovery rail placeholders matching `_DiscoveryRail` layout.
class DashboardSkeleton extends StatelessWidget {
  final bool reduceAnimations;

  const DashboardSkeleton({
    super.key,
    this.reduceAnimations = false,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      isLoading: true,
      reduceAnimations: reduceAnimations,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _DiscoveryRailSkeleton(titleWidth: 140, subtitleWidth: 95),
          SizedBox(height: 32),
          _DiscoveryRailSkeleton(titleWidth: 175, subtitleWidth: 120),
          SizedBox(height: 32),
          _DiscoveryRailSkeleton(titleWidth: 155, subtitleWidth: 85),
        ],
      ),
    );
  }
}

class _DiscoveryRailSkeleton extends StatelessWidget {
  final double titleWidth;
  final double subtitleWidth;

  const _DiscoveryRailSkeleton({
    required this.titleWidth,
    required this.subtitleWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Skeleton
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(
                  width: titleWidth,
                  height: 20,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 6),
                SkeletonBox(
                  width: subtitleWidth,
                  height: 12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
            SkeletonBox(
              width: 55,
              height: 14,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Horizontal Carousel of Album Card Skeletons
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) => const _AlbumCardSkeleton(),
          ),
        ),
      ],
    );
  }
}

class _AlbumCardSkeleton extends StatelessWidget {
  const _AlbumCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Square Artwork placeholder
          SkeletonBox(
            width: 140,
            height: 140,
            borderRadius: BorderRadius.circular(12),
          ),
          const SizedBox(height: 8),
          // Song Title placeholder
          SkeletonBox(
            width: 110,
            height: 13,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 4),
          // Artist / Subtitle placeholder
          SkeletonBox(
            width: 75,
            height: 11,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}

/// Explore Tab Skeleton Loader.
/// Displays Radio carousels matching `_buildExploreTab` layout.
class ExploreSkeleton extends StatelessWidget {
  final bool reduceAnimations;

  const ExploreSkeleton({
    super.key,
    this.reduceAnimations = false,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      isLoading: true,
      reduceAnimations: reduceAnimations,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _ExploreRadioSectionSkeleton(
            titleWidth: 150,
            hasLeadingIcon: false,
          ),
          SizedBox(height: 36),
          _ExploreRadioSectionSkeleton(
            titleWidth: 120,
            hasLeadingIcon: true,
          ),
          SizedBox(height: 36),
          _ExploreRadioSectionSkeleton(
            titleWidth: 130,
            hasLeadingIcon: true,
          ),
        ],
      ),
    );
  }
}

class _ExploreRadioSectionSkeleton extends StatelessWidget {
  final double titleWidth;
  final bool hasLeadingIcon;

  const _ExploreRadioSectionSkeleton({
    required this.titleWidth,
    required this.hasLeadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Skeleton
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (hasLeadingIcon) ...[
                  const SkeletonBox(
                    width: 32,
                    height: 32,
                    shape: BoxShape.circle,
                  ),
                  const SizedBox(width: 10),
                ],
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasLeadingIcon) ...[
                      SkeletonBox(
                        width: 50,
                        height: 11,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: 4),
                    ],
                    SkeletonBox(
                      width: titleWidth,
                      height: 20,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ],
                ),
              ],
            ),
            SkeletonBox(
              width: 55,
              height: 14,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Horizontal Carousel of Radio Card Skeletons
        SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) => const _RadioCardSkeleton(),
          ),
        ),
      ],
    );
  }
}

class _RadioCardSkeleton extends StatelessWidget {
  const _RadioCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 165,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardSurfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderOf(context), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Radio Artwork placeholder
          SkeletonBox(
            width: double.infinity,
            height: 140,
            borderRadius: BorderRadius.circular(12),
          ),
          const SizedBox(height: 12),
          // Radio Station Name placeholder
          SkeletonBox(
            width: 120,
            height: 15,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 6),
          // Artist names / tags placeholder
          SkeletonBox(
            width: 90,
            height: 11,
            borderRadius: BorderRadius.circular(3),
          ),
          const Spacer(),
          // Bottom tag / action placeholder
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonBox(
                width: 45,
                height: 16,
                borderRadius: BorderRadius.circular(8),
              ),
              const SkeletonBox(
                width: 28,
                height: 28,
                shape: BoxShape.circle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Library Tab Skeleton Grid.
/// Displays a responsive grid of playlist card skeletons under the header & filter chips.
class LibrarySkeletonGrid extends StatelessWidget {
  final bool reduceAnimations;
  final int itemCount;

  const LibrarySkeletonGrid({
    super.key,
    this.reduceAnimations = false,
    this.itemCount = 8,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      isLoading: true,
      reduceAnimations: reduceAnimations,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 16.0;
          const maxExtent = 210.0;
          var count = (constraints.maxWidth / (maxExtent + spacing)).ceil();
          if (count < 1) count = 1;
          final cardWidth =
              (constraints.maxWidth - spacing * (count - 1)) / count;

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: itemCount,
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: maxExtent,
              mainAxisExtent: cardWidth + 88,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
            ),
            itemBuilder: (context, index) => _PlaylistCardSkeleton(cardWidth: cardWidth),
          );
        },
      ),
    );
  }
}

/// Full Library Tab Skeleton (including Header, Filter Chips, and Grid).
class LibrarySkeleton extends StatelessWidget {
  final bool reduceAnimations;

  const LibrarySkeleton({
    super.key,
    this.reduceAnimations = false,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      isLoading: true,
      reduceAnimations: reduceAnimations,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Skeleton
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(
                    width: 140,
                    height: 24,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(height: 6),
                  SkeletonBox(
                    width: 80,
                    height: 12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
              Row(
                children: [
                  SkeletonBox(
                    width: 130,
                    height: 38,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  const SizedBox(width: 8),
                  SkeletonBox(
                    width: 120,
                    height: 38,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Filter Chips Skeleton
          Row(
            children: [
              SkeletonBox(
                width: 50,
                height: 32,
                borderRadius: BorderRadius.circular(20),
              ),
              const SizedBox(width: 8),
              SkeletonBox(
                width: 80,
                height: 32,
                borderRadius: BorderRadius.circular(20),
              ),
              const SizedBox(width: 8),
              SkeletonBox(
                width: 75,
                height: 32,
                borderRadius: BorderRadius.circular(20),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Grid of Playlist Card Skeletons
          const LibrarySkeletonGrid(),
        ],
      ),
    );
  }
}

class _PlaylistCardSkeleton extends StatelessWidget {
  final double cardWidth;

  const _PlaylistCardSkeleton({required this.cardWidth});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardSurfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderOf(context), width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SkeletonBox(
              width: double.infinity,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 10),
          SkeletonBox(
            width: cardWidth * 0.75,
            height: 14,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 6),
          SkeletonBox(
            width: cardWidth * 0.45,
            height: 11,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}
