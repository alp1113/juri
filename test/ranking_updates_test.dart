import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:juri/app/app.dart';
import 'package:juri/data/local_state.dart';
import 'package:juri/data/repository.dart';
import 'package:juri/l10n/strings.dart';

LocalFootballRepository realRepo() => LocalFootballRepository.fromJson(
  jsonDecode(File('data/app.json').readAsStringSync()),
  matchData: jsonDecode(File('data/matches.json').readAsStringSync()),
);

void main() {
  /// The community board is rebuilt only when `adoptCommunityReviews` runs,
  /// and that happens inside a community refresh. Rating a player used to push
  /// to the server without pulling back, so the table stayed frozen until the
  /// next sign-in. See `AppScope._publishAndRecount`.
  testWidgets('board picks up a rating saved while the tab is open', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = realRepo();
    SharedPreferences.setMockInitialValues({'supported_club_id': '3604'});
    final user = LocalUserState(await SharedPreferences.getInstance());
    final first = repo.appearancesForPlayer('2690888').firstWhere((a) => a.reviewPermitted);
    await user.saveReview(appearanceId: first.id, genelPuan: 8.5);

    await tester.pumpWidget(JuriApp(repository: repo, user: user));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Tr.t('rankings')).last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rank-2690888')), findsOneWidget);

    // Now rate a SECOND player while the rankings tab is the visible one.
    final other = repo.players.firstWhere((p) =>
        p.id != '2690888' &&
        repo.appearancesForPlayer(p.id).any((a) => a.reviewPermitted));
    final second = repo.appearancesForPlayer(other.id).firstWhere((a) => a.reviewPermitted);
    await user.saveReview(appearanceId: second.id, genelPuan: 9.0);
    await tester.pumpAndSettle();

    expect(find.byKey(Key('rank-${other.id}')), findsOneWidget,
        reason: 'a rating saved while the board is open should appear on it');
  });
}
