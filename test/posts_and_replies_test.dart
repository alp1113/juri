import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:juri/app/app.dart';
import 'package:juri/data/feed_models.dart';
import 'package:juri/data/local_state.dart';
import 'package:juri/data/repository.dart';
import 'package:juri/l10n/strings.dart';

LocalFootballRepository realRepo() => LocalFootballRepository.fromJson(
  jsonDecode(File('data/app.json').readAsStringSync()),
  matchData: jsonDecode(File('data/matches.json').readAsStringSync()),
);

Reply reply(
  String id, {
  String? parent,
  String review = 'r1',
  int depth = 0,
  int likes = 0,
  int dislikes = 0,
  int mine = 0,
}) => Reply(
  id: id,
  reviewId: review,
  parentId: parent,
  authorId: 'u-$id',
  authorClubId: '3604',
  body: 'body $id',
  depth: depth,
  likeCount: likes,
  dislikeCount: dislikes,
  myVote: mine,
  createdAt: DateTime.utc(2026, 9, 8, 12, id.length, id.codeUnitAt(id.length - 1)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Layout tests measure text, so they need the real faces: the fallback test
  // font has different metrics and reports overflows the app never has.
  setUpAll(() async {
    for (final font in {
      'Manrope': 'assets/fonts/Manrope.ttf',
      'BarlowCondensed': 'assets/fonts/BarlowCondensed-Bold.ttf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  group('thread ordering', () {
    test('a reply always follows the one it answers', () {
      final ordered = threadOrder([
        reply('c', parent: 'a', depth: 1),
        reply('a'),
        reply('b'),
        reply('d', parent: 'c', depth: 2),
      ]);
      final ids = [for (final r in ordered) r.id];
      expect(ids.indexOf('c'), ids.indexOf('a') + 1);
      expect(ids.indexOf('d'), ids.indexOf('c') + 1);
      expect(ids.indexOf('b'), greaterThan(ids.indexOf('d')));
    });

    test('an answer to a reply that is gone surfaces instead of vanishing', () {
      // Moderation can hide one row out from under another. Losing somebody
      // else's words to that is worse than a stray indent.
      final ordered = threadOrder([reply('a'), reply('z', parent: 'missing', depth: 1)]);
      expect(ordered.map((r) => r.id), containsAll(['a', 'z']));
      expect(ordered.length, 2);
    });

    test('every reply appears exactly once', () {
      final ordered = threadOrder([
        reply('a'),
        reply('b', parent: 'a', depth: 1),
        reply('c', parent: 'a', depth: 1),
        reply('d', parent: 'b', depth: 2),
      ]);
      expect(ordered.length, 4);
      expect({for (final r in ordered) r.id}.length, 4);
    });
  });

  group('votes', () {
    test('a take carries both directions and how this reader voted', () {
      final take = Take.fromRow({
        'id': 'r1',
        'user_id': 'u1',
        'appearance_id': 'a1',
        'match_id': 'm1',
        'player_id': 'p1',
        'club_id': '3604',
        'supporter_club_id': '3592',
        'genel_puan': 7.5,
        'body': 'iyiydi',
        'like_count': 14,
        'dislike_count': 9,
        'reply_count': 4,
        'created_at': '2026-09-06T18:00:00Z',
        'edited_at': null,
        'profiles': {'username': 'deniz_1903'},
      }, currentUserId: 'u2', myVotes: {'r1': -1});
      expect(take.likeCount, 14);
      expect(take.dislikeCount, 9);
      expect(take.replyCount, 4);
      expect(take.dislikedByMe, isTrue);
      expect(take.likedByMe, isFalse);
    });

    test('a buried take sinks below a quiet one in the feed ranking', () {
      Take at({required int likes, required int dislikes}) => Take(
        id: 'x$likes$dislikes',
        authorId: 'u',
        authorClubId: '3604',
        appearanceId: 'a',
        playerId: 'p',
        matchId: 'm',
        clubId: '3604',
        body: 'b',
        score: 7,
        createdAt: DateTime.utc(2026, 9, 8),
        likeCount: likes,
        dislikeCount: dislikes,
      );
      final buried = TakeItem(at(likes: 10, dislikes: 30));
      final quiet = TakeItem(at(likes: 0, dislikes: 0));
      expect(buried.weight, lessThan(quiet.weight));
    });
  });

  testWidgets('the Sözler tab shows written takes and nothing else', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = realRepo();
    SharedPreferences.setMockInitialValues({'supported_club_id': '3604'});
    final user = LocalUserState(await SharedPreferences.getInstance());
    final appearance = repo
        .appearancesForPlayer('2690888')
        .firstWhere((a) => a.reviewPermitted);
    await user.saveReview(
      appearanceId: appearance.id,
      genelPuan: 8.5,
      juriNotu: 'Maçın adamıydı.',
    );

    await tester.pumpWidget(JuriApp(repository: repo, user: user));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Tr.t('posts')).last);
    await tester.pumpAndSettle();

    expect(find.text('Maçın adamıydı.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every tab still renders now that there are six', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'supported_club_id': '3604'});
    final user = LocalUserState(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: JuriApp(repository: realRepo(), user: user),
      ),
    );
    await tester.pumpAndSettle();
    for (final tab in [
      Tr.t('posts'),
      Tr.t('clubs'),
      Tr.t('rankings'),
      Tr.t('games'),
      Tr.t('profile'),
      Tr.t('home'),
    ]) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'tab $tab overflowed');
    }
  });
}
