import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/aggregation.dart';
import '../data/attributes.dart';
import '../data/models.dart';
import '../l10n/strings.dart';
import 'widgets.dart';

class AttributeInsight {
  final AttributeDef attribute;
  final PopulationScore community;
  final PopulationScore? club;
  final double? personal;
  const AttributeInsight({
    required this.attribute,
    required this.community,
    this.club,
    this.personal,
  });

  bool get published => community.published;
  double get fill =>
      published && community.mean != null ? (community.mean! / 10).clamp(0, 1) : 0;

  /// The reader's own score on the same 0–1 scale, or null where they never
  /// rated this attribute. Kept separate from [fill] so the radar can plot
  /// both without either standing in for the other.
  double? get personalFill =>
      personal == null ? null : (personal! / 10).clamp(0, 1).toDouble();
}

class AttributeAnalysisBoard extends StatelessWidget {
  final List<AttributeInsight> insights;
  final Color accent;
  const AttributeAnalysisBoard({
    super.key,
    required this.insights,
    this.accent = JuriTheme.gold,
  });

  @override
  Widget build(BuildContext context) {
    final published = insights.where((i) => i.published).toList();
    final reduce = MediaQuery.disableAnimationsOf(context);
    // The crowd shape when there is a crowd, the reader's own otherwise. The
    // discovery board already falls back this way; an analysis screen that
    // stayed blank while holding the reader's own scores was the odd one out.
    final hasCommunity = insights.any((i) => i.published && i.fill > 0);
    final hasPersonal = insights.any((i) => (i.personalFill ?? 0) > 0);
    final personalPrimary = !hasCommunity;
    return Container(
      key: const Key('attributeAnalysis'),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: JuriTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: JuriTheme.line.withValues(alpha: .65)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 256,
            width: double.infinity,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: reduce ? 0 : 720),
              curve: Curves.easeOutCubic,
              builder: (context, t, _) => CustomPaint(
                painter: _RadarPainter(
                  values: [
                    for (final i in insights) i.published ? i.fill : null,
                  ],
                  personalValues: [for (final i in insights) i.personalFill],
                  personalPrimary: personalPrimary,
                  labels: [for (final i in insights) _radarLabel(i.attribute)],
                  accent: accent,
                  progress: t,
                ),
              ),
            ),
          ),
          if (hasCommunity || hasPersonal) ...[
            const SizedBox(height: 4),
            _RadarLegend(
              community: hasCommunity,
              personal: hasPersonal,
              personalPrimary: personalPrimary,
              accent: accent,
            ),
          ],
          if (published.isEmpty) ...[
            const SizedBox(height: 6),
            Text(
              Tr.t('seasonForming'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: JuriTheme.muted),
            ),
          ],
          const SizedBox(height: 16),
          for (var i = 0; i < insights.length; i += 2)
            Padding(
              padding: EdgeInsets.only(bottom: i + 2 < insights.length ? 10 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _AttributeTile(
                      insight: insights[i],
                      accent: accent,
                      delay: i,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: i + 1 < insights.length
                        ? _AttributeTile(
                            insight: insights[i + 1],
                            accent: accent,
                            delay: i + 1,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AttributeTile extends StatelessWidget {
  final AttributeInsight insight;
  final Color accent;
  final int delay;
  const _AttributeTile({
    required this.insight,
    required this.accent,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final published = insight.published;
    final club = insight.club;
    final score = published
        ? insight.community.displayAverage
        : Tr.t('emptyScore');
    final meta = [
      if (insight.personal != null)
        '${Tr.t('yourRating')} ${formatScore(insight.personal!)}',
      if (club?.published == true)
        '${Tr.t('kulupSkoru')} ${club!.displayAverage}',
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
      decoration: BoxDecoration(
        color: JuriTheme.elevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: published
              ? accent.withValues(alpha: .18)
              : JuriTheme.line.withValues(alpha: .7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Glyph(attribute: insight.attribute, accent: accent),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  alignment: Alignment.centerRight,
                  fit: BoxFit.scaleDown,
                  child: Headline(
                    score,
                    size: 26,
                    color: published ? accent : JuriTheme.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            insight.attribute.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              height: 1.2,
              letterSpacing: -.2,
            ),
          ),
          const SizedBox(height: 10),
          _Bar(
            fill: insight.fill,
            color: accent,
            duration: Duration(milliseconds: reduce ? 0 : 560 + delay * 40),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              meta.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: JuriTheme.muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Names the shapes on the radar. Without it a lone dashed outline is hard to
/// tell from the empty-state placeholder, which is also dashed.
class _RadarLegend extends StatelessWidget {
  final bool community, personal, personalPrimary;
  final Color accent;
  const _RadarLegend({
    required this.community,
    required this.personal,
    required this.personalPrimary,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      if (community) _entry(accent, dashed: false, label: Tr.t('community')),
      if (community && personal) const SizedBox(width: 16),
      if (personal)
        _entry(
          personalPrimary ? accent : _personalInk,
          dashed: !personalPrimary,
          label: Tr.t('radarPersonal'),
        ),
    ],
  );

  Widget _entry(Color color, {required bool dashed, required String label}) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _swatch(color, dashed),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: .4,
              color: JuriTheme.muted,
            ),
          ),
        ],
      );

  Widget _swatch(Color color, bool dashed) => dashed
      ? Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 2.5),
              _line(color, 3),
            ],
          ],
        )
      : _line(color, 14);

  Widget _line(Color color, double width) => Container(
    width: width,
    height: 2,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(1),
    ),
  );
}

class _Glyph extends StatelessWidget {
  final AttributeDef attribute;
  final Color accent;
  const _Glyph({required this.attribute, required this.accent});

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    decoration: BoxDecoration(
      color: accent.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(_iconFor(attribute.key), size: 14, color: accent),
  );
}

class _Bar extends StatelessWidget {
  final double fill;
  final Color color;
  final Duration duration;
  const _Bar({
    required this.fill,
    required this.color,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: fill),
    duration: duration,
    curve: Curves.easeOutCubic,
    builder: (context, value, _) => ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: JuriTheme.line),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: value.clamp(0, 1),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: .5), color],
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Colour of the reader's own series when it sits alongside a community one.
/// Solid-versus-dashed carries the distinction on its own, so this only has to
/// stay legible against any club accent.
const _personalInk = JuriTheme.ink;

class _RadarPainter extends CustomPainter {
  final List<double?> values;
  final List<double?> personalValues;
  final bool personalPrimary;
  final List<String> labels;
  final Color accent;
  final double progress;
  const _RadarPainter({
    required this.values,
    required this.personalValues,
    required this.personalPrimary,
    required this.labels,
    required this.accent,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n < 3) return;
    final center = Offset(size.width / 2, size.height / 2 + 4);
    final radius = math.min(size.width, size.height) / 2 - 30;
    final grid = Paint()
      ..color = JuriTheme.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final axis = Paint()
      ..color = JuriTheme.line.withValues(alpha: .85)
      ..strokeWidth = 1;

    for (var ring = 1; ring <= 4; ring++) {
      canvas.drawPath(_polygon(center, radius * ring / 4, n), grid);
    }
    for (var i = 0; i < n; i++) {
      canvas.drawLine(center, _point(center, radius, i, n), axis);
    }

    final hasCommunity = values.any((v) => v != null && v > 0);
    final hasPersonal = personalValues.any((v) => v != null && v > 0);

    if (hasCommunity) {
      _series(canvas, center, radius, n, values, accent, primary: true);
      // Both on screen: the crowd stays the solid shape and the reader's own
      // scores ride over it as a dashed outline.
      if (hasPersonal) {
        _series(
          canvas,
          center,
          radius,
          n,
          personalValues,
          _personalInk,
          primary: false,
        );
      }
    } else if (hasPersonal) {
      // No crowd yet, so the reader's own shape is the analysis, not a
      // footnote — drawn exactly as the community series would have been.
      _series(canvas, center, radius, n, personalValues, accent, primary: true);
    } else {
      final ghost = _polygon(center, radius * .48, n);
      canvas.drawPath(
        ghost,
        Paint()..color = accent.withValues(alpha: .07),
      );
      _dash(
        canvas,
        ghost,
        Paint()
          ..color = accent.withValues(alpha: .7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
      canvas.drawCircle(center, 3.2, Paint()..color = accent);
    }

    for (var i = 0; i < n; i++) {
      _label(canvas, center, radius, i, n, labels[i]);
    }
  }

  /// One plotted shape. [primary] is the filled, solid-stroked treatment used
  /// for whichever series leads; the secondary one is a dashed outline so the
  /// two never read as a single polygon.
  void _series(
    Canvas canvas,
    Offset center,
    double radius,
    int n,
    List<double?> source,
    Color color, {
    required bool primary,
  }) {
    final ready = [
      for (var i = 0; i < n; i++) (source[i] ?? 0) * progress,
    ];
    final path = _valuePath(center, radius, ready, n);
    if (primary) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: .16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: .28));
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round,
      );
    } else {
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: .07));
      _dash(
        canvas,
        path,
        Paint()
          ..color = color.withValues(alpha: .9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
    for (var i = 0; i < n; i++) {
      if (source[i] == null) continue;
      canvas.drawCircle(
        _point(center, radius * ready[i], i, n),
        primary ? 2.4 : 2,
        Paint()..color = color,
      );
    }
  }

  void _label(
    Canvas canvas,
    Offset center,
    double radius,
    int i,
    int n,
    String text,
  ) {
    final angle = _angle(i, n);
    final pos = _point(center, radius + 16, i, n);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: .4,
          color: JuriTheme.muted,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = math.cos(angle);
    tp.paint(
      canvas,
      pos - Offset(tp.width / 2, tp.height / 2) + Offset(dx * 2, 0),
    );
  }

  Path _valuePath(Offset center, double radius, List<double> fills, int n) {
    final path = Path();
    for (var i = 0; i < n; i++) {
      final p = _point(center, radius * fills[i], i, n);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    return path;
  }

  Path _polygon(Offset center, double radius, int n) {
    final path = Path();
    for (var i = 0; i < n; i++) {
      final p = _point(center, radius, i, n);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    return path;
  }

  void _dash(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 4, metric.length)), paint);
        d += 9;
      }
    }
  }

  double _angle(int i, int n) => -math.pi / 2 + (i * 2 * math.pi / n);

  Offset _point(Offset center, double radius, int i, int n) {
    final a = _angle(i, n);
    return Offset(
      center.dx + radius * math.cos(a),
      center.dy + radius * math.sin(a),
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.progress != progress ||
      old.accent != accent ||
      old.personalPrimary != personalPrimary ||
      !listEquals(old.values, values) ||
      !listEquals(old.personalValues, personalValues) ||
      !listEquals(old.labels, labels);
}

String _radarLabel(AttributeDef attribute) {
  final first = attribute.label.split(' ').first;
  return first.length > 6 ? '${first.substring(0, 5).toUpperCase()}.' : first.toUpperCase();
}

IconData _iconFor(String key) => switch (key) {
  'teknik' => Icons.sports_soccer,
  'pas' => Icons.sync_alt,
  'hucum_katkisi' => Icons.north_east,
  'savunma_katkisi' => Icons.shield_outlined,
  'topsuz_oyun' => Icons.directions_run,
  'ikili_mucadele' => Icons.sports,
  'karar_verme' => Icons.psychology_outlined,
  'efor' => Icons.local_fire_department_outlined,
  'sogukkanlilik' => Icons.ac_unit,
  'takim_oyunu' => Icons.groups_outlined,
  'sut_kurtarma' => Icons.front_hand_outlined,
  'hava_toplari' => Icons.keyboard_double_arrow_up,
  'bire_bir' => Icons.person_outline,
  'alan_kontrolu' => Icons.radar_outlined,
  _ => Icons.circle_outlined,
};
