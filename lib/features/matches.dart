import 'package:flutter/material.dart';
import '../app/scope.dart';
import '../core/theme.dart';
import '../data/match_models.dart';
import '../data/models.dart';
import '../l10n/strings.dart';
import '../shared/widgets.dart';
import 'performance.dart';

void openMatch(BuildContext context, Match match) =>
    openPage(context, MatchScreen(match: match));

void openFixtures(BuildContext context) =>
    openPage(context, const FixturesScreen());

/// One fixture line, shared by the home feed and the full fixture list.
class FixtureRow extends StatelessWidget {
  final Match match;
  const FixtureRow({super.key, required this.match});
  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    final home = repo.club(match.homeClubId);
    final away = repo.club(match.awayClubId);
    final status = switch (match.status) {
      MatchStatus.upcoming => Tr.t('upcoming'),
      MatchStatus.postponed => Tr.t('postponed'),
      MatchStatus.finished => Tr.t('finished'),
    };
    return Pressable(
      onTap: () => openMatch(context, match),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  formatMatchDate(match.kickoff),
                  style: const TextStyle(fontSize: 11, color: JuriTheme.muted),
                ),
                const Spacer(),
                Text(
                  status,
                  style: const TextStyle(fontSize: 11, color: JuriTheme.gold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            MatchScoreline(match: match, home: home, away: away),
          ],
        ),
      ),
    );
  }
}

class FixturesScreen extends StatelessWidget {
  const FixturesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    final fixtures = [...repo.matches]
      ..sort((a, b) => b.kickoff.compareTo(a.kickoff));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          Tr.t('fixtures'),
          style: const TextStyle(fontSize: 14),
        ),
      ),
      body: fixtures.isEmpty
          ? EmptyView(title: Tr.t('noResults'), body: Tr.t('noResultsBody'))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
              itemCount: fixtures.length,
              itemBuilder: (context, i) => FixtureRow(match: fixtures[i]),
            ),
    );
  }
}

/// Position lines, in the order a team sheet is normally read.
const _lines = <String?>['GK', 'DF', 'MF', 'FW', null];

class MatchScreen extends StatefulWidget {
  final Match match;
  const MatchScreen({super.key, required this.match});
  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  String? teamId;

  Match get match => widget.match;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final repo = scope.repository;
    final home = repo.club(match.homeClubId);
    final away = repo.club(match.awayClubId);
    // Open on the reader's own club when it is playing; otherwise the hosts.
    final selected =
        teamId ??
        (scope.user.clubId == match.awayClubId
            ? match.awayClubId
            : match.homeClubId);
    final squad = repo
        .appearancesForMatch(match.id)
        .where((a) => a.clubId == selected)
        .toList();
    final starters = squad
        .where((a) => a.role == AppearanceRole.starter)
        .toList();
    final onPitch = squad
        .where((a) => a.role != AppearanceRole.starter && a.played)
        .toList();
    final benched = squad.where((a) => !a.played).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${home.shortName} – ${away.shortName}',
          style: const TextStyle(fontSize: 14),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
        children: [
          if (match.isDemo) ...[
            const DemoBanner(),
            const SizedBox(height: 16),
          ],
          _Scoreboard(match: match, home: home, away: away),
          if (match.events.isNotEmpty) ...[
            SectionHeading(Tr.t('matchEvents')),
            Text(
              Tr.t('eventsNote'),
              style: const TextStyle(color: JuriTheme.muted, fontSize: 11),
            ),
            const SizedBox(height: 16),
            for (final e in match.events)
              if (e.type != 'assist')
                _EventLine(event: e, match: match, home: home),
          ],
          SectionHeading(Tr.t('lineup')),
          _TeamSwitch(
            home: home,
            away: away,
            selected: selected,
            onSelect: (id) => setState(() => teamId = id),
          ),
          const SizedBox(height: 20),
          if (squad.isEmpty)
            Text(
              Tr.t('noLineup'),
              style: const TextStyle(color: JuriTheme.muted, fontSize: 12),
            ),
          if (starters.isNotEmpty)
            _Group(
              title: Tr.t('startingXI'),
              count: starters.length,
              accent: JuriTheme.clubColor(selected),
              children: [
                for (final line in _lines)
                  ..._lineBlock(context, starters, line),
              ],
            ),
          if (onPitch.isNotEmpty)
            _Group(
              title: Tr.t('cameOn'),
              count: onPitch.length,
              accent: JuriTheme.clubColor(selected),
              children: [
                for (final a in onPitch) _row(context, a),
              ],
            ),
          if (benched.isNotEmpty)
            _Group(
              title: Tr.t('benchList'),
              count: benched.length,
              accent: JuriTheme.line,
              // Where the source lists substitutions, the bench is simply
              // whoever never came on. The softer "not confirmed" wording is
              // kept for feeds that publish a bench without the swaps.
              note: benched.any((a) => a.participationUnknown)
                  ? Tr.t('participationUnknownBody')
                  : Tr.t('benchListBody'),
              children: [
                for (final a in benched) _row(context, a),
              ],
            ),
          if (repo.matchMeta.hasGaps) ...[
            const SizedBox(height: 24),
            Text(
              Tr.t('sourceGapBody'),
              style: const TextStyle(color: JuriTheme.muted, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  /// One position line of a starting XI, skipped entirely when empty.
  List<Widget> _lineBlock(
    BuildContext context,
    List<PlayerAppearance> starters,
    String? line,
  ) {
    final repo = AppScope.of(context).repository;
    final members =
        starters.where((a) {
          final group = repo.player(a.playerId)?.positionGroup;
          return line == null ? !_lines.contains(group) : group == line;
        }).toList()..sort(
          (a, b) => (repo.player(a.playerId)?.name ?? '').compareTo(
            repo.player(b.playerId)?.name ?? '',
          ),
        );
    if (members.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 2),
        child: Eyebrow(Tr.group(line).toUpperCase()),
      ),
      for (final a in members) _row(context, a),
    ];
  }

  Widget _row(BuildContext context, PlayerAppearance appearance) =>
      LineupRow(key: Key('appearance-${appearance.id}'), appearance: appearance);
}

/// Club-tinted header: both badges, the score, and who was at home.
class _Scoreboard extends StatelessWidget {
  final Match match;
  final Club home, away;
  const _Scoreboard({
    required this.match,
    required this.home,
    required this.away,
  });

  @override
  Widget build(BuildContext context) {
    final status = switch (match.status) {
      MatchStatus.upcoming => Tr.t('upcoming'),
      MatchStatus.postponed => Tr.t('postponed'),
      MatchStatus.finished => Tr.t('finished'),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            JuriTheme.clubColor(home.id).withValues(alpha: .20),
            JuriTheme.surface,
            JuriTheme.clubColor(away.id).withValues(alpha: .20),
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Eyebrow(status, color: JuriTheme.gold)),
              if (match.isDemo) DemoLabel(label: Tr.t('demoMatches')),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _side(home, Tr.t('homeTeam'))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Headline(match.result, size: 46),
                ),
              ),
              Expanded(child: _side(away, Tr.t('awayTeam'))),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '${match.competition} · ${formatMatchDateLong(match.kickoff)}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: JuriTheme.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _side(Club club, String label) => Column(
    children: [
      ClubBadge(club, size: 52),
      const SizedBox(height: 10),
      Text(
        club.name,
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          letterSpacing: 1.2,
          color: JuriTheme.muted,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

/// Events read as a timeline with each club on its own side, so attribution
/// never depends on recognising a badge.
class _EventLine extends StatelessWidget {
  final MatchEvent event;
  final Match match;
  final Club home;
  const _EventLine({
    required this.event,
    required this.match,
    required this.home,
  });

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    final isHome = event.clubId == home.id;
    final player = repo.player(event.playerId);
    final assist = event.assistPlayerId == null
        ? null
        : repo.player(event.assistPlayerId!);
    final label = switch (event.type) {
      'goal' => event.detail == 'penalty' ? Tr.t('penaltyGoal') : Tr.t('goal'),
      'own_goal' => Tr.t('ownGoal'),
      'yellow' => Tr.t('yellow'),
      'red' => Tr.t('red'),
      _ => event.type,
    };
    final detail = Column(
      crossAxisAlignment: isHome
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          player?.name ?? event.playerId,
          textAlign: isHome ? TextAlign.right : TextAlign.left,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          assist == null ? label : '$label · ${Tr.t('assist')}: ${assist.name}',
          textAlign: isHome ? TextAlign.right : TextAlign.left,
          style: const TextStyle(fontSize: 11, color: JuriTheme.muted),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: isHome ? detail : const SizedBox.shrink()),
          Container(
            width: 42,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 3),
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: JuriTheme.elevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "${event.minute}'",
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: JuriTheme.gold,
              ),
            ),
          ),
          Expanded(child: isHome ? const SizedBox.shrink() : detail),
        ],
      ),
    );
  }
}

class _TeamSwitch extends StatelessWidget {
  final Club home, away;
  final String selected;
  final ValueChanged<String> onSelect;
  const _TeamSwitch({
    required this.home,
    required this.away,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: _tab(context, home)),
      const SizedBox(width: 10),
      Expanded(child: _tab(context, away)),
    ],
  );

  Widget _tab(BuildContext context, Club club) {
    final active = club.id == selected;
    final accent = JuriTheme.clubColor(club.id);
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(club.id),
        child: AnimatedContainer(
          duration: Duration(
            milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 180,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: active
                ? accent.withValues(alpha: .13)
                : JuriTheme.surface.withValues(alpha: .6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? accent : JuriTheme.line.withValues(alpha: .7),
            ),
          ),
          child: Row(
            children: [
              // The tap here picks a side; the badge must not navigate away.
              ClubBadge(club, size: 26, linked: false),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  club.shortName.isEmpty ? club.name : club.shortName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: active ? JuriTheme.ink : JuriTheme.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final int count;
  final Color accent;
  final String? note;
  final List<Widget> children;
  const _Group({
    required this.title,
    required this.count,
    required this.accent,
    required this.children,
    this.note,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
    decoration: BoxDecoration(
      color: JuriTheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: accent.withValues(alpha: .25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: JuriTheme.elevated,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: JuriTheme.muted,
                ),
              ),
            ),
          ],
        ),
        if (note != null) ...[
          const SizedBox(height: 6),
          Text(
            note!,
            style: const TextStyle(fontSize: 11, color: JuriTheme.muted),
          ),
        ],
        ...children,
        const SizedBox(height: 6),
      ],
    ),
  );
}

/// A team-sheet row: who they are, what the source knows, what they did, and
/// any score attached to the performance.
class LineupRow extends StatelessWidget {
  final PlayerAppearance appearance;
  const LineupRow({super.key, required this.appearance});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final repo = scope.repository;
    final player = repo.player(appearance.playerId);
    if (player == null) return const SizedBox.shrink();
    final match = repo.match(appearance.matchId);
    final own = scope.user.reviewFor(appearance.id);
    final scores = repo.appearanceScores(appearance);
    final score = scores.genel.published ? scores.genel.mean : own?.genelPuan;
    final goals = match?.goalsFor(player.id) ?? 0;
    final assists = match?.assistsFor(player.id) ?? 0;
    final cards = match == null
        ? const <MatchEvent>[]
        : match
              .eventsFor(player.id)
              .where((e) => e.type == 'yellow' || e.type == 'red')
              .toList();
    final dimmed = appearance.participationUnknown;

    return Pressable(
      onTap: () => openPerformance(context, appearance),
      child: Opacity(
        opacity: dimmed ? .62 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Portrait(player, width: 42, height: 48),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            player.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        for (var i = 0; i < goals; i++)
                          const _Marker(icon: Icons.sports_soccer),
                        for (var i = 0; i < assists; i++)
                          const _Marker(
                            icon: Icons.assistant_direction_outlined,
                          ),
                        for (final card in cards)
                          _Marker(
                            icon: Icons.rectangle,
                            color: card.type == 'red'
                                ? const Color(0xFFD05A4E)
                                : const Color(0xFFE7D56E),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        player.position ?? Tr.t('unknownPosition'),
                        appearanceStatus(appearance, includeRole: false),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: JuriTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (score != null)
                ScoreChip(score)
              else if (own != null)
                ScoreChip(own.genelPuan)
              else
                Text(
                  Tr.t('emptyScore'),
                  style: const TextStyle(color: JuriTheme.muted, fontSize: 13),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Marker extends StatelessWidget {
  final IconData icon;
  final Color? color;
  const _Marker({required this.icon, this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 5),
    child: Icon(icon, size: 13, color: color ?? JuriTheme.gold),
  );
}
