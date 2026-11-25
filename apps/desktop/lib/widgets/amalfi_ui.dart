import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:amalfi_brand_assets/amalfi_brand_assets.dart';

import '../theme/amalfi_theme.dart';

class ScreenHeading extends StatelessWidget {
  const ScreenHeading({
    required this.title,
    required this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final titleContent = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AmalfiTheme.brandFor(context),
                  AmalfiTheme.deepBrandFor(context),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: AmalfiTheme.brandFor(context).withValues(alpha: .22),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const AmalfiIcon(
              name: AmalfiIconName.coffee,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AmalfiTheme.mutedText(context, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      );
      if (constraints.maxWidth < 760 && trailing != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            titleContent,
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: trailing),
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: titleContent),
          ?trailing,
        ],
      );
    },
  );
}

class AmalfiPageBackground extends StatelessWidget {
  const AmalfiPageBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: Image.asset(
            AmalfiBrandAssets.coffeeSceneBackground,
            key: const ValueKey('coffee-scene-background'),
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                theme.scaffoldBackgroundColor.withValues(alpha: .58),
                theme.scaffoldBackgroundColor.withValues(alpha: .78),
              ],
              stops: const [.42, 1],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class AmalfiBrandFooter extends StatelessWidget {
  const AmalfiBrandFooter({required this.height, super.key});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(
      painter: _AmalfiFooterPainter(
        pageColor: AmalfiTheme.pageFor(context),
        deepColor: AmalfiTheme.deepBrandFor(context),
        brandColor: AmalfiTheme.brandFor(context),
        accentColor: AmalfiTheme.errorFor(context),
      ),
    ),
  );
}

class _AmalfiFooterPainter extends CustomPainter {
  const _AmalfiFooterPainter({
    required this.pageColor,
    required this.deepColor,
    required this.brandColor,
    required this.accentColor,
  });

  final Color pageColor;
  final Color deepColor;
  final Color brandColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            pageColor.withValues(alpha: .12),
            pageColor.withValues(alpha: .02),
          ],
        ).createShader(bounds),
    );

    final backWave = Path()
      ..moveTo(0, size.height * .37)
      ..cubicTo(
        size.width * .21,
        size.height * .30,
        size.width * .36,
        size.height * .69,
        size.width * .57,
        size.height * .55,
      )
      ..cubicTo(
        size.width * .79,
        size.height * .69,
        size.width * .91,
        size.height * .50,
        size.width,
        size.height * .47,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      backWave,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            deepColor.withValues(alpha: .30),
            brandColor.withValues(alpha: .22),
          ],
        ).createShader(bounds),
    );

    final middleWave = Path()
      ..moveTo(0, size.height * .59)
      ..cubicTo(
        size.width * .19,
        size.height * .48,
        size.width * .32,
        size.height * .85,
        size.width * .54,
        size.height * .72,
      )
      ..cubicTo(
        size.width * .75,
        size.height * .59,
        size.width * .89,
        size.height * .67,
        size.width,
        size.height * .40,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      middleWave,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            brandColor.withValues(alpha: .35),
            deepColor.withValues(alpha: .32),
          ],
        ).createShader(bounds),
    );

    final frontWave = Path()
      ..moveTo(0, size.height * .81)
      ..cubicTo(
        size.width * .18,
        size.height * .72,
        size.width * .35,
        size.height * .96,
        size.width * .59,
        size.height * .86,
      )
      ..cubicTo(
        size.width * .79,
        size.height * .72,
        size.width * .92,
        size.height * .82,
        size.width,
        size.height * .88,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      frontWave,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            deepColor.withValues(alpha: .44),
            brandColor.withValues(alpha: .36),
          ],
        ).createShader(bounds),
    );

    final accentWave = Path()
      ..moveTo(0, size.height * .585)
      ..cubicTo(
        size.width * .19,
        size.height * .475,
        size.width * .32,
        size.height * .845,
        size.width * .54,
        size.height * .715,
      )
      ..cubicTo(
        size.width * .75,
        size.height * .585,
        size.width * .89,
        size.height * .655,
        size.width,
        size.height * .685,
      );
    canvas.drawPath(
      accentWave,
      Paint()
        ..color = accentColor.withValues(alpha: .9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(_AmalfiFooterPainter oldDelegate) =>
      oldDelegate.pageColor != pageColor ||
      oldDelegate.deepColor != deepColor ||
      oldDelegate.brandColor != brandColor ||
      oldDelegate.accentColor != accentColor;
}

class AmalfiPanel extends StatelessWidget {
  const AmalfiPanel({
    required this.title,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.all(12),
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AmalfiTheme.panelFor(context),
        border: Border.all(color: AmalfiTheme.outlineFor(context)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(
              alpha: theme.brightness == Brightness.dark ? .12 : .07,
            ),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 17,
                    decoration: BoxDecoration(
                      color: AmalfiTheme.brandFor(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(padding: padding, child: child),
          ),
        ],
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
    super.key,
  });

  final String label;
  final String value;
  final AmalfiIconName icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AmalfiTheme.panelFor(context),
        border: Border.all(color: AmalfiTheme.outlineFor(context)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(
              alpha: theme.brightness == Brightness.dark ? .12 : .07,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AmalfiTheme.mutedFor(context),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: valueColor ?? theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AmalfiTheme.brandFor(context).withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: AmalfiIcon(
              name: icon,
              size: 20,
              color: valueColor ?? AmalfiTheme.brandFor(context),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.label, required this.color, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
    ),
  );
}
