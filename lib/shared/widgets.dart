import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/aggregation.dart';
import '../data/match_models.dart';
import '../features/clubs.dart';
import '../l10n/strings.dart';

class Headline extends StatelessWidget {
  final String text;
  final double size;
  final Color? color;
  const Headline(this.text, {super.key, this.size = 44, this.color});
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontFamily: 'BarlowCondensed',
      fontWeight: FontWeight.w700,
      fontSize: size,
      height: .98,
      letterSpacing: -.5,
      color: color ?? JuriTheme.ink,
    ),
  );
}

class Eyebrow extends StatelessWidget {
  final String text;
  final Color color;
  const Eyebrow(this.text, {super.key, this.color = JuriTheme.muted});
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.8,
      color: color,
    ),
  );
}

class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const Pressable({super.key, required this.child, this.onTap});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) => Semantics(
    button: widget.onTap != null,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => pressed = true),
      onTapUp: (_) => setState(() => pressed = false),
      onTapCancel: () => setState(() => pressed = false),
      child: AnimatedScale(
        scale: pressed ? 0.975 : 1,
        duration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 160,
        ),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    ),
  );
}

class ClubBadge extends StatelessWidget {
  final Club club;
  final double size;

  /// A badge is a link to its club everywhere it appears. Turn this off only
  /// where tapping already means something else — picking a club in
  /// onboarding or a dropdown, or a badge sitting on that club's own page.
  final bool linked;
  const ClubBadge(this.club, {super.key, this.size = 36, this.linked = true});

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      club.badge,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, e, s) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: JuriTheme.elevated,
        ),
        child: Text(
          club.shortName,
          style: TextStyle(fontSize: size / 4, fontWeight: FontWeight.bold),
        ),
      ),
      semanticLabel: club.name,
    );
    if (!linked || club.isUnknown) return image;
    return Semantics(
      button: true,
      label: club.name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => openClub(context, club),
        child: image,
      ),
    );
  }
}

class Portrait extends StatelessWidget {
  final Player player;
  final BoxFit fit;
  final double? width, height;
  const Portrait(
    this.player, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });
  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            JuriTheme.clubColor(player.clubId).withValues(alpha: .18),
            JuriTheme.surface,
          ],
        ),
      ),
      child: Headline(
        player.initials,
        size: 48,
        color: JuriTheme.clubColor(player.clubId),
      ),
    );
    if (player.photo == null) return fallback();
    return Image.asset(
      player.photo!,
      width: width,
      height: height,
      fit: fit,
      alignment: Alignment.topCenter,
      cacheWidth: 700,
      errorBuilder: (_, e, s) => fallback(),
      semanticLabel: player.name,
    );
  }
}

class ScoreChip extends StatelessWidget {
  final double score;
  final bool large;
  const ScoreChip(this.score, {super.key, this.large = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: large ? 13 : 9,
      vertical: large ? 9 : 5,
    ),
    decoration: BoxDecoration(
      color: JuriTheme.gold,
      borderRadius: BorderRadius.circular(large ? 12 : 7),
    ),
    child: Text(
      formatScore(score),
      style: TextStyle(
        color: JuriTheme.background,
        fontWeight: FontWeight.w800,
        fontSize: large ? 24 : 14,
      ),
    ),
  );
}

class SeasonRecordRow extends StatelessWidget {
  final PlayerSeasonStats record;
  const SeasonRecordRow({super.key, required this.record});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      _stat(record.matches, Tr.t('seasonMatches')),
      _divider(),
      _stat(record.goals, Tr.t('seasonGoals')),
      _divider(),
      _stat(record.assists, Tr.t('seasonAssists')),
    ],
  );

  Widget _stat(int value, String label) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Headline('$value', size: 36, color: JuriTheme.gold),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w800,
            color: JuriTheme.muted,
          ),
        ),
      ],
    ),
  );

  Widget _divider() => Container(
    width: 1,
    height: 42,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: JuriTheme.line,
  );
}

class SectionHeading extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  const SectionHeading(this.title, {super.key, this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 16),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -.6,
            ),
          ),
        ),
        if (onTap != null)
          TextButton(
            onPressed: onTap,
            child: Text(Tr.t('seeAll'), style: const TextStyle(fontSize: 11)),
          ),
      ],
    ),
  );
}

class DemoLabel extends StatelessWidget {
  final String? label;
  const DemoLabel({super.key, this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      border: Border.all(color: JuriTheme.line),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label ?? Tr.t('demo'),
      style: const TextStyle(
        fontSize: 10,
        color: JuriTheme.muted,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: JuriTheme.elevated,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      Tr.t('demoBanner'),
      style: const TextStyle(fontSize: 11, height: 1.45, color: JuriTheme.muted),
    ),
  );
}

class PlayerRow extends StatelessWidget {
  final Player player;
  final Club club;
  final VoidCallback onTap;
  final int? rank;
  final double? score;
  final String? subtitle;

  /// Opt-in shared-element transition. A hero tag must be unique inside a
  /// route, and lists such as the review history can legitimately show the
  /// same player twice, so callers decide rather than the row.
  final bool hero;
  const PlayerRow({
    super.key,
    required this.player,
    required this.club,
    required this.onTap,
    this.rank,
    this.score,
    this.subtitle,
    this.hero = false,
  });
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          if (rank != null)
            SizedBox(
              width: 30,
              child: Text(
                rank!.toString().padLeft(2, '0'),
                style: const TextStyle(fontSize: 12, color: JuriTheme.muted),
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: hero
                ? Hero(
                    tag: 'player-${player.id}',
                    child: Portrait(player, width: 52, height: 60),
                  )
                : Portrait(player, width: 52, height: 60),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle ?? '${club.name} · ${player.position ?? '—'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: JuriTheme.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (score != null)
            ScoreChip(score!)
          else
            Text(
              formatValue(player.marketValue),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
        ],
      ),
    ),
  );
}

/// Up and down with both counts beside them.
///
/// Both directions are public: a supporter can see how hard the ground pushed
/// back on a take, not just how many agreed. The second tap on the direction
/// you already chose clears the vote, which is what every such control does.
class VoteBar extends StatelessWidget {
  final int likeCount, dislikeCount, myVote;
  final Future<void> Function(int direction) onVote;
  final bool compact;
  const VoteBar({
    super.key,
    required this.likeCount,
    required this.dislikeCount,
    required this.myVote,
    required this.onVote,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _button(
        icon: myVote == 1
            ? Icons.arrow_upward
            : Icons.arrow_upward_outlined,
        count: likeCount,
        active: myVote == 1,
        activeColor: JuriTheme.gold,
        direction: 1,
      ),
      SizedBox(width: compact ? 2 : 6),
      _button(
        icon: myVote == -1
            ? Icons.arrow_downward
            : Icons.arrow_downward_outlined,
        count: dislikeCount,
        active: myVote == -1,
        activeColor: const Color(0xFFD08C7A),
        direction: -1,
      ),
    ],
  );

  Widget _button({
    required IconData icon,
    required int count,
    required bool active,
    required Color activeColor,
    required int direction,
  }) => TextButton.icon(
    key: Key(direction == 1 ? 'voteUp' : 'voteDown'),
    onPressed: () => onVote(direction),
    style: TextButton.styleFrom(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    icon: Icon(
      icon,
      size: 15,
      color: active ? activeColor : JuriTheme.muted,
    ),
    label: Text(
      count == 0 ? '' : '$count',
      style: TextStyle(
        fontSize: 11,
        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
        color: active ? activeColor : JuriTheme.muted,
      ),
    ),
  );
}

class EmptyView extends StatelessWidget {
  final String title, body;
  final Widget? action;
  const EmptyView({
    super.key,
    required this.title,
    required this.body,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.sports_soccer_outlined,
          size: 38,
          color: JuriTheme.gold,
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(color: JuriTheme.muted, height: 1.6),
        ),
        if (action != null) ...[const SizedBox(height: 24), action!],
      ],
    ),
  );
}

class PitchLines extends CustomPainter {
  final Color color;
  PitchLines({this.color = const Color(0xFF41483A)});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rect = Rect.fromLTWH(
      size.width * .12,
      size.height * .1,
      size.width * .78,
      size.height * .85,
    );
    canvas.drawRect(rect, p);
    canvas.drawLine(
      Offset(rect.left, rect.center.dy),
      Offset(rect.right, rect.center.dy),
      p,
    );
    canvas.drawCircle(rect.center, size.width * .17, p);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * .3,
        rect.top,
        size.width * .42,
        size.height * .16,
      ),
      p,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * .3,
        rect.bottom - size.height * .16,
        size.width * .42,
        size.height * .16,
      ),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant PitchLines oldDelegate) =>
      oldDelegate.color != color;
}

Future<T?> openPage<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(
      Theme.of(context).platform == TargetPlatform.iOS &&
              !MediaQuery.disableAnimationsOf(context)
          ? CupertinoPageRoute<T>(builder: (_) => page)
          : PageRouteBuilder<T>(
              pageBuilder: (_, a, b) => page,
              transitionDuration: Duration(
                milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 330,
              ),
              transitionsBuilder: (_, a, b, child) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(begin: const Offset(.04, 0), end: Offset.zero)
                      .animate(
                        CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
                      ),
                  child: child,
                ),
              ),
            ),
    );
void showSaveError(BuildContext context) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(Tr.t('saveError'))));

/// One line describing what the source actually knows about an appearance.
/// Kept in one place because four screens render it and they used to drift.
///
/// Set [includeRole] to false where the surrounding section already names the
/// role — a team sheet under an "İlk 11" heading should not repeat it on
/// every row.
String appearanceStatus(PlayerAppearance appearance, {bool includeRole = true}) {
  final parts = <String>[
    if (appearance.positionNote != null) appearance.positionNote!,
  ];
  if (appearance.unused) {
    parts.add(Tr.t('unusedSub'));
  } else if (appearance.participationUnknown) {
    parts.add(includeRole ? Tr.t('benchUnconfirmed') : Tr.t('entryUnconfirmed'));
  } else if (appearance.minutesKnown) {
    parts.add('${appearance.minutes}′');
    if (appearance.isShort) parts.add(Tr.t('shortAppearance'));
  } else if (!includeRole) {
    parts.add(Tr.t('minutesUnknown'));
  } else if (appearance.role == AppearanceRole.starter) {
    parts.add(Tr.t('starterPresumed'));
  } else {
    parts.add('${Tr.t('substitute')} · ${Tr.t('minutesUnknown')}');
  }
  return parts.join(' · ');
}

String populationCaption(PopulationScore score) {
  if (score.empty) return Tr.t('unrated');
  if (score.withheld) return evaluationCount(score.count);
  final base = '${score.displayAverage} · ${evaluationCount(score.count)}';
  return score.lowSample ? '$base · ${Tr.t('lowSample')}' : base;
}

/// Five 2-point bands under an average. The product is about disagreement,
/// and a mean of 5,5 reads the same whether everyone said 5,5 or half the
/// ground said 2 and the other half said 9.
class RatingDistribution extends StatelessWidget {
  final PopulationScore score;
  final Color accent;
  const RatingDistribution({
    super.key,
    required this.score,
    this.accent = JuriTheme.gold,
  });

  static const _bands = ['1-2', '3-4', '5-6', '7-8', '9-10'];

  @override
  Widget build(BuildContext context) {
    if (!score.published) return const SizedBox.shrink();
    final peak = score.distribution.fold<int>(0, (a, b) => a > b ? a : b);
    if (peak == 0) return const SizedBox.shrink();
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Tr.t('distribution'),
          style: const TextStyle(fontSize: 10, color: JuriTheme.muted),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < score.distribution.length; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: i == score.distribution.length - 1 ? 0 : 5,
                  ),
                  child: Semantics(
                    label: '${_bands[i]}: ${score.distribution[i]}',
                    child: Column(
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: 0,
                            end: score.distribution[i] / peak,
                          ),
                          duration: Duration(milliseconds: reduce ? 0 : 480),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) => Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: 6 + 30 * value,
                              decoration: BoxDecoration(
                                color: score.distribution[i] == 0
                                    ? JuriTheme.line
                                    : accent.withValues(
                                        alpha: .35 + .5 * value,
                                      ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _bands[i],
                          style: const TextStyle(
                            fontSize: 10,
                            color: JuriTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (score.divided) ...[
          const SizedBox(height: 8),
          Text(
            '${Tr.t('divided')} · ${Tr.t('dividedBody')}',
            style: const TextStyle(fontSize: 10, color: JuriTheme.gold),
          ),
        ],
      ],
    );
  }
}

class DualScoreCard extends StatelessWidget {
  final PopulationScore genel;
  final PopulationScore club;
  final String clubName;
  final bool revealed;
  final bool demo;
  final Color accent;
  const DualScoreCard({
    super.key,
    required this.genel,
    required this.club,
    required this.clubName,
    this.revealed = true,
    this.demo = false,
    this.accent = JuriTheme.gold,
  });
  @override
  Widget build(BuildContext context) {
    if (!revealed) {
      return Text(
        Tr.t('revealResults'),
        style: const TextStyle(color: JuriTheme.muted, fontSize: 12),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Eyebrow(
                demo ? Tr.t('demoCommunity') : Tr.t('community'),
                color: JuriTheme.gold,
              ),
            ),
            if (demo) const DemoLabel(),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _scoreBlock(Tr.t('genelSkor'), genel)),
            const SizedBox(width: 16),
            Expanded(child: _scoreBlock(clubScoreLabel(clubName), club)),
          ],
        ),
        if (genel.published) ...[
          const SizedBox(height: 18),
          RatingDistribution(score: genel, accent: accent),
        ],
        if (genel.published && !club.published) ...[
          const SizedBox(height: 10),
          Text(
            Tr.t('insufficientClub'),
            style: const TextStyle(fontSize: 11, color: JuriTheme.muted),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          Tr.t('selfDeclared'),
          style: const TextStyle(fontSize: 10, color: JuriTheme.muted),
        ),
      ],
    );
  }

  Widget _scoreBlock(String title, PopulationScore score) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, color: JuriTheme.muted),
      ),
      const SizedBox(height: 6),
      Headline(
        score.published ? score.displayAverage : Tr.t('emptyScore'),
        size: 42,
      ),
      const SizedBox(height: 6),
      Text(
        populationCaption(score),
        style: const TextStyle(
          fontSize: 11,
          color: JuriTheme.muted,
          height: 1.4,
        ),
      ),
    ],
  );
}

class MatchScoreline extends StatelessWidget {
  final Match match;
  final Club home, away;
  const MatchScoreline({
    super.key,
    required this.match,
    required this.home,
    required this.away,
  });
  @override
  Widget build(BuildContext context) => Row(
    children: [
      ClubBadge(home, size: 28),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          home.shortName.isEmpty ? home.name : home.shortName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
      Text(
        match.result,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
      ),
      Expanded(
        child: Text(
          away.shortName.isEmpty ? away.name : away.shortName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
      const SizedBox(width: 8),
      ClubBadge(away, size: 28),
    ],
  );
}
