import 'package:flutter/material.dart';
import '../app/scope.dart';
import '../core/theme.dart';
import '../data/match_models.dart';
import '../data/models.dart';
import '../data/stat_boards.dart';
import '../l10n/strings.dart';
import '../shared/widgets.dart';
import 'players.dart';

/// How many rows a counted board shows on the overview before the reader
/// opens it. Opinion boards preview their leader only: there are fourteen of
/// them, and three rows each would bury the counted boards they sit beside.
const _previewRows = 3;

String _boardTitle(String id) =>
    Tr.t('board${id[0].toUpperCase()}${id.substring(1)}');

String _groupTitle(StatBoardGroup group) => Tr.t(switch (group) {
  StatBoardGroup.attack => 'groupAttack',
  StatBoardGroup.defence => 'groupDefence',
  StatBoardGroup.discipline => 'groupDiscipline',
  StatBoardGroup.workload => 'groupWorkload',
  StatBoardGroup.goalkeeping => 'groupGoalkeeping',
});

/// Rate boards read as decimals; every other board counts whole events and
/// should never render "12,0 gol".
bool _isRate(String id) => id == 'cardRate' || id == 'concededRate';

String _boardValue(String id, double value) =>
    _isRate(id) ? formatScore(value, decimals: 2) : value.toInt().toString();

String _boardUnit(String id) => switch (id) {
  'goals' || 'contributions' || 'substituteImpact' => Tr.t('unitGoal'),
  'assists' => Tr.t('unitAssist'),
  'yellows' => Tr.t('unitYellow'),
  'reds' => Tr.t('unitRed'),
  'minutes' => Tr.t('unitMinute'),
  'starts' => Tr.t('unitStart'),
  'cleanSheets' => Tr.t('unitCleanSheet'),
  'cardRate' || 'concededRate' => Tr.t('per90'),
  _ => '',
};

/// The line under the player's name: the football that produced the number,
/// so a tally is never shown without the workload behind it.
String _boardDetail(String id, PlayerSeasonStats s) {
  final matches = '${s.matches} ${Tr.t('unitMatch')}';
  return switch (id) {
    'goals' || 'assists' || 'contributions' =>
      '$matches · ${s.minutes} ${Tr.t('unitMinute')}',
    'substituteImpact' =>
      '${s.substituteGoals} ${Tr.t('unitGoal')} · '
          '${s.substituteAssists} ${Tr.t('unitAssist')} · '
          '${s.substituteMatches} ${Tr.t('unitMatch')}',
    'yellows' || 'reds' || 'cardRate' =>
      '${s.yellows} ${Tr.t('unitYellow')} · ${s.reds} ${Tr.t('unitRed')} · '
          '${s.minutes} ${Tr.t('unitMinute')}',
    'minutes' => '$matches · ${s.starts} ${Tr.t('unitStart')}',
    'starts' => '$matches · ${s.minutes} ${Tr.t('unitMinute')}',
    'cleanSheets' || 'concededRate' =>
      '${s.keeperMatches} ${Tr.t('unitMatch')} · '
          '${s.conceded} ${Tr.t('unitConceded')}',
    _ => matches,
  };
}

/// The number on the right of a counted row. Deliberately not [ScoreChip]:
/// a gold pill in this app means a 1–10 rating, and eleven goals is not one.
/// The two kinds of board sit side by side here, so the difference has to be
/// legible without reading the heading.
class StatValue extends StatelessWidget {
  final String value, unit;
  const StatValue({super.key, required this.value, required this.unit});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: JuriTheme.gold,
          letterSpacing: -.5,
        ),
      ),
      if (unit.isNotEmpty)
        Text(
          unit.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w800,
            color: JuriTheme.muted,
          ),
        ),
    ],
  );
}

class StatRow extends StatelessWidget {
  final int rank;
  final Player player;
  final Club club;
  final String detail, value, unit;
  final VoidCallback onTap;
  const StatRow({
    super.key,
    required this.rank,
    required this.player,
    required this.club,
    required this.detail,
    required this.value,
    required this.unit,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              rank.toString().padLeft(2, '0'),
              style: const TextStyle(fontSize: 12, color: JuriTheme.muted),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Portrait(player, width: 40, height: 46),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${club.shortName} · $detail',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: JuriTheme.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatValue(value: value, unit: unit),
        ],
      ),
    ),
  );
}

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: JuriTheme.elevated,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 10.5,
        height: 1.5,
        color: JuriTheme.muted,
      ),
    ),
  );
}

/// Separates the counted half of a group from the rated half.
class _Divider extends StatelessWidget {
  final String label;
  const _Divider(this.label);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 2),
    child: Row(
      children: [
        Eyebrow(label, color: JuriTheme.muted),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: JuriTheme.line)),
      ],
    ),
  );
}

class _BoardHeading extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  const _BoardHeading(this.title, {this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),
        if (onTap != null)
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(Tr.t('seeAll'), style: const TextStyle(fontSize: 10)),
          ),
      ],
    ),
  );
}

/// A counted board, previewed on the overview screen.
class StatBoardCard extends StatelessWidget {
  final StatBoard board;
  final String? clubId;
  const StatBoardCard({super.key, required this.board, this.clubId});
  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    final id = board.def.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BoardHeading(
          _boardTitle(id),
          onTap: board.rows.length > _previewRows
              ? () => openPage(
                  context,
                  StatBoardScreen(def: board.def, clubId: clubId),
                )
              : null,
        ),
        for (final row in board.rows.take(_previewRows))
          StatRow(
            key: Key('stat-$id-${row.player.id}'),
            rank: row.rank,
            player: row.player,
            club: repo.club(row.player.clubId),
            detail: _boardDetail(id, row.stats),
            value: _boardValue(id, row.value),
            unit: _boardUnit(id),
            onTap: () => openPlayer(context, row.player),
          ),
        if (board.undifferentiated) _Note(Tr.t('boardTied')),
        if (board.def.minimumMinutes > 0) _Note(Tr.t('boardMinimum')),
      ],
    );
  }
}

/// One rating attribute, previewed by its leader alone. The full ranking is a
/// tap away; what belongs on the overview is which quality is being ranked and
/// who currently holds it.
class OpinionLeaderRow extends StatelessWidget {
  final OpinionBoard board;
  final String? clubId;
  const OpinionLeaderRow({super.key, required this.board, this.clubId});
  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    final leader = board.rows.first;
    return Pressable(
      key: Key('opinion-${board.def.id}'),
      onTap: () => openPage(
        context,
        OpinionBoardScreen(def: board.def, clubId: clubId),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Portrait(leader.player, width: 34, height: 40),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    board.def.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${leader.player.name} · '
                    '${repo.club(leader.player.clubId).shortName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: JuriTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (leader.score.mean != null) ScoreChip(leader.score.mean!),
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: JuriTheme.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});
  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  String? clubId;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final repo = scope.repository;
    final reviews = scope.user.matchReviews.values;
    final counted = [
      for (final def in StatBoards.all)
        repo.statBoard(def, clubId: clubId, limit: 25),
    ];
    final rated = [
      for (final def in OpinionBoards.all)
        repo.opinionBoard(def, localReviews: reviews, clubId: clubId, limit: 25),
    ];
    // With no crowd and no ratings of your own, every opinion board is empty.
    // Say that once, at the top, instead of repeating it under five headings.
    final anyRated = rated.any((b) => !b.isEmpty);

    List<Widget> group(StatBoardGroup group) {
      final groupCounted = [
        for (final b in counted)
          if (b.def.group == group && !b.isEmpty) b,
      ];
      final groupRated = [
        for (final b in rated)
          if (b.def.group == group && !b.isEmpty) b,
      ];
      if (groupCounted.isEmpty && groupRated.isEmpty) return const [];
      return [
        SectionHeading(_groupTitle(group)),
        if (groupCounted.isNotEmpty) ...[
          _Divider(Tr.t('countedTitle')),
          for (final board in groupCounted)
            StatBoardCard(board: board, clubId: clubId),
        ],
        if (groupRated.isNotEmpty) ...[
          _Divider(Tr.t('ratedTitle')),
          for (final board in groupRated)
            OpinionLeaderRow(board: board, clubId: clubId),
        ],
      ];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(Tr.t('statistics'), style: const TextStyle(fontSize: 14)),
      ),
      body: CustomScrollView(
        key: const PageStorageKey('statistics'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Eyebrow(
                        'SÜPER LİG · ${Tr.t('season')}',
                        color: JuriTheme.gold,
                      ),
                      const Spacer(),
                      if (repo.hasDemoContent) const DemoLabel(),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Headline(Tr.t('statisticsTitle'), size: 46),
                  const SizedBox(height: 12),
                  Text(
                    Tr.t('statisticsBody'),
                    style: const TextStyle(
                      color: JuriTheme.muted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      key: const Key('statsClubFilter'),
                      value: clubId,
                      isExpanded: true,
                      hint: Text(
                        Tr.t('all'),
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
                          child: Text(Tr.t('all')),
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
                      onChanged: (v) => setState(() => clubId = v),
                    ),
                  ),
                  if (!anyRated) ...[
                    const SizedBox(height: 6),
                    Eyebrow(Tr.t('ratedTitle'), color: JuriTheme.gold),
                    _Note(Tr.t('opinionEmptyBody')),
                  ],
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            sliver: SliverList.list(
              children: [
                for (final g in StatBoardGroup.values) ...group(g),
                const SizedBox(height: 28),
                Eyebrow(Tr.t('statsSource'), color: JuriTheme.muted),
                _Note(Tr.t('statsSourceBody')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The full list behind one counted board.
class StatBoardScreen extends StatelessWidget {
  final StatBoardDef def;
  final String? clubId;
  const StatBoardScreen({super.key, required this.def, this.clubId});
  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    final board = repo.statBoard(def, clubId: clubId);
    return Scaffold(
      appBar: AppBar(
        title: Text(_boardTitle(def.id), style: const TextStyle(fontSize: 14)),
      ),
      body: board.isEmpty
          ? EmptyView(title: _boardTitle(def.id), body: Tr.t('boardEmpty'))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              itemCount: board.rows.length + 1,
              itemBuilder: (context, i) {
                if (i == board.rows.length) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (board.undifferentiated) _Note(Tr.t('boardTied')),
                      if (def.minimumMinutes > 0) _Note(Tr.t('boardMinimum')),
                    ],
                  );
                }
                final row = board.rows[i];
                return StatRow(
                  key: Key('stat-${def.id}-${row.player.id}'),
                  rank: row.rank,
                  player: row.player,
                  club: repo.club(row.player.clubId),
                  detail: _boardDetail(def.id, row.stats),
                  value: _boardValue(def.id, row.value),
                  unit: _boardUnit(def.id),
                  onTap: () => openPlayer(context, row.player),
                );
              },
            ),
    );
  }
}

/// The full ranking behind one rating attribute.
class OpinionBoardScreen extends StatelessWidget {
  final OpinionBoardDef def;
  final String? clubId;
  const OpinionBoardScreen({super.key, required this.def, this.clubId});
  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final repo = scope.repository;
    final board = repo.opinionBoard(
      def,
      localReviews: scope.user.matchReviews.values,
      clubId: clubId,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(def.label, style: const TextStyle(fontSize: 14)),
      ),
      body: board.isEmpty
          ? EmptyView(title: def.label, body: Tr.t('opinionEmptyBody'))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              itemCount: board.rows.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow(
                        board.personal
                            ? Tr.t('opinionPersonal')
                            : Tr.t('opinionCommunity'),
                        color: JuriTheme.gold,
                      ),
                      // The prompt supporters answered when they gave this
                      // score. Without it the board is a number with no
                      // question attached.
                      if (def.definition != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            def.definition!.prompt,
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.5,
                              color: JuriTheme.muted,
                            ),
                          ),
                        ),
                      _Note(Tr.t('opinionBody')),
                      const SizedBox(height: 4),
                    ],
                  );
                }
                final row = board.rows[i - 1];
                return PlayerRow(
                  key: Key('opinionRow-${def.id}-${row.player.id}'),
                  player: row.player,
                  club: repo.club(row.player.clubId),
                  rank: row.rank,
                  score: row.score.mean,
                  subtitle:
                      '${repo.club(row.player.clubId).shortName} · '
                      '${row.score.count} ${Tr.t('ratedBy')}',
                  onTap: () => openPlayer(context, row.player),
                );
              },
            ),
    );
  }
}

void openStatistics(BuildContext context) =>
    openPage(context, const StatisticsScreen());
