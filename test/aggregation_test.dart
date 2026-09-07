import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:juri/data/aggregation.dart';
import 'package:juri/data/attributes.dart';
import 'package:juri/data/match_models.dart';
import 'package:juri/data/repository.dart';
import 'package:juri/data/thresholds.dart';

LocalFootballRepository loadRepo() => LocalFootballRepository.fromJson(
  jsonDecode(File('data/app.json').readAsStringSync()),
  demo: jsonDecode(File('test/fixtures/demo_matches.json').readAsStringSync()),
);

void main() {
  late LocalFootballRepository repo;
  setUp(() => repo = loadRepo());

  test('Osimhen derby derives 20+ general and club disagreement from reviews', () {
    final app = repo.appearance('a-demo-gs-fb-2690888')!;
    final scores = repo.appearanceScores(app);
    expect(scores.genel.count, 22);
    expect(scores.genel.published, true);
    expect(scores.genel.lowSample, false);
    expect(scores.club.count, 8);
    expect(scores.club.published, true);
    expect(scores.club.lowSample, true);
    expect(scores.club.mean! > scores.genel.mean!, true);
    expect(scores.genel.displayAverage, isNot(scores.club.displayAverage));
  });

  test('General can qualify while club score stays withheld', () {
    final app = repo.appearance('a-demo-gs-bjk-2690888')!;
    final scores = repo.appearanceScores(app);
    // The counts are facts about the fixture and hold whatever the bar is.
    expect(scores.genel.count, 8);
    expect(scores.club.count, 3);
    expect(scores.genel.count, greaterThan(scores.club.count));
    expect(scores.genel.published, true);
    // Which side of the bar the smaller crowd falls on is the threshold's
    // call, not the fixture's: production withholds a crowd of three, the
    // pilot bar is low enough to publish it. Both are correct behaviour.
    expect(scores.club.published, 3 >= Thresholds.publish);
    expect(scores.club.withheld, 3 < Thresholds.publish);
  });

  test('Zero, withheld and short appearances keep distinct states', () {
    final zero = repo.appearanceScores(repo.appearance('a-demo-gs-kon-1944296')!);
    expect(zero.genel.empty, true);
    final few = repo.appearanceScores(repo.appearance('a-demo-gs-kon-2935561')!);
    expect(few.genel.count, 3);
    expect(few.genel.withheld, 3 < Thresholds.publish);
    final short = repo.appearance('a-demo-gs-bsh-2174480')!;
    expect(short.isShort, true);
    expect(short.seasonEligible, false);
    expect(repo.appearanceScores(short).genel.published, true);
    final unused = repo.appearance('a-demo-gs-bsh-2023994')!;
    expect(unused.reviewPermitted, false);
    // A starter without a published minute count still counts: being named in
    // the XI is itself evidence of a meaningful shift.
    final pending = repo.appearance('a-demo-gs-kon-2117517')!;
    expect(pending.minutesUnresolved, true);
    expect(pending.role, AppearanceRole.starter);
    expect(pending.participation, ParticipationEvidence.lineup);
    expect(pending.seasonEligible, true);
    expect(pending.reviewPermitted, true);
  });

  test('Unconfirmed substitutes are neither rated nor counted', () {
    const bench = PlayerAppearance(
      id: 'x',
      matchId: 'm',
      playerId: 'p',
      clubId: '3604',
      role: AppearanceRole.substitute,
      minutesUnresolved: true,
      templateId: AttributeCatalog.outfieldId,
    );
    expect(bench.participationUnknown, true);
    expect(bench.played, false);
    expect(bench.reviewPermitted, false);
    expect(bench.seasonEligible, false);

    // The same bench slot, once an event proves the player came on.
    final proven = bench.copyWith(evidence: ParticipationEvidence.event);
    expect(proven.participationUnknown, false);
    expect(proven.reviewPermitted, true);
    // Still no minutes, so it stays out of the season average.
    expect(proven.seasonEligible, false);
  });

  test('Real fixture set resolves every bench slot into played or unused', () {
    final live = LocalFootballRepository.fromJson(
      jsonDecode(File('data/app.json').readAsStringSync()),
      matchData: jsonDecode(File('data/matches.json').readAsStringSync()),
    );
    final all = [
      for (final m in live.matches) ...live.appearancesForMatch(m.id),
    ];
    final subs = all.where((a) => a.role == AppearanceRole.substitute).toList();
    final unused = all.where((a) => a.unused).toList();
    expect(subs, isNotEmpty);
    expect(unused, isNotEmpty);

    // The regression this guards: Mackolik files substitutions as their own
    // event kind, and when the scraper dropped them every bench name arrived
    // as an unresolved substitute, so "came on" listed only the handful who
    // had also scored or been booked. A substitute in the file now means the
    // source showed them entering the game, with the minute to prove it.
    for (final a in subs) {
      expect(a.minutesKnown, true);
      expect(a.minutes! > 0, true);
      expect(a.participation, ParticipationEvidence.minutes);
      expect(a.played, true);
      expect(a.reviewPermitted, true);
    }
    // Every club that used substitutes should show several of them, not one.
    final perMatchClub = <String, int>{};
    for (final a in subs) {
      perMatchClub['${a.matchId}:${a.clubId}'] =
          (perMatchClub['${a.matchId}:${a.clubId}'] ?? 0) + 1;
    }
    expect(perMatchClub.values.every((n) => n >= 1), true);
    expect(perMatchClub.values.fold<int>(0, (a, b) => a + b) / perMatchClub.length,
        greaterThan(2));

    // Named on the bench but never used: present for the team sheet, and
    // excluded from both rating and the season average.
    for (final a in unused) {
      expect(a.played, false);
      expect(a.reviewPermitted, false);
      expect(a.seasonEligible, false);
    }

    // Starters now carry a real minute count too, so one withdrawn early
    // drops out of the season average instead of riding on the old
    // "named in the XI is enough" fallback.
    final starters = all.where((a) => a.role == AppearanceRole.starter);
    expect(starters.every((a) => a.played && a.reviewPermitted), true);
    // Short cameos stay out of the season average; real shifts count.
    for (final a in [...starters, ...subs]) {
      expect(a.seasonEligible, a.minutes! >= 20);
    }
  });

  test('League table travels with the fixtures and agrees with them', () {
    final live = LocalFootballRepository.fromJson(
      jsonDecode(File('data/app.json').readAsStringSync()),
      matchData: jsonDecode(File('data/matches.json').readAsStringSync()),
    );
    expect(live.standings.length, 18);
    expect(live.standings.first.rank, 1);

    // The table used to be scraped separately and drifted behind the results
    // the app itself shipped, so a club's row could contradict its own
    // fixture list. Recount the fixtures and hold the two together.
    final played = <String, int>{};
    final points = <String, int>{};
    for (final m in live.matches) {
      if (m.status != MatchStatus.finished) continue;
      if (m.homeGoals == null || m.awayGoals == null) continue;
      for (final (club, scored, conceded) in [
        (m.homeClubId, m.homeGoals!, m.awayGoals!),
        (m.awayClubId, m.awayGoals!, m.homeGoals!),
      ]) {
        played[club] = (played[club] ?? 0) + 1;
        points[club] =
            (points[club] ?? 0) + (scored > conceded ? 3 : (scored == conceded ? 1 : 0));
      }
    }
    for (final row in live.standings) {
      expect(row.played, played[row.clubId] ?? 0,
          reason: 'played count for ${row.clubId}');
      expect(row.points, points[row.clubId] ?? 0,
          reason: 'points for ${row.clubId}');
      expect(row.won + row.drawn + row.lost, row.played);
    }
    // Ranking runs best-first on points.
    for (var i = 1; i < live.standings.length; i++) {
      expect(live.standings[i - 1].points >= live.standings[i].points, true);
    }
  });

  test('Fixture file without a table falls back to the bundled one', () {
    // The demo fixture carries no standings, so the reference data's table
    // must still come through rather than leaving an empty league.
    expect(repo.standings, isNotEmpty);
  });

  test('Goalkeeper template omits one-on-ones when unrated', () {
    final app = repo.appearance('a-demo-ts-fb-1136213')!;
    expect(app.templateId, AttributeCatalog.goalkeeperId);
    final scores = repo.appearanceScores(app);
    expect(scores.genel.published, true);
    expect(scores.genelAttributes['bire_bir']!.empty, true);
    expect(scores.genelAttributes['sut_kurtarma']!.count, greaterThan(0));
  });

  test('Outfield template stays identical for attacking full-back and defensive mid', () {
    final sallai = repo.appearance('a-demo-gs-fb-2698504')!;
    final torreira = repo.appearance('a-demo-gs-fb-2419707')!;
    expect(sallai.templateId, AttributeCatalog.outfieldId);
    expect(torreira.templateId, AttributeCatalog.outfieldId);
    expect(sallai.template.attributes.map((a) => a.key),
        torreira.template.attributes.map((a) => a.key));
    expect(sallai.positionNote, 'Hücum bek');
    expect(torreira.positionNote, 'Savunma orta sahası');
  });

  test('Season averages weight qualifying matches equally and isolate local reviews', () {
    final season = repo.seasonScores('2690888');
    expect(season.eligibleAppearances, 5);
    expect(season.qualifyingMatches, 5);
    expect(season.ready, true);
    expect(season.leaderboardReady, true);
    final means = [
      repo.appearanceScores(repo.appearance('a-demo-gs-fb-2690888')!).genel.mean!,
      repo.appearanceScores(repo.appearance('a-demo-gs-bjk-2690888')!).genel.mean!,
      repo.appearanceScores(repo.appearance('a-demo-gs-ts-2690888')!).genel.mean!,
      repo.appearanceScores(repo.appearance('a-demo-gs-bsh-2690888')!).genel.mean!,
      repo.appearanceScores(repo.appearance('a-demo-gs-kon-2690888')!).genel.mean!,
    ];
    final expected = means.reduce((a, b) => a + b) / means.length;
    expect(season.genel.mean, closeTo(expected, 0.0001));
    expect(
      repo.appearanceScores(repo.appearance('a-demo-gs-fb-2690888')!).genel.count,
      22,
    );
    expect(
      repo.communityReviews.every((r) => r.userId != 'local-user'),
      true,
    );
  });

  test('Equal match weighting ignores vote volume', () {
    final matchA = Match(
      id: 'a',
      competition: 'Süper Lig',
      season: '2026–2027',
      homeClubId: '3604',
      awayClubId: '3592',
      kickoff: DateTime.utc(2026, 8, 1),
      status: MatchStatus.finished,
      homeGoals: 1,
      awayGoals: 0,
    );
    final matchB = matchA.id == 'a'
        ? Match(
            id: 'b',
            competition: 'Süper Lig',
            season: '2026–2027',
            homeClubId: '3604',
            awayClubId: '3590',
            kickoff: DateTime.utc(2026, 8, 8),
            status: MatchStatus.finished,
            homeGoals: 1,
            awayGoals: 0,
          )
        : matchA;
    PlayerAppearance app(String id, String matchId) => PlayerAppearance(
      id: id,
      matchId: matchId,
      playerId: 'p',
      clubId: '3604',
      role: AppearanceRole.starter,
      minutes: 90,
      templateId: AttributeCatalog.outfieldId,
    );
    MatchReview review(String id, String appearance, double score) => MatchReview(
      id: id,
      userId: id,
      appearanceId: appearance,
      genelPuan: score,
      supporterClubId: '3592',
      createdAt: DateTime.utc(2026, 8, 2),
    );
    final season = CommunityAggregator.season(
      appearances: [app('aa', 'a'), app('bb', 'b')],
      communityReviews: [
        for (var i = 0; i < 20; i++) review('a$i', 'aa', 8),
        for (var i = 0; i < 5; i++) review('b$i', 'bb', 6),
      ],
      matches: {'a': matchA, 'b': matchB},
    );
    // Two rated matches is a season only if the floor is that low; under
    // production rules it is not, which is the weighting rule's whole point.
    expect(season.ready, 2 >= seasonScoreFloor);
    final third = Match(
      id: 'c',
      competition: 'Süper Lig',
      season: '2026–2027',
      homeClubId: '3604',
      awayClubId: '3596',
      kickoff: DateTime.utc(2026, 8, 15),
      status: MatchStatus.finished,
      homeGoals: 1,
      awayGoals: 0,
    );
    final ready = CommunityAggregator.season(
      appearances: [app('aa', 'a'), app('bb', 'b'), app('cc', 'c')],
      communityReviews: [
        for (var i = 0; i < 20; i++) review('a$i', 'aa', 8),
        for (var i = 0; i < 5; i++) review('b$i', 'bb', 6),
        for (var i = 0; i < 5; i++) review('c$i', 'cc', 7),
      ],
      matches: {'a': matchA, 'b': matchB, 'c': third},
    );
    expect(ready.genel.mean, closeTo(7.0, 0.0001));
  });

  test('Personal totals keep every rating the reader was allowed to write', () {
    const cameo = PlayerAppearance(
      id: 'cameo',
      matchId: 'm',
      playerId: 'p',
      clubId: '3604',
      role: AppearanceRole.substitute,
      minutes: 8,
      templateId: AttributeCatalog.outfieldId,
    );
    // Too short for a community season average, but the reader rated it.
    expect(cameo.seasonEligible, false);
    expect(cameo.reviewPermitted, true);
    final personal = CommunityAggregator.personal(
      appearances: const [cameo],
      localReviews: [
        MatchReview(
          id: 'local-cameo',
          userId: 'local-user',
          appearanceId: 'cameo',
          genelPuan: 6,
          supporterClubId: '3604',
          createdAt: DateTime.utc(2026, 9, 1),
        ),
      ],
    );
    expect(personal.overall.count, 1);
    expect(personal.overall.mean, 6);
  });

  test('Ranking floor tracks how far the season has actually run', () {
    final live = LocalFootballRepository.fromJson(
      jsonDecode(File('data/app.json').readAsStringSync()),
      matchData: jsonDecode(File('data/matches.json').readAsStringSync()),
    );
    // The floor always sits between the season-score floor and the
    // full-season rule, whichever thresholds the build was given.
    expect(live.rankingMinimumMatches, greaterThanOrEqualTo(seasonScoreFloor));
    expect(live.rankingMinimumMatches, lessThanOrEqualTo(seasonRankingFloor));
    // Under production rules the clamp has to actually bite: four rounds in,
    // a five-match floor would be unreachable for every player in the league,
    // which is how the ranking tab ended up dead. The pilot bar is already at
    // one match, so there is nothing left to climb down from.
    if (!Thresholds.pilot) {
      expect(live.rankingMinimumMatches, lessThan(seasonRankingFloor));
    }
    // Deep into a season the full-season rule takes over again.
    final long = LocalFootballRepository.fromJson(
      jsonDecode(File('data/app.json').readAsStringSync()),
      matchData: {
        'matches': [
          for (var i = 0; i < 12; i++)
            {
              'id': 'r$i',
              'homeClubId': '3604',
              'awayClubId': '3592',
              'kickoff': '2026-08-0${i % 9 + 1}T18:00:00Z',
              'status': 'finished',
              'homeGoals': 1,
              'awayGoals': 0,
              'isDemo': false,
            },
        ],
        'appearances': const [],
      },
    );
    expect(long.rankingMinimumMatches, seasonRankingFloor);
  });

  test('Transfer spells keep club scores separate', () {
    final season = repo.seasonScores('1136213');
    expect(season.clubSpells.length, 2);
    expect(season.spell('3596'), isNotNull);
    expect(season.spell('3604'), isNotNull);
    expect(season.ready, true);
    expect(season.leaderboardReady, true);
  });

  test('Upcoming and postponed matches do not open reviews', () {
    expect(repo.match('demo-gs-ala')!.reviewsOpen, false);
    expect(repo.match('demo-gs-sam')!.status, MatchStatus.postponed);
    expect(repo.match('demo-gs-sam')!.reviewsOpen, false);
  });

  test('Leaderboard only includes eligible demo players', () {
    final board = repo.leaderboard();
    expect(board, isNotEmpty);
    expect(board.any((row) => row.$1.id == '2690888'), true);
    expect(board.any((row) => row.$1.id == '1136213'), true);
    expect(board.any((row) => row.$1.id == '2174480'), false);
  });
}
