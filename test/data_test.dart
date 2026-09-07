import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:juri/data/models.dart';
import 'package:juri/data/repository.dart';
import 'package:juri/data/local_state.dart';
import 'package:juri/data/value_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _sourceTests();
  late LocalFootballRepository repo;
  setUp(
    () => repo = LocalFootballRepository.fromJson(
      jsonDecode(File('data/app.json').readAsStringSync()),
    ),
  );
  test('Complete dataset is indexed by stable IDs and assets exist', () {
    expect(repo.clubs.length, 18);
    expect(repo.players.length, 617);
    for (final p in repo.players) {
      expect(repo.club(p.clubId).id, p.clubId);
      expect(repo.squad(p.clubId), contains(p));
      if (p.photo != null) {
        expect(File(p.photo!).existsSync(), true, reason: p.photo);
      }
    }
    for (final c in repo.clubs) {
      expect(File(c.badge).existsSync(), true);
    }
    expect(repo.stadium('3610'), isNull);
    expect(repo.players.where((p) => p.marketValue == null).length, 134);
  });
  test('Search preserves Turkish name discovery', () {
    expect(
      repo.search('abdulkerim').any((p) => p.name == 'Abdülkerim Bardakcı'),
      true,
    );
    expect(repo.search('ORKUN KOKCU').any((p) => p.id == '2217597'), true);
    expect(normalizeSearch('İSTANBUL IĞDIR ÇÖŞÜ'), 'istanbul igdir cosu');
  });
  test('Age follows birthday boundaries and missing data stays missing', () {
    final p = repo.player('1048397')!;
    expect(p.ageAt(DateTime(2026, 9, 6)), 31);
    expect(p.ageAt(DateTime(2026, 9, 7)), 32);
    expect(formatValue(null), '—');
    expect(formatValue(6500000), '€6.5M');
    expect(formatValue(850000), '€850K');
    expect(
      const Player(id: 'x', clubId: 'x', name: 'X').ageAt(DateTime.now()),
      isNull,
    );
  });
  test(
    'Game rejects ties, excludes unknown values, and handles streak lifecycle',
    () {
      final game = ValueGame(repo.players, random: Random(9));
      for (var i = 0; i < 100; i++) {
        expect(game.left.marketValue, isNotNull);
        expect(game.right.marketValue, isNotNull);
        expect(game.left.marketValue, isNot(game.right.marketValue));
        expect(
          game.choose(game.right.marketValue! > game.left.marketValue!),
          true,
        );
        expect(game.streak, i + 1);
        game.choose(false);
        expect(game.streak, i + 1);
        game.next();
      }
      expect(
        game.choose(game.right.marketValue! < game.left.marketValue!),
        false,
      );
      expect(game.streak, 100);
      game.next();
      expect(game.streak, 0);
    },
  );
  test(
    'Supporter identity, ratings, settings and record survive recreation',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final user = LocalUserState(prefs);
      await user.chooseClub('3604');
      await user.chooseClub('3592');
      await user.rate('2690888', 9.1);
      await user.recordScore(12);
      await user.recordScore(4);
      await user.setHaptics(false);
      final restored = LocalUserState(prefs);
      expect(restored.clubId, '3604');
      expect(restored.ratings['2690888'], 9.1);
      expect(restored.highScore, 12);
      expect(restored.haptics, false);
      await expectLater(user.rate('x', 11), throwsArgumentError);
    },
  );

  test('Match catalog indexes real Super Lig fixtures by stable IDs', () {
    final live = LocalFootballRepository.fromJson(
      jsonDecode(File('data/app.json').readAsStringSync()),
      matchData: jsonDecode(File('data/matches.json').readAsStringSync()),
    );
    expect(live.matches.length, greaterThanOrEqualTo(7));
    expect(live.matches.every((m) => !m.isDemo), true);
    expect(live.match('mk-4542682')!.result, '2–3');
    expect(live.appearance('a-mk-4542682-2690888')!.playerId, '2690888');
    expect(live.appearancesForMatch('mk-4542682'), isNotEmpty);
    expect(
      live.match('mk-4542682')!.events.where((e) => e.isGoal),
      isNotEmpty,
    );
    expect(
      live.match('mk-4542682')!.events.any(
        (e) => e.playerId == '2690888' && e.isGoal && e.assistPlayerId != null,
      ),
      true,
    );
    expect(live.seasonStats('2690888').goals, greaterThan(0));
    expect(live.demoUsers, isEmpty);
    expect(live.communityReviews, isEmpty);
  });

  test('Local match reviews persist separately from legacy scores', () async {
    SharedPreferences.setMockInitialValues({
      'supported_club_id': '3604',
      'local_player_ratings': '{"2690888":8.2}',
    });
    final prefs = await SharedPreferences.getInstance();
    final user = LocalUserState(prefs);
    expect(user.legacyRatings.single.score, 8.2);
    await user.saveReview(
      appearanceId: 'a-demo-gs-fb-2690888',
      genelPuan: 7.5,
      attributes: {'efor': 8, 'pas': 6.5},
      juriNotu: 'Kısa not',
    );
    await user.saveReview(
      appearanceId: 'a-demo-gs-fb-2690888',
      genelPuan: 8,
      juriNotu: 'Düzenlendi',
    );
    expect(user.reviewFor('a-demo-gs-fb-2690888')!.genelPuan, 8);
    expect(user.reviewFor('a-demo-gs-fb-2690888')!.edited, true);
    expect(user.reviewFor('a-demo-gs-fb-2690888')!.supporterClubId, '3604');
    expect(user.ratings['2690888'], 8.2);
    await user.deleteReview('a-demo-gs-fb-2690888');
    final restored = LocalUserState(prefs);
    expect(restored.reviewFor('a-demo-gs-fb-2690888'), isNull);
    expect(restored.ratings['2690888'], 8.2);
  });
}

void _sourceTests() {
  test('Bundled data loads through the background decode path', () async {
    final source = LocalJsonDataSource();
    final data = await source.load();
    final matchData = await source.loadMatches();
    // The isolate hop must return plain, sendable JSON that still carries the
    // portrait overrides merged in on the worker side.
    expect((data['players'] as List), isNotEmpty);
    expect(
      (data['players'] as List).any((p) => p['photo_asset'] != null),
      true,
    );
    final repo = LocalFootballRepository.fromJson(data, matchData: matchData);
    expect(repo.matches, isNotEmpty);
    expect(repo.matchMeta.provider, isNotEmpty);
  });
}
