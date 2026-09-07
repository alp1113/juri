import 'package:flutter/material.dart';
import '../app/scope.dart';
import '../core/theme.dart';
import '../data/match_models.dart';
import '../l10n/strings.dart';
import '../shared/widgets.dart';
import 'clubs.dart';
import 'matches.dart';
import 'players.dart';

/// The league's own furniture: the round, the table, the scorers.
///
/// These used to be a Home screen of their own. The feed is the home surface
/// now, so they ride inside it as cards rather than sitting on a tab the
/// reader has to leave the conversation to reach.

/// Your club's latest finished match, falling back to the league's.
Match? spotlightMatch(BuildContext context) {
  final repo = AppScope.of(context).repository;
  final clubId = AppScope.of(context).user.clubId;
  final own = clubId == null
      ? const <Match>[]
      : repo.matchesForClub(clubId).where((m) => m.status == MatchStatus.finished);
  if (own.isNotEmpty) return own.first;
  final league = [...repo.matches]
    ..sort((a, b) => b.kickoff.compareTo(a.kickoff));
  return league.where((m) => m.status == MatchStatus.finished).firstOrNull;
}

class SpotlightCard extends StatelessWidget {
  final Match match;
  const SpotlightCard({super.key, required this.match});
  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    final home = repo.club(match.homeClubId);
    final away = repo.club(match.awayClubId);
    return Pressable(
      key: Key('homeMatch-${match.id}'),
      onTap: () => openMatch(context, match),
      child: Container(
        // Sized by its contents so it grows with the reader's text setting
        // instead of clipping, and does not leave dead space when it fits.
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: const Color(0xFF2A3027),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Eyebrow(Tr.t('spotlight'), color: JuriTheme.gold),
                const Spacer(),
                if (match.isDemo) DemoLabel(label: Tr.t('demoMatches')),
              ],
            ),
            const SizedBox(height: 34),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Headline(
                '${home.shortName} ${match.result} ${away.shortName}',
                size: 44,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${home.name} · ${away.name}',
              style: const TextStyle(color: Color(0xFFBFC4B8), fontSize: 12),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  Tr.t('discover'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: JuriTheme.gold,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The reader's club first, then the rest of the round, without repeats.
class FixturesBlock extends StatelessWidget {
  static const limit = 5;
  const FixturesBlock({super.key});
  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final repo = scope.repository;
    final clubFixtures = scope.user.clubId == null
        ? const <Match>[]
        : repo.matchesForClub(scope.user.clubId!);
    final league = [...repo.matches]
      ..sort((a, b) => b.kickoff.compareTo(a.kickoff));
    final seen = {for (final m in clubFixtures) m.id};
    final fixtures = <Match>[
      ...clubFixtures,
      ...league.where((m) => !seen.contains(m.id)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          Tr.t('fixtures'),
          onTap: fixtures.length > limit ? () => openFixtures(context) : null,
        ),
        for (final match in fixtures.take(limit))
          FixtureRow(match: match, key: Key('fixture-${match.id}')),
        if (fixtures.length > limit)
          TextButton(
            onPressed: () => openFixtures(context),
            child: Text(Tr.t('seeAllFixtures')),
          ),
      ],
    );
  }
}

class ScorersBlock extends StatelessWidget {
  const ScorersBlock({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    final scorers = repo.topScorers(limit: 3);
    if (scorers.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(Tr.t('topScorer')),
        for (final (player, record) in scorers)
          PlayerRow(
            key: Key('scorer-${player.id}'),
            player: player,
            club: repo.club(player.clubId),
            hero: true,
            subtitle:
                '${repo.club(player.clubId).name} · '
                '${record.goals} ${Tr.t('seasonGoals')}'
                '${record.assists > 0 ? ' · ${record.assists} ${Tr.t('seasonAssists')}' : ''}',
            onTap: () => openPlayer(context, player),
          ),
      ],
    );
  }
}

class StandingsBlock extends StatelessWidget {
  final VoidCallback onClubs;
  const StandingsBlock({super.key, required this.onClubs});
  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(Tr.t('standings'), onTap: onClubs),
        ...repo.standings
            .take(4)
            .map((s) => StandingRow(standing: s, club: repo.club(s.clubId))),
      ],
    );
  }
}

/// The two rankings surfaces plus the provenance line that closes the page.
class LeagueLinksBlock extends StatelessWidget {
  final VoidCallback onRankings;
  const LeagueLinksBlock({super.key, required this.onRankings});
  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        // Season statistics used to sit here, at the very bottom of the feed,
        // where readers scrolled past it. It lives on the rankings tab now,
        // as a card rather than a line of text.
        _link(context, Tr.t('rankings'), const Key('discoverPlayer'), onRankings),
        const SizedBox(height: 20),
        Eyebrow('${repo.meta.season} · ${Tr.t('dataSource').toUpperCase()}'),
        if (repo.matchMeta.provider.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            '${Tr.t('sourceLine')}: ${repo.matchMeta.provider}',
            style: const TextStyle(fontSize: 10, color: JuriTheme.muted),
          ),
        ],
      ],
    );
  }

  Widget _link(BuildContext context, String label, Key key, VoidCallback onTap) =>
      Pressable(
        onTap: onTap,
        child: Row(
          children: [
            Text(
              label,
              key: key,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward, size: 16, color: JuriTheme.gold),
          ],
        ),
      );
}
