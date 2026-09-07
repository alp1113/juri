import 'package:flutter/material.dart';
import '../app/scope.dart';
import '../core/theme.dart';
import '../data/aggregation.dart';
import '../data/local_state.dart';
import '../data/match_models.dart';
import '../data/models.dart';
import '../l10n/strings.dart';
import '../shared/analysis.dart';
import '../shared/widgets.dart';
import 'matches.dart';
import 'performance.dart';
import 'rating.dart';
import 'take.dart';

void openPlayer(BuildContext context, Player player) =>
    openPage(context, PlayerScreen(player: player));

class PlayerScreen extends StatelessWidget {
  final Player player;
  const PlayerScreen({super.key, required this.player});
  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final repo = scope.repository;
    final club = repo.club(player.clubId);
    final appearances = repo.appearancesForPlayer(player.id);
    final season = repo.seasonScores(player.id);
    final record = repo.seasonStats(player.id);
    final personal = CommunityAggregator.personal(
      appearances: appearances,
      localReviews: scope.user.matchReviews.values,
    );
    final currentSpell = season.spell(player.clubId);
    final reviews = [
      for (final a in appearances) ...repo.reviewsForAppearance(a.id),
      for (final a in appearances)
        if (scope.user.reviewFor(a.id) != null) scope.user.reviewFor(a.id)!,
    ];
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: JuriTheme.background.withValues(alpha: .65),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: ClubBadge(club, size: 32),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 430,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(.4, -.3),
                        radius: 1,
                        colors: [
                          JuriTheme.clubColor(player.clubId).withValues(alpha: .2),
                          JuriTheme.background,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: -10,
                    top: 75,
                    width: 290,
                    height: 340,
                    child: Hero(
                      tag: 'player-${player.id}',
                      child: ShaderMask(
                        shaderCallback: (r) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white, Colors.white, Colors.transparent],
                          stops: [0, .55, 1],
                        ).createShader(r),
                        blendMode: BlendMode.dstIn,
                        child: Portrait(player),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow(
                          '${club.name.toUpperCase()} · ${player.position ?? '—'}',
                          color: JuriTheme.gold,
                        ),
                        const SizedBox(height: 12),
                        Headline(
                          player.name.replaceFirst(' ', '\n').toUpperCase(),
                          size: 58,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (repo.hasDemoContent) ...[
                    const DemoBanner(),
                    const SizedBox(height: 16),
                  ],
                  _identityCard(context, player, club),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: JuriTheme.surface,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow(Tr.t('seasonRecord'), color: JuriTheme.gold),
                        const SizedBox(height: 14),
                        SeasonRecordRow(key: const Key('seasonRecord'), record: record),
                        const SizedBox(height: 18),
                        DualScoreCard(
                          genel: season.ready
                              ? season.genel
                              : const PopulationScore(count: 0),
                          club: currentSpell?.ready == true
                              ? currentSpell!.overall
                              : const PopulationScore(count: 0),
                          clubName: club.name,
                          demo: repo.hasDemoContent,
                          accent: JuriTheme.clubColor(player.clubId),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          season.ready
                              ? '${CommunityAggregator.coverage(season.qualifyingMatches, season.eligibleAppearances)} ${Tr.t('coverage')}'
                              : Tr.t('seasonForming'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: JuriTheme.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Tr.t('coverageHint'),
                          style: const TextStyle(
                            fontSize: 10,
                            color: JuriTheme.muted,
                          ),
                        ),
                        if (personal.overall.count > 0) ...[
                          const SizedBox(height: 18),
                          const Divider(),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      Tr.t('personalSeason'),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: JuriTheme.muted,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Headline(
                                      personal.overall.displayAverage,
                                      size: 42,
                                      color: JuriTheme.gold,
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '${personal.overall.count} ${Tr.t('ratedCount')}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: JuriTheme.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton(
                          key: const Key('ratePlayer'),
                          onPressed: appearances.isEmpty
                              ? null
                              : () => openAppearancePicker(context, player),
                          child: Text(
                            appearances.isEmpty
                                ? Tr.t('noAppearances')
                                : Tr.t('rate'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (season.clubSpells.length > 1) ...[
                    SectionHeading(Tr.t('clubSpell')),
                    for (final spell in season.clubSpells)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '${repo.club(spell.clubId).name}: ${spell.ready ? spell.overall.displayAverage : Tr.t('seasonForming')} · ${CommunityAggregator.coverage(spell.qualifyingMatches, spell.eligibleAppearances)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                  ],
                  if (appearances.isNotEmpty) ...[
                    SectionHeading(Tr.t('analyzePlayer')),
                    if (repo.hasDemoContent) ...[
                      DemoLabel(label: Tr.t('demoCommunity')),
                      const SizedBox(height: 12),
                    ],
                    AttributeAnalysisBoard(
                      accent: JuriTheme.clubColor(player.clubId),
                      insights: [
                        for (final attr in appearances.first.template.attributes)
                          AttributeInsight(
                            attribute: attr,
                            community:
                                season.genelAttributes[attr.key] ??
                                const PopulationScore(count: 0),
                            personal:
                                (personal.attributes[attr.key]?.count ?? 0) > 0
                                ? personal.attributes[attr.key]!.mean
                                : null,
                          ),
                      ],
                    ),
                    SectionHeading(Tr.t('fixtures')),
                    for (final a in appearances)
                      _appearance(context, a, repo.match(a.matchId), scope),
                    PlayerTakes(player: player),
                    SectionHeading(Tr.t('publicReviews')),
                    if (repo.hasDemoContent) ...[
                      DemoLabel(label: Tr.t('demoCommunity')),
                      const SizedBox(height: 10),
                    ],
                    if (reviews.isEmpty)
                      Text(
                        Tr.t('unrated'),
                        style: const TextStyle(
                          color: JuriTheme.muted,
                          fontSize: 12,
                        ),
                      ),
                    for (final review in reviews.take(8))
                      _note(context, review, repo),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Text(
                        Tr.t('noAppearances'),
                        style: const TextStyle(color: JuriTheme.muted),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Age, nationality and the canonical registration name were parsed out of
  /// the dataset from the start but never rendered anywhere.
  Widget _identityCard(BuildContext context, Player player, Club club) {
    final age = player.ageAt(DateTime.now());
    final rows = <(String, String)>[
      (Tr.t('position'), player.position ?? Tr.t('unknownPosition')),
      (Tr.t('age'), age == null ? Tr.t('unknownValue') : '$age'),
      (Tr.t('nationality'), player.nationality ?? Tr.t('unknownValue')),
      (Tr.t('marketValue'), formatValue(player.marketValue)),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: JuriTheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(Tr.t('overview'), color: JuriTheme.gold),
          const SizedBox(height: 14),
          Wrap(
            spacing: 26,
            runSpacing: 16,
            children: [
              for (final (label, value) in rows)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                        color: JuriTheme.muted,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (player.officialName != null &&
              player.officialName != player.name) ...[
            const SizedBox(height: 16),
            Text(
              '${Tr.t('officialName')}: ${player.officialName}',
              style: const TextStyle(fontSize: 11, color: JuriTheme.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _appearance(
    BuildContext context,
    PlayerAppearance appearance,
    Match? match,
    AppScope scope,
  ) {
    if (match == null) return const SizedBox.shrink();
    final opponent = scope.repository.club(match.opponentOf(appearance.clubId));
    final scores = scope.repository.appearanceScores(appearance);
    final own = scope.user.reviewFor(appearance.id);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ClubBadge(opponent, size: 30),
      title: Text('${opponent.name}  ${match.result}'),
      subtitle: Text(
        [
          formatMatchDate(match.kickoff),
          if (match.goalsFor(appearance.playerId) > 0)
            '${match.goalsFor(appearance.playerId)} ${Tr.t('seasonGoals').toLowerCase()}',
          if (match.assistsFor(appearance.playerId) > 0)
            '${match.assistsFor(appearance.playerId)} ${Tr.t('seasonAssists').toLowerCase()}',
          appearanceStatus(appearance),
          if (scores.genel.published)
            '${Tr.t('genelSkor')} ${scores.genel.displayAverage}',
          if (own != null) '${Tr.t('yourRating')} ${formatScore(own.genelPuan)}',
        ].join(' · '),
      ),
      onTap: () => match.reviewsOpen && appearance.reviewPermitted
          ? openPerformance(context, appearance)
          : openMatch(context, match),
    );
  }

  Widget _note(BuildContext context, MatchReview review, repo) {
    final local = review.userId == localUserId;
    final user = repo.demoUser(review.userId);
    final appearance = repo.appearance(review.appearanceId);
    final match = appearance == null ? null : repo.match(appearance.matchId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${local ? Tr.t('yourReview') : user?.displayName ?? review.userId} · ${formatScore(review.genelPuan)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (match != null)
            Text(
              '${repo.club(match.homeClubId).shortName}–${repo.club(match.awayClubId).shortName} · ${formatMatchDate(match.kickoff)}',
              style: const TextStyle(fontSize: 11, color: JuriTheme.muted),
            ),
          if (review.juriNotu != null) Text(review.juriNotu!),
          if (review.edited)
            Text(
              Tr.t('edited'),
              style: const TextStyle(fontSize: 10, color: JuriTheme.gold),
            ),
          if (local)
            Text(
              Tr.t('localPreview'),
              style: const TextStyle(fontSize: 10, color: JuriTheme.muted),
            ),
        ],
      ),
    );
  }
}
