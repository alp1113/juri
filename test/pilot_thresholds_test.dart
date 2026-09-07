import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:juri/app/app.dart';
import 'package:juri/data/local_state.dart';
import 'package:juri/data/match_models.dart';
import 'package:juri/data/repository.dart';
import 'package:juri/data/thresholds.dart';
import 'package:juri/l10n/strings.dart';

LocalFootballRepository realRepo() => LocalFootballRepository.fromJson(
  jsonDecode(File('data/app.json').readAsStringSync()),
  matchData: jsonDecode(File('data/matches.json').readAsStringSync()),
);

/// Gives every rateable appearance exactly [Thresholds.publish] ratings: the
/// smallest crowd the app promises to publish, and the one a pilot actually
/// produces. Mirrors what `RemoteTakes.refresh` does with the server's rows.
void seedSmallestPublishableCrowd(LocalFootballRepository repo) {
  repo.adoptCommunityReviews([
    for (final a in repo.appearances)
      if (a.reviewPermitted)
        for (var i = 0; i < Thresholds.publish; i++)
          MatchReview(
            id: '${a.id}-$i',
            userId: 'u$i',
            appearanceId: a.id,
            genelPuan: 6 + (i % 3),
            supporterClubId: a.clubId,
            createdAt: DateTime(2026, 1, 1),
          ),
  ]);
}

/// The pilot ships with [Thresholds.pilot] on, so the aggregator has to read
/// the thresholds rather than keep its own copies of the numbers. A score that
/// says it is published but has no mean is what took the rankings tab down:
/// every ranking path reads `.mean!` off a score it has checked `published` on.
void main() {
  test('a crowd at the publish threshold is scored, not merely published', () {
    final repo = realRepo();
    seedSmallestPublishableCrowd(repo);
    for (final player in repo.players) {
      final season = repo.seasonScores(player.id);
      for (final score in [season.genel, ...season.genelAttributes.values]) {
        if (score.published) {
          expect(score.mean, isNotNull, reason: 'genel ${player.id}');
        }
      }
      for (final spell in season.clubSpells) {
        for (final score in [spell.overall, ...spell.attributes.values]) {
          if (score.published) {
            expect(score.mean, isNotNull, reason: 'spell ${player.id}');
          }
        }
      }
    }
    // Both of these sort on `.mean!` and run before the tab paints anything.
    expect(repo.leaderboard(), isNotNull);
    for (final club in repo.clubs) {
      expect(repo.leaderboard(clubId: club.id), isNotNull);
    }
  });

  testWidgets('the rankings tab paints a board built by a pilot-sized crowd', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = realRepo();
    seedSmallestPublishableCrowd(repo);
    SharedPreferences.setMockInitialValues({'supported_club_id': '3604'});
    final user = LocalUserState(await SharedPreferences.getInstance());
    await tester.pumpWidget(JuriApp(repository: repo, user: user));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Tr.t('rankings')).last);
    await tester.pumpAndSettle();
    // The screen used to be replaced wholesale by the release error widget.
    expect(tester.takeException(), isNull);
    expect(find.byType(ErrorWidget), findsNothing);
  });

  testWidgets('the community caption quotes the bar this build actually uses', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'supported_club_id': '3604'});
    final user = LocalUserState(await SharedPreferences.getInstance());
    final repo = realRepo();
    // The caption sits above the reader's own board, so give them one rating.
    final mine = repo.appearances.firstWhere((a) => a.reviewPermitted);
    await user.saveReview(appearanceId: mine.id, genelPuan: 7);
    await tester.pumpWidget(JuriApp(repository: repo, user: user));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Tr.t('rankings')).last);
    await tester.pumpAndSettle();
    // Telling a pilot tester they need five ratings when the build publishes
    // at two is how the demo looks broken to the people trying it.
    expect(
      find.textContaining('en az ${Thresholds.publish} değerlendirme'),
      findsOneWidget,
    );
    expect(find.textContaining('{n}'), findsNothing);
  });
}
