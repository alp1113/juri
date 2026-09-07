import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:juri/data/match_models.dart';
import 'package:juri/data/repository.dart';
import 'package:juri/data/stat_boards.dart';

LocalFootballRepository loadLive() => LocalFootballRepository.fromJson(
  jsonDecode(File('data/app.json').readAsStringSync()),
  matchData: jsonDecode(File('data/matches.json').readAsStringSync()),
);

void main() {
  late LocalFootballRepository repo;
  setUpAll(() => repo = loadLive());

  test('Season lines agree with the raw fixture feed', () {
    final feed =
        jsonDecode(File('data/matches.json').readAsStringSync())
            as Map<String, dynamic>;
    final finished = {
      for (final m in feed['matches'] as List)
        if ((m as Map)['status'] == 'finished') '${m['id']}': m,
    };
    final goals = <String, int>{};
    final assists = <String, int>{};
    final yellows = <String, int>{};
    final reds = <String, int>{};
    for (final m in finished.values) {
      for (final e in m['events'] as List) {
        final id = '${(e as Map)['playerId']}';
        switch (e['type']) {
          case 'goal':
            goals[id] = (goals[id] ?? 0) + 1;
          case 'assist':
            assists[id] = (assists[id] ?? 0) + 1;
          case 'yellow':
            yellows[id] = (yellows[id] ?? 0) + 1;
          case 'red':
            reds[id] = (reds[id] ?? 0) + 1;
        }
      }
    }
    final minutes = <String, int>{};
    for (final a in feed['appearances'] as List) {
      final row = a as Map;
      if (!finished.containsKey('${row['matchId']}')) continue;
      if (row['role'] == 'unusedSubstitute') continue;
      final id = '${row['playerId']}';
      minutes[id] = (minutes[id] ?? 0) + (row['minutes'] as int? ?? 0);
    }
    // Every counter the app publishes has to match a count taken straight off
    // the feed, or a leaderboard is quietly inventing football.
    for (final id in {...goals.keys, ...assists.keys, ...minutes.keys}) {
      final stats = repo.seasonStats(id);
      expect(stats.goals, goals[id] ?? 0, reason: 'goals for $id');
      expect(stats.assists, assists[id] ?? 0, reason: 'assists for $id');
      expect(stats.yellows, yellows[id] ?? 0, reason: 'yellows for $id');
      expect(stats.reds, reds[id] ?? 0, reason: 'reds for $id');
      expect(stats.minutes, minutes[id] ?? 0, reason: 'minutes for $id');
    }
  });

  test('Assist board ranks the feed assists and never double counts', () {
    final board = repo.statBoard(StatBoards.assists);
    expect(board.isEmpty, false);
    // The feed emits a standalone assist event and repeats the passer on the
    // goal. Counting both would double every assist in the league.
    final total = board.rows.fold<int>(0, (sum, r) => sum + r.value.toInt());
    expect(total, 57);
    for (var i = 1; i < board.rows.length; i++) {
      expect(board.rows[i].value <= board.rows[i - 1].value, true);
    }
  });

  test('Ties share a rank instead of implying an order', () {
    final board = repo.statBoard(StatBoards.assists);
    final top = board.rows.where((r) => r.value == board.rows.first.value);
    expect(top.length, greaterThan(1));
    expect(top.every((r) => r.rank == 1), true);
    // The next distinct reading skips the ranks the tie consumed.
    final after = board.rows.firstWhere((r) => r.rank != 1);
    expect(after.rank, top.length + 1);
  });

  test('A board where nobody separates says so', () {
    final reds = repo.statBoard(StatBoards.reds);
    expect(reds.isEmpty, false);
    expect(reds.rows.every((r) => r.value == 1), true);
    expect(reds.undifferentiated, true);
    expect(repo.statBoard(StatBoards.minutes).undifferentiated, false);
    // The flag reads the whole field. Every player at the head of the minutes
    // board is level on 360, but the board below them separates perfectly
    // well, so a four-row preview must not claim otherwise.
    final preview = repo.statBoard(StatBoards.minutes, limit: 4);
    expect(preview.rows.every((r) => r.value == 360), true);
    expect(preview.undifferentiated, false);
  });

  test('Workload ties favour the player who played more football', () {
    final starts = repo.statBoard(StatBoards.starts);
    final level = starts.rows.where((r) => r.rank == 1).toList();
    expect(level.length, greaterThan(1));
    for (var i = 1; i < level.length; i++) {
      expect(level[i].stats.minutes <= level[i - 1].stats.minutes, true);
    }
    // A scoring board breaks the same tie the other way: the same tally in
    // fewer minutes is the better return.
    final goals = repo.statBoard(StatBoards.goals);
    final tiedOnGoals = goals.rows.where((r) => r.rank == 2).toList();
    expect(tiedOnGoals.length, greaterThan(1));
    for (var i = 1; i < tiedOnGoals.length; i++) {
      expect(
        tiedOnGoals[i].stats.minutes >= tiedOnGoals[i - 1].stats.minutes,
        true,
      );
    }
  });

  test('Clean sheets belong to keepers who played the whole match', () {
    final board = repo.statBoard(StatBoards.cleanSheets);
    expect(board.isEmpty, false);
    for (final row in board.rows) {
      expect(row.stats.keptGoal, true);
      expect(row.value <= row.stats.keeperFullMatches, true);
      // A shutout cannot outnumber the matches in which nothing was conceded.
      expect(row.stats.cleanSheets <= row.stats.keeperMatches, true);
    }
  });

  test('Rate boards exclude anyone the feed barely timed', () {
    for (final def in [StatBoards.concededRate, StatBoards.cardRate]) {
      final board = repo.statBoard(def);
      for (final row in board.rows) {
        expect(row.stats.minutes >= rateBoardMinimumMinutes, true);
      }
    }
    // Fewest conceded per ninety wins, so the board climbs rather than falls.
    final conceded = repo.statBoard(StatBoards.concededRate);
    expect(conceded.isEmpty, false);
    for (var i = 1; i < conceded.rows.length; i++) {
      expect(conceded.rows[i].value >= conceded.rows[i - 1].value, true);
    }
    expect(conceded.rows.every((r) => r.stats.keeperMatches >= 3), true);
  });

  test('Substitute impact counts only what happened off the bench', () {
    final board = repo.statBoard(StatBoards.substituteImpact);
    expect(board.isEmpty, false);
    for (final row in board.rows) {
      expect(row.stats.substituteGoals <= row.stats.goals, true);
      expect(row.stats.substituteAssists <= row.stats.assists, true);
      expect(row.stats.substituteMatches, greaterThan(0));
    }
  });

  test('A club filter keeps a board inside one squad', () {
    final all = repo.statBoard(StatBoards.minutes);
    final galatasaray = repo.statBoard(StatBoards.minutes, clubId: '3604');
    expect(galatasaray.isEmpty, false);
    expect(galatasaray.rows.length, lessThan(all.rows.length));
    expect(galatasaray.rows.every((r) => r.player.clubId == '3604'), true);
    expect(galatasaray.rows.first.rank, 1);
  });

  test('Unused substitutes never reach a board', () {
    final bench = repo.appearances.where((a) => a.unused).toList();
    expect(bench, isNotEmpty);
    for (final a in bench.take(40)) {
      final played = repo
          .appearancesForPlayer(a.playerId)
          .where((x) => x.played)
          .length;
      expect(repo.seasonStats(a.playerId).matches, played);
    }
  });

  test('Opinion boards fall back to the reader and say so', () {
    final passing = OpinionBoards.all.firstWhere(
      (d) => d.attributeKey == 'pas' && d.templateId == 'outfield.v1',
    );
    // No crowd exists in the bundled data, so an unfed board is empty rather
    // than inventing a community verdict.
    final community = repo.opinionBoard(passing);
    expect(community.isEmpty, true);
    expect(community.personal, true);

    final appearance = repo.appearances.firstWhere(
      (a) => a.reviewPermitted && a.templateId == 'outfield.v1',
    );
    final review = MatchReview(
      id: 'local-1',
      userId: 'me',
      appearanceId: appearance.id,
      supporterClubId: appearance.clubId,
      genelPuan: 8,
      attributes: const {'pas': 9},
      createdAt: DateTime.now(),
    );
    final personal = repo.opinionBoard(passing, localReviews: [review]);
    expect(personal.personal, true);
    expect(personal.rows.length, 1);
    expect(personal.rows.first.player.id, appearance.playerId);
    expect(personal.rows.first.score.mean, 9);
  });

  test('A keeper rating never lands on an outfield board', () {
    final keeperApp = repo.appearances.firstWhere(
      (a) => a.reviewPermitted && a.templateId == 'goalkeeper.v1',
    );
    final review = MatchReview(
      id: 'local-gk',
      userId: 'me',
      appearanceId: keeperApp.id,
      supporterClubId: keeperApp.clubId,
      genelPuan: 8,
      attributes: const {'pas': 10},
      createdAt: DateTime.now(),
    );
    // Both templates carry a `pas` attribute, rated against different
    // prompts. A keeper's distribution score must not outrank a midfielder on
    // a question nobody asked about them.
    final outfield = OpinionBoards.all.firstWhere(
      (d) => d.attributeKey == 'pas' && d.templateId == 'outfield.v1',
    );
    expect(repo.opinionBoard(outfield, localReviews: [review]).isEmpty, true);

    final keeperBoard = OpinionBoards.all.firstWhere(
      (d) => d.templateId == 'goalkeeper.v1',
    );
    final saves = MatchReview(
      id: 'local-gk2',
      userId: 'me',
      appearanceId: keeperApp.id,
      supporterClubId: keeperApp.clubId,
      genelPuan: 8,
      attributes: {keeperBoard.attributeKey: 7},
      createdAt: DateTime.now(),
    );
    final board = repo.opinionBoard(keeperBoard, localReviews: [saves]);
    expect(board.rows.length, 1);
    expect(board.rows.first.player.id, keeperApp.playerId);
  });

  test('Every group pairs counted boards with rated ones', () {
    // The point of the section: each quality carries both what the feed can
    // count and what only supporters can judge. Defence is the exception the
    // free data forces — nothing countable exists for it.
    for (final group in StatBoardGroup.values) {
      final rated = OpinionBoards.inGroup(group);
      expect(rated, isNotEmpty, reason: '$group has no opinion board');
      final counted = StatBoards.all.where((d) => d.group == group);
      if (group != StatBoardGroup.defence) {
        expect(counted, isNotEmpty, reason: '$group has no counted board');
      } else {
        expect(counted, isEmpty);
      }
    }
    // Board ids stay unique across the two templates that share attribute keys.
    final ids = OpinionBoards.all.map((d) => d.id).toSet();
    expect(ids.length, OpinionBoards.all.length);
    // Every board names a real attribute in its own template.
    for (final def in OpinionBoards.all) {
      expect(def.definition, isNotNull, reason: def.id);
      expect(def.label, isNot(def.attributeKey));
    }
  });

  test('Every board the screen offers is computable', () {
    for (final def in StatBoards.all) {
      final board = repo.statBoard(def);
      expect(board.def.id, def.id);
      for (final row in board.rows) {
        expect(row.value.isFinite, true);
        expect(row.rank, greaterThan(0));
      }
    }
  });
}
