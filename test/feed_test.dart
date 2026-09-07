import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:juri/app/app.dart';
import 'package:juri/app/scope.dart';
import 'package:juri/core/theme.dart';
import 'package:juri/data/feed.dart';
import 'package:juri/data/feed_models.dart';
import 'package:juri/data/local_state.dart';
import 'package:juri/data/match_models.dart';
import 'package:juri/data/moments.dart';
import 'package:juri/data/aggregation.dart';
import 'package:juri/data/repository.dart';
import 'package:juri/data/thresholds.dart';
import 'package:juri/features/take.dart';
import 'package:juri/l10n/strings.dart';

LocalFootballRepository realRepo() => LocalFootballRepository.fromJson(
  jsonDecode(File('data/app.json').readAsStringSync()),
  matchData: jsonDecode(File('data/matches.json').readAsStringSync()),
);

Map<String, dynamic> rawMatches() =>
    jsonDecode(File('data/matches.json').readAsStringSync())
        as Map<String, dynamic>;

Future<LocalUserState> onboarded({String club = '3604'}) async {
  SharedPreferences.setMockInitialValues({'supported_club_id': club});
  return LocalUserState(await SharedPreferences.getInstance());
}

LocalFeedRepository feedFor(LocalFootballRepository repo, LocalUserState user) =>
    LocalFeedRepository(football: repo, user: user);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _thresholdGuards();
  _communityScoreTests();

  test('Every moment restates something the fixture file actually published', () {
    final repo = realRepo();
    final moments = feedFor(repo, LocalUserState(_FakePrefs())).moments;
    expect(moments, isNotEmpty);
    for (final moment in moments) {
      final match = repo.match(moment.matchId);
      expect(match, isNotNull, reason: '${moment.id} has no fixture');
      expect(match!.status, MatchStatus.finished);
      if (moment.playerId != null) {
        expect(
          repo.player(moment.playerId!),
          isNotNull,
          reason: '${moment.id} names a player the squad data does not carry',
        );
      }
    }
  });

  test('Hat-tricks and red cards match a direct count over the raw file', () {
    final repo = realRepo();
    final moments = feedFor(repo, LocalUserState(_FakePrefs())).moments;
    final raw = rawMatches()['matches'] as List;
    final expectedHatTricks = <String>{};
    final expectedReds = <String>{};
    for (final m in raw.cast<Map<String, dynamic>>()) {
      if (m['status'] != 'finished') continue;
      final goals = <String, int>{};
      for (final e in (m['events'] as List).cast<Map<String, dynamic>>()) {
        if (e['type'] == 'goal') {
          goals['${e['playerId']}'] = (goals['${e['playerId']}'] ?? 0) + 1;
        }
        if (e['type'] == 'red') expectedReds.add('${m['id']}|${e['playerId']}');
      }
      goals.forEach((id, count) {
        if (count >= 3) expectedHatTricks.add('${m['id']}|$id');
      });
    }
    String key(LeagueMoment m) => '${m.matchId}|${m.playerId}';
    expect(
      moments.where((m) => m.kind == MomentKind.hatTrick).map(key).toSet(),
      expectedHatTricks,
    );
    // A red card is the loudest thing that happens to one player, so the
    // per-match cap must never drop one.
    expect(
      moments.where((m) => m.kind == MomentKind.redCard).map(key).toSet(),
      expectedReds,
    );
  });

  test('A fixture whose events do not add up gets no running-score moment', () {
    final repo = realRepo();
    final moments = feedFor(repo, LocalUserState(_FakePrefs())).moments;
    // Four of the scraped fixtures publish fewer goal events than their own
    // scoreline. Replaying those events would invent a match, so comeback and
    // late-winner moments must not appear for them.
    final incomplete = <String>{};
    for (final match in repo.matches) {
      if (match.status != MatchStatus.finished) continue;
      var home = 0, away = 0;
      for (final e in match.events) {
        if (!e.isGoal && !e.isOwnGoal) continue;
        ((e.clubId == match.homeClubId) != e.isOwnGoal) ? home++ : away++;
      }
      if (home != match.homeGoals || away != match.awayGoals) {
        incomplete.add(match.id);
      }
    }
    expect(incomplete, isNotEmpty, reason: 'fixture gaps are the point here');
    final timeline = moments.where(
      (m) =>
          m.kind == MomentKind.comeback || m.kind == MomentKind.lateWinner,
    );
    for (final moment in timeline) {
      expect(incomplete.contains(moment.matchId), isFalse);
    }
  });

  test('No fixture contributes more than the per-match cap', () {
    final repo = realRepo();
    final counts = <String, int>{};
    for (final moment in feedFor(repo, LocalUserState(_FakePrefs())).moments) {
      counts[moment.matchId] = (counts[moment.matchId] ?? 0) + 1;
    }
    for (final entry in counts.entries) {
      expect(entry.value, lessThanOrEqualTo(MomentFinder.perMatchLimit));
    }
  });

  testWidgets('The feed invents nobody: every take in it is the reader own', (
    tester,
  ) async {
    final repo = realRepo();
    final user = await onboarded();
    final feed = feedFor(repo, user);
    final appearance = repo.appearances.firstWhere((a) => a.reviewPermitted);
    await user.saveReview(
      appearanceId: appearance.id,
      genelPuan: 9,
      juriNotu: 'Ligin en iyisi, tartışmaya kapalı.',
    );
    final items = feed.feed(filter: FeedFilter.league, supporterClubId: '3604');
    final takes = items.whereType<TakeItem>().map((i) => i.take).toList();
    expect(takes, isNotEmpty);
    for (final take in takes) {
      expect(take.mine, isTrue);
      expect(take.published, isFalse);
      expect(take.authorClubId, '3604');
    }
    expect(feed.takesAreLocalOnly, isTrue);
    // A rating without a note is not a take and must not reach the feed.
    final silent = repo.appearances.firstWhere(
      (a) => a.reviewPermitted && a.id != appearance.id,
    );
    await user.saveReview(appearanceId: silent.id, genelPuan: 7);
    expect(
      feed
          .feed(filter: FeedFilter.league, supporterClubId: '3604')
          .whereType<TakeItem>()
          .length,
      takes.length,
    );
  });

  testWidgets('The club filter admits only football the club was part of', (
    tester,
  ) async {
    final repo = realRepo();
    final user = await onboarded();
    final items = feedFor(repo, user).feed(
      filter: FeedFilter.myClub,
      supporterClubId: '3604',
    );
    final content = items.where((i) => i is! EditorialItem).toList();
    expect(content, isNotEmpty);
    for (final item in content) {
      expect(
        item.clubs.contains('3604'),
        isTrue,
        reason: '${item.id} is not about the reader club',
      );
    }
  });

  testWidgets('Two cards about the same player never sit back to back', (
    tester,
  ) async {
    final repo = realRepo();
    final user = await onboarded();
    for (final filter in FeedFilter.values) {
      final items = feedFor(repo, user)
          .feed(filter: filter, supporterClubId: '3604')
          .where((i) => i is! EditorialItem)
          .toList();
      for (var i = 1; i < items.length; i++) {
        if (items[i].subject == null) continue;
        expect(
          items[i].subject == items[i - 1].subject,
          isFalse,
          reason: 'repeat subject at $i under $filter',
        );
      }
    }
  });

  testWidgets('Writing a take from the feed keeps the attribute ratings intact', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = realRepo();
    final user = await onboarded();
    final appearance = repo.appearances.firstWhere(
      (a) => a.reviewPermitted && a.templateId == 'outfield.v1',
    );
    // The composer never asks about attributes, so it must carry through the
    // ones the full rating form already collected instead of wiping them.
    await user.saveReview(
      appearanceId: appearance.id,
      genelPuan: 6,
      attributes: const {'pas': 8},
    );
    await tester.pumpWidget(
      AppScope(
        repository: repo,
        user: user,
        child: MaterialApp(
          theme: JuriTheme.theme,
          home: TakeComposerScreen(appearance: appearance),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('takeBody')),
      'Doksan dakika boyunca oyunu o kurdu.',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveTake')));
    await tester.pumpAndSettle();
    final saved = user.reviewFor(appearance.id)!;
    expect(saved.juriNotu, 'Doksan dakika boyunca oyunu o kurdu.');
    expect(saved.attributes['pas'], 8);
    expect(saved.genelPuan, 6);
  });

  testWidgets('The feed tab renders under every filter and shows a written take', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final font in {
      'Manrope': 'assets/fonts/Manrope.ttf',
      'BarlowCondensed': 'assets/fonts/BarlowCondensed-Bold.ttf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
    final repo = realRepo();
    final user = await onboarded();
    final appearance = repo
        .appearancesForMatch('mk-4542682')
        .firstWhere((a) => a.clubId == '3604' && a.reviewPermitted);
    await user.saveReview(
      appearanceId: appearance.id,
      genelPuan: 8.5,
      juriNotu: 'Bu maçta farkı o yarattı.',
    );
    await tester.pumpWidget(JuriApp(repository: repo, user: user));
    await tester.pumpAndSettle();
    // The feed identifies itself by its eyebrow now; the 54pt headline that
    // used to sit here was most of a phone screen above the first card.
    expect(find.text(Tr.t('leagueVoice')), findsOneWidget);
    for (final filter in FeedFilter.values) {
      await tester.tap(find.byKey(Key('filter-${filter.name}')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'filter ${filter.name}');
    }
    await tester.tap(find.byKey(const Key('filter-myClub')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Bu maçta farkı o yarattı.'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Bu maçta farkı o yarattı.'), findsOneWidget);
    // No server, so the card must not imply the take reached anybody.
    expect(find.text(Tr.t('localPreview')), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Other supporters takes join the feed and keep their author', (
    tester,
  ) async {
    final repo = realRepo();
    final user = await onboarded();
    final appearance = repo.appearances.firstWhere((a) => a.reviewPermitted);
    final other = Take(
      id: 'remote-1',
      authorId: 'someone-else',
      authorClubId: '3592',
      appearanceId: appearance.id,
      playerId: appearance.playerId,
      matchId: appearance.matchId,
      clubId: appearance.clubId,
      body: 'Fenerli gözüyle: adam iyiydi.',
      score: 8,
      createdAt: DateTime.now().toUtc(),
      likeCount: 4,
      authorName: 'baran_07',
      published: true,
    );
    // A take the server echoes back to its own author must not appear twice:
    // local state is authoritative for the reader's own.
    final echoOfMine = Take(
      id: 'remote-2',
      authorId: 'me',
      authorClubId: '3604',
      appearanceId: appearance.id,
      playerId: appearance.playerId,
      matchId: appearance.matchId,
      clubId: appearance.clubId,
      body: 'Bu benim, sunucudan geldi.',
      score: 9,
      createdAt: DateTime.now().toUtc(),
      mine: true,
      published: true,
    );
    final feed = LocalFeedRepository(
      football: repo,
      user: user,
      remoteTakes: () => [other, echoOfMine],
    );
    final takes = feed
        .feed(filter: FeedFilter.league, supporterClubId: '3604')
        .whereType<TakeItem>()
        .map((i) => i.take)
        .toList();
    expect(takes.map((t) => t.id), ['remote-1']);
    expect(takes.first.authorName, 'baran_07');
    expect(takes.first.published, isTrue);
    // With a published take in the feed, the local-only disclaimer must go.
    expect(feed.takesAreLocalOnly, isFalse);
  });

  test('A server row becomes a take with its author and like state', () {
    final take = Take.fromRow({
      'id': 'r1',
      'user_id': 'u1',
      'appearance_id': 'a1',
      'match_id': 'm1',
      'player_id': 'p1',
      'club_id': '3604',
      'supporter_club_id': '3592',
      'genel_puan': 7.5,
      'body': 'İyi maçtı.',
      'like_count': 3,
      'created_at': '2026-09-06T18:00:00Z',
      'edited_at': null,
      'profiles': {'username': 'deniz_1903'},
    }, currentUserId: 'u2', myVotes: {'r1': 1});
    expect(take.authorName, 'deniz_1903');
    expect(take.likedByMe, isTrue);
    expect(take.dislikedByMe, isFalse);
    expect(take.mine, isFalse);
    expect(take.published, isTrue);
    expect(take.score, 7.5);
  });

  testWidgets('Signing in on a fresh device restores ratings from the server', (
    tester,
  ) async {
    final repo = realRepo();
    final user = await onboarded();
    final appearance = repo.appearances.firstWhere((a) => a.reviewPermitted);
    // A device that has never seen this account: the home-screen app iOS gives
    // storage of its own, a new browser, a reinstall.
    expect(user.matchReviews, isEmpty);
    final fromServer = MatchReview(
      id: 'server-1',
      userId: localUserId,
      appearanceId: appearance.id,
      genelPuan: 8.5,
      juriNotu: 'Sunucudan geri geldi.',
      supporterClubId: '3604',
      createdAt: DateTime.utc(2026, 9, 6, 12),
    );
    expect(await user.importReviews([fromServer]), 1);
    expect(user.reviewFor(appearance.id)!.genelPuan, 8.5);
    expect(user.reviewFor(appearance.id)!.juriNotu, 'Sunucudan geri geldi.');
  });

  testWidgets('A rating edited on this device survives the server copy', (
    tester,
  ) async {
    final repo = realRepo();
    final user = await onboarded();
    final appearance = repo.appearances.firstWhere((a) => a.reviewPermitted);
    await user.saveReview(
      appearanceId: appearance.id,
      genelPuan: 9,
      juriNotu: 'Bunu az önce yazdım.',
    );
    // An older row from the server must not overwrite what the reader just
    // typed; the newer of the two wins, and a tie goes to the device.
    final stale = MatchReview(
      id: 'server-1',
      userId: localUserId,
      appearanceId: appearance.id,
      genelPuan: 4,
      juriNotu: 'Eski hâli.',
      supporterClubId: '3604',
      createdAt: DateTime.utc(2020),
    );
    expect(await user.importReviews([stale]), 0);
    expect(user.reviewFor(appearance.id)!.genelPuan, 9);

    // The other direction: a newer edit made elsewhere does land.
    final fresher = MatchReview(
      id: 'server-1',
      userId: localUserId,
      appearanceId: appearance.id,
      genelPuan: 6.5,
      juriNotu: 'Başka cihazda düzelttim.',
      supporterClubId: '3604',
      createdAt: DateTime.utc(2020),
      editedAt: DateTime.now().toUtc().add(const Duration(minutes: 1)),
    );
    expect(await user.importReviews([fresher]), 1);
    expect(user.reviewFor(appearance.id)!.genelPuan, 6.5);
  });
}

/// SharedPreferences stub for the pure-data tests, which need a user object
/// but never write through it.
class _FakePrefs implements SharedPreferences {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

MatchReview _communityReview(
  String appearanceId,
  String userId,
  double score, {
  String club = '3604',
}) => MatchReview(
  id: 'r-$userId',
  userId: userId,
  appearanceId: appearanceId,
  genelPuan: score,
  supporterClubId: club,
  createdAt: DateTime.utc(2026, 9, 6),
);

void _communityScoreTests() {
  test('Ratings from the server become the community score', () {
    final repo = realRepo();
    final appearance = repo.appearances.firstWhere((a) => a.reviewPermitted);

    // Before: the bundled review list is empty, which is why every score in
    // production said "henüz puanlanmadı" however many people had rated.
    expect(repo.appearanceScores(appearance).genel.count, 0);
    expect(repo.appearanceScores(appearance).genel.published, isFalse);

    repo.adoptCommunityReviews([
      for (var i = 0; i < 5; i++)
        _communityReview(appearance.id, 'user-$i', 8 + (i - 2) * 0.5),
    ]);

    // The cached zero must not survive. This is the whole risk of adopting
    // data into a repository whose caches were written on the assumption that
    // community ratings never change.
    final genel = repo.appearanceScores(appearance).genel;
    expect(genel.count, 5, reason: 'stale cache');
    expect(genel.mean, 8.0);
    expect(genel.published, isTrue);
    expect(genel.distribution.reduce((a, b) => a + b), 5);
  });

  test('Real supporter ratings are never captioned as demo content', () {
    final repo = realRepo();
    final appearance = repo.appearances.firstWhere((a) => a.reviewPermitted);
    expect(repo.hasDemoContent, isFalse);
    repo.adoptCommunityReviews([
      _communityReview(appearance.id, 'user-1', 9),
    ]);
    // hasDemoContent means *bundled* mock-up content. Folding server ratings
    // into it would put a DEMO label on the realest data in the app.
    expect(repo.hasDemoContent, isFalse);
  });

  test('The club split separates supporters from the general score', () {
    final repo = realRepo();
    final appearance = repo.appearances.firstWhere(
      (a) => a.reviewPermitted && a.clubId == '3604',
    );
    repo.adoptCommunityReviews([
      for (var i = 0; i < 4; i++)
        _communityReview(appearance.id, 'gs-$i', 9, club: '3604'),
      for (var i = 0; i < 4; i++)
        _communityReview(appearance.id, 'fb-$i', 5, club: '3592'),
    ]);
    final scores = repo.appearanceScores(appearance);
    expect(scores.genel.count, 8);
    expect(scores.genel.mean, 7.0);
    // The player's own club's stand, which is the comparison the whole
    // product exists to make.
    expect(scores.club.count, 4);
    expect(scores.club.mean, 9.0);
  });
}

/// Pilot thresholds are a build flag, not an edited constant, so a release
/// build cannot inherit them by accident. Run with no --dart-define this is
/// exactly what a production build looks like; run with
/// `--dart-define=PILOT_MODE=true` it is what GitHub Pages actually ships.
/// Both have to hold, because the pilot is the build testers see.
void _thresholdGuards() {
  test('Thresholds are whichever set the build flag asked for', () {
    if (Thresholds.pilot) {
      expect(Thresholds.publish, 2);
      expect(Thresholds.seasonMatches, 1);
      expect(Thresholds.rankingMatches, 1);
    } else {
      expect(Thresholds.publish, 5);
      expect(Thresholds.seasonMatches, 3);
      expect(Thresholds.rankingMatches, 5);
    }
  });

  test('A score is withheld until it clears the bar, and flagged after', () {
    final belowBar = PopulationScore(count: Thresholds.publish - 1, mean: 9);
    final atBar = PopulationScore(count: Thresholds.publish, mean: 9);
    const one = PopulationScore(count: 1, mean: 9);
    const many = PopulationScore(count: 25, mean: 9);
    expect(one.published, isFalse);
    expect(belowBar.published, isFalse, reason: 'one short of the bar');
    expect(belowBar.withheld || belowBar.empty, isTrue);
    expect(atBar.published, isTrue);
    // Clearing the bar is not the same as being settled: the low-sample
    // caption stays until the sample is genuinely large.
    expect(atBar.lowSample, isTrue);
    expect(many.lowSample, isFalse);
  });

  test('A published score always carries a mean to publish', () {
    // The aggregator used to keep its own copies of these numbers, so under
    // pilot thresholds a score could report published with no mean — and
    // every ranking path reads `.mean!` off a score it has checked.
    expect(seasonScoreFloor, lessThanOrEqualTo(Thresholds.publish));
  });
}
