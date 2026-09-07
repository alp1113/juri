import 'package:flutter/material.dart';
import '../app/scope.dart';
import '../core/theme.dart';
import '../data/aggregation.dart';
import '../data/models.dart';
import '../data/thresholds.dart';
import '../l10n/strings.dart';
import '../shared/widgets.dart';
import 'players.dart';
import 'clubs.dart';
import 'statistics.dart';

class DiscoveryScreen extends StatefulWidget {
  final bool searchMode;
  const DiscoveryScreen({super.key, this.searchMode = false});
  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  String query = '';
  String? position, clubId, supporterId;
  int? maxAge;
  double? maxValue;
  Future<void> _filters() async {
    final repo = AppScope.of(context).repository;
    String? selected = clubId;
    int? age = maxAge;
    double? value = maxValue;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Tr.t('filters'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    initialValue: selected,
                    decoration: InputDecoration(labelText: Tr.t('clubs')),
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text(Tr.t('all')),
                      ),
                      ...repo.clubs.map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ),
                    ],
                    onChanged: (v) => update(() => selected = v),
                  ),
                  const SizedBox(height: 20),
                  Text('${Tr.t('maxAge')} · ${age ?? Tr.t('unlimited')}'),
                  Slider(
                    value: (age ?? 45).toDouble(),
                    min: 16,
                    max: 45,
                    divisions: 29,
                    onChanged: (v) =>
                        update(() => age = v == 45 ? null : v.toInt()),
                  ),
                  Text(
                    '${Tr.t('maxValue')} · ${value == null ? Tr.t('unlimited') : formatValue(value)}',
                  ),
                  Slider(
                    value: (value ?? 80000000) / 1000000,
                    min: 1,
                    max: 80,
                    divisions: 79,
                    onChanged: (v) =>
                        update(() => value = v == 80 ? null : v * 1000000),
                  ),
                  Text(
                    Tr.t('unknownExcluded'),
                    style: const TextStyle(
                      fontSize: 10,
                      color: JuriTheme.muted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        clubId = selected;
                        maxAge = age;
                        maxValue = value;
                      });
                      Navigator.pop(context);
                    },
                    child: Text(Tr.t('apply')),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          clubId = null;
                          maxAge = null;
                          maxValue = null;
                        });
                        Navigator.pop(context);
                      },
                      child: Text(Tr.t('reset')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final repo = scope.repository;
    final searching = query.trim().isNotEmpty;
    final now = DateTime.now();
    final filtered = repo
        .search(query)
        .where(
          (p) =>
              (position == null || p.positionGroup == position) &&
              (clubId == null || p.clubId == clubId) &&
              (maxAge == null ||
                  (p.ageAt(now) != null && p.ageAt(now)! <= maxAge!)) &&
              (maxValue == null ||
                  (p.marketValue != null && p.marketValue! <= maxValue!)),
        )
        .toList();
    final allowed = {for (final p in filtered) p.id};
    final board = searching
        ? const <(Player, SeasonAggregate)>[]
        : repo
              .leaderboard(clubId: supporterId)
              .where((row) => allowed.contains(row.$1.id))
              .toList();
    // Community ranking needs a crowd. Until the thresholds are met, rank the
    // reader's own reviews rather than showing an empty flagship screen.
    final personalBoard = searching || board.isNotEmpty
        ? const <(Player, PersonalSeason)>[]
        : repo
              .personalLeaderboard(scope.user.matchReviews.values)
              .where((row) => allowed.contains(row.$1.id))
              .toList();
    final personal = personalBoard.isNotEmpty;
    final players = searching
        ? filtered
        : personal
        ? [for (final row in personalBoard) row.$1]
        : [for (final row in board) row.$1];
    final clubs = query.trim().isEmpty
        ? <Club>[]
        : repo.clubs
              .where(
                (c) => normalizeSearch(c.name).contains(normalizeSearch(query)),
              )
              .toList();
    final body = CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Eyebrow(
                      widget.searchMode
                          ? Tr.t('search').toUpperCase()
                          : 'SÜPER LİG · ${Tr.t('season')}',
                      color: JuriTheme.gold,
                    ),
                    const Spacer(),
                    if (repo.hasDemoContent) const DemoLabel(),
                  ],
                ),
                const SizedBox(height: 14),
                Headline(
                  personal ? Tr.t('personalTitle') : Tr.t('rankingTitle'),
                  size: 54,
                ),
                const SizedBox(height: 12),
                Text(
                  personal ? Tr.t('personalBoard') : Tr.t('rankingBody'),
                  style: const TextStyle(color: JuriTheme.muted, fontSize: 12),
                ),
                if (personal) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: JuriTheme.elevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      Tr.fill('communityEmptyBody', {
                        'n': '${Thresholds.publish}',
                      }),
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.45,
                        color: JuriTheme.muted,
                      ),
                    ),
                  ),
                ],
                if (!widget.searchMode) ...[
                  const SizedBox(height: 22),
                  const _StatisticsEntry(),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('playerSearch'),
                        onChanged: (v) => setState(() => query = v),
                        decoration: InputDecoration(
                          hintText: Tr.t('search'),
                          prefixIcon: const Icon(Icons.search),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: Tr.t('filter'),
                      onPressed: _filters,
                      icon: Icon(
                        Icons.tune,
                        color:
                            clubId != null || maxAge != null || maxValue != null
                            ? JuriTheme.gold
                            : JuriTheme.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 38 * MediaQuery.textScalerOf(context).scale(1),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [null, 'GK', 'DF', 'MF', 'FW']
                        .map(
                          (g) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                g == null ? Tr.t('all') : Tr.group(g),
                              ),
                              selected: position == g,
                              onSelected: (_) => setState(() => position = g),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 15),
                // The supporter filter reads a community board. In personal
                // mode there is no crowd to slice, so it is hidden rather than
                // left on screen doing nothing.
                if (!personal)
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: supporterId,
                      isExpanded: true,
                      hint: Text(
                        Tr.t('allSupporters'),
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        color: JuriTheme.ink,
                      ),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text(Tr.t('allSupporters')),
                        ),
                        ...repo.clubs.map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Row(
                              children: [
                                ClubBadge(c, size: 22, linked: false),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    c.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => supporterId = v),
                    ),
                  ),
                if (clubs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...clubs.map(
                    (c) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClubBadge(c),
                      title: Text(c.name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => openPage(context, ClubScreen(club: c)),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        if (players.isEmpty)
          SliverToBoxAdapter(
            child: EmptyView(
              title: searching
                  ? Tr.t('noResults')
                  : Tr.t('communityEmpty'),
              body: searching
                  ? Tr.t('noResultsBody')
                  : Tr.t('personalEmptyBody'),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          sliver: SliverList.builder(
            itemCount: players.length,
            itemBuilder: (context, i) {
              final p = players[i];
              if (personal) {
                final row = personalBoard[i].$2;
                return PlayerRow(
                  key: Key('rank-${p.id}'),
                  player: p,
                  club: repo.club(p.clubId),
                  hero: true,
                  rank: i + 1,
                  score: row.overall.mean,
                  subtitle:
                      '${row.overall.count} ${Tr.t('ratedCount')} · ${Tr.t('yourAverage')}',
                  onTap: () => openPlayer(context, p),
                );
              }
              final season = searching ? null : repo.seasonScores(p.id);
              final score = season == null
                  ? null
                  : supporterId == null
                  ? season.genel.mean
                  : season.spell(supporterId!)?.overall.mean;
              return PlayerRow(
                key: Key('rank-${p.id}'),
                player: p,
                club: repo.club(p.clubId),
                hero: true,
                rank: searching ? null : i + 1,
                score: score,
                subtitle: season == null
                    ? null
                    : '${CommunityAggregator.coverage(season.qualifyingMatches, season.eligibleAppearances)} ${Tr.t('coverage')}',
                onTap: () => openPlayer(context, p),
              );
            },
          ),
        ),
      ],
    );
    // The board is only as fresh as the last community pull, and rating a
    // player is exactly when a reader wants to see the table move. Pull-to-
    // refresh belongs on the screen showing the table, not only on the feed.
    final remote = scope.remote;
    final refreshable = remote == null
        ? body
        : RefreshIndicator(
            color: JuriTheme.gold,
            backgroundColor: JuriTheme.surface,
            onRefresh: () => remote.refresh(),
            child: body,
          );
    return widget.searchMode
        ? Scaffold(
            appBar: AppBar(
              title: Text(Tr.t('search'), style: const TextStyle(fontSize: 14)),
            ),
            body: refreshable,
          )
        : refreshable;
  }
}

/// The way into the season statistics.
///
/// This was a line of text at the bottom of the feed, below the league table,
/// which is the last place anybody looks. Twenty-five boards deserve a door
/// people can actually see, and the rankings tab is where a reader already is
/// when they want them.
class _StatisticsEntry extends StatelessWidget {
  const _StatisticsEntry();

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: () => openStatistics(context),
    child: Container(
      key: const Key('openStatistics'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: JuriTheme.elevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: JuriTheme.gold.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: JuriTheme.gold.withValues(alpha: .16),
            ),
            child: const Icon(
              Icons.bar_chart_rounded,
              size: 21,
              color: JuriTheme.gold,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Tr.t('statisticsEntry'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  Tr.t('statisticsEntryBody'),
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: JuriTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.arrow_forward, size: 18, color: JuriTheme.gold),
        ],
      ),
    ),
  );
}
