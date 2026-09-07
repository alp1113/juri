import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:juri/app/app.dart';
import 'package:juri/data/local_state.dart';
import 'package:juri/data/match_models.dart';
import 'package:juri/data/repository.dart';
import 'package:juri/data/stat_boards.dart';
import 'package:juri/app/scope.dart';
import 'package:juri/core/theme.dart';
import 'package:juri/features/statistics.dart';
import 'package:juri/features/clubs.dart';
import 'package:juri/features/matches.dart';
import 'package:juri/features/players.dart';
import 'package:juri/l10n/strings.dart';
import 'package:juri/shared/widgets.dart';

LocalFootballRepository realRepo() => LocalFootballRepository.fromJson(
  jsonDecode(File('data/app.json').readAsStringSync()),
  matchData: jsonDecode(File('data/matches.json').readAsStringSync()),
);

Future<LocalUserState> onboarded(WidgetTester tester, {String club = '3604'}) async {
  SharedPreferences.setMockInitialValues({'supported_club_id': club});
  return LocalUserState(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in {
      'Manrope': 'assets/fonts/Manrope.ttf',
      'BarlowCondensed': 'assets/fonts/BarlowCondensed-Bold.ttf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  testWidgets('Every tab renders without layout errors at the largest supported text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final user = await onboarded(tester);
    await tester.pumpWidget(
      MediaQuery(
        // Above the app's own clamp, so the clamp itself is under test.
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: JuriApp(repository: realRepo(), user: user),
      ),
    );
    await tester.pumpAndSettle();
    for (final tab in [
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

  testWidgets('Statistics opens from the rankings tab and every board renders', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = realRepo();
    final user = await onboarded(tester);
    await tester.pumpWidget(JuriApp(repository: repo, user: user));
    await tester.pumpAndSettle();

    final entry = find.byKey(const Key('openStatistics'));
    // It used to sit at the bottom of the feed, under the league table, where
    // readers scrolled straight past it. It belongs to the rankings tab now.
    expect(entry, findsNothing, reason: 'still on the feed');
    await tester.tap(find.text(Tr.t('rankings')).last);
    await tester.pumpAndSettle();
    expect(entry, findsOneWidget);
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.text(Tr.t('statistics')), findsWidgets);

    // Walk the whole page: a board that overflows or throws on the way past
    // is a board the reader would have hit.
    for (var i = 0; i < 40; i++) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'statistics scroll $i');
    }
    // The source note closes the page, so reaching it proves the walk covered
    // every board above it.
    expect(find.text(Tr.t('statsSource')), findsOneWidget);
  });

  testWidgets('Rated boards appear beside the counted ones once ratings exist', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = realRepo();
    final user = await onboarded(tester);

    // Rate one outfielder and one keeper, so both templates have a board.
    final outfield = repo.appearances.firstWhere(
      (a) => a.reviewPermitted && a.templateId == 'outfield.v1',
    );
    final keeper = repo.appearances.firstWhere(
      (a) => a.reviewPermitted && a.templateId == 'goalkeeper.v1',
    );
    await user.saveReview(
      appearanceId: outfield.id,
      genelPuan: 8,
      attributes: const {'pas': 9, 'ikili_mucadele': 7, 'efor': 8},
    );
    await user.saveReview(
      appearanceId: keeper.id,
      genelPuan: 7,
      attributes: const {'sut_kurtarma': 9, 'pas': 6},
    );

    await tester.pumpWidget(
      AppScope(
        repository: repo,
        user: user,
        child: MaterialApp(
          theme: JuriTheme.theme,
          home: const StatisticsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The empty-state prompt gives way to real boards.
    expect(find.text(Tr.t('opinionEmptyBody')), findsNothing);
    final passing = find.byKey(const Key('opinion-outfield.v1:pas'));
    await tester.scrollUntilVisible(
      passing,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(passing, findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('opinion-goalkeeper.v1:sut_kurtarma')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    // The keeper's own passing score stays out of the outfield passing board.
    final outfieldPas = OpinionBoards.all.firstWhere(
      (d) => d.id == 'outfield.v1:pas',
    );
    final board = repo.opinionBoard(
      outfieldPas,
      localReviews: user.matchReviews.values,
    );
    expect(board.rows.length, 1);
    expect(board.rows.first.player.id, outfield.playerId);

    await tester.scrollUntilVisible(
      passing,
      -300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(passing);
    await tester.pumpAndSettle();
    await tester.tap(passing);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(Tr.t('opinionPersonal')), findsOneWidget);
  });

  testWidgets('A full board keeps tied ranks and opens the player behind a row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = realRepo();
    final user = await onboarded(tester);
    // AppScope sits above the navigator in the real app, so pushed routes can
    // still read it. Mirror that here or the player page loses the scope.
    await tester.pumpWidget(
      AppScope(
        repository: repo,
        user: user,
        child: MaterialApp(
          theme: JuriTheme.theme,
          home: const StatBoardScreen(def: StatBoards.assists),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final board = repo.statBoard(StatBoards.assists);
    // Everyone level on assists shares first place rather than being ordered
    // by an accident of the sort.
    final tied = board.rows.where((r) => r.rank == 1).toList();
    expect(tied.length, greaterThan(1));
    expect(find.text('01'), findsNWidgets(tied.length));

    final first = find.byKey(Key('stat-assists-${tied.first.player.id}'));
    await tester.ensureVisible(first);
    await tester.pumpAndSettle();
    await tester.tap(first);
    await tester.pumpAndSettle();
    expect(find.byType(PlayerScreen), findsOneWidget);
    expect(
      find.text(tied.first.player.name.replaceFirst(' ', '\n').toUpperCase()),
      findsOneWidget,
    );
  });

  testWidgets('Detail screens survive the largest supported text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = realRepo();
    final user = await onboarded(tester);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: JuriApp(repository: repo, user: user),
      ),
    );
    await tester.pumpAndSettle();

    // Fixture card -> match -> a confirmed appearance -> the rating form.
    await tester.scrollUntilVisible(
      find.byKey(const Key('homeMatch-mk-4542682')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('homeMatch-mk-4542682')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'match screen');
    // The sheet opens on the reader's own club, so pick from that side.
    final appearance = repo
        .appearancesForMatch('mk-4542682')
        .firstWhere((a) => a.reviewPermitted && a.clubId == '3604');
    await tester.scrollUntilVisible(
      find.byKey(Key('appearance-${appearance.id}')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.byKey(Key('appearance-${appearance.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('appearance-${appearance.id}')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'performance screen');
    await tester.scrollUntilVisible(
      find.byKey(const Key('rateAppearance')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('rateAppearance')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'rating screen');

    // The attribute board is the densest layout in the app.
    await tester.tap(find.text(Tr.t('analyzePlayer')).last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'attribute steppers');
  });

  testWidgets('A saved rating stays editable instead of freezing the form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = realRepo();
    final user = await onboarded(tester);
    final appearance = repo
        .appearancesForPlayer('2690888')
        .firstWhere((a) => a.reviewPermitted);
    await tester.pumpWidget(JuriApp(repository: repo, user: user));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('homeMatch-mk-4542682')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('homeMatch-mk-4542682')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(Key('appearance-${appearance.id}')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.byKey(Key('appearance-${appearance.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('appearance-${appearance.id}')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('rateAppearance')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('rateAppearance')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('genelPlus')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveReview')));
    await tester.pumpAndSettle();
    final first = user.reviewFor(appearance.id)!.genelPuan;
    // Correcting a slip must not require leaving and re-entering the screen.
    await tester.tap(find.byKey(const Key('genelPlus')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveReview')));
    await tester.pumpAndSettle();
    expect(user.reviewFor(appearance.id)!.genelPuan, greaterThan(first));
    expect(find.byKey(const Key('closeRating')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Match screen separates confirmed play from an unconfirmed bench', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = realRepo();
    final user = await onboarded(tester);
    await tester.pumpWidget(JuriApp(repository: repo, user: user));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('homeMatch-mk-4542682')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('homeMatch-mk-4542682')));
    await tester.pumpAndSettle();
    expect(find.byType(MatchScreen), findsOneWidget);
    // Both sides are reachable, and the sheet is split by team rather than
    // being one undifferentiated list.
    expect(find.text(Tr.t('lineup')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(Tr.t('startingXI')),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text(Tr.t('startingXI')), findsOneWidget);
    final repo2 = realRepo();
    final selected = repo2
        .appearancesForMatch('mk-4542682')
        .where((a) => a.clubId == '3604' && a.role == AppearanceRole.starter);
    // Only the shown team's players are on screen.
    expect(selected, isNotEmpty);
    expect(
      find.byKey(Key('appearance-${selected.first.id}')),
      findsOneWidget,
    );
    final other = repo2
        .appearancesForMatch('mk-4542682')
        .firstWhere((a) => a.clubId != '3604');
    expect(find.byKey(Key('appearance-${other.id}')), findsNothing);
    // Switching sides swaps the sheet.
    await tester.tap(find.text(repo2.club(other.clubId).shortName).last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(Key('appearance-${other.id}')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.byKey(Key('appearance-${other.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('appearance-${other.id}')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Rankings fall back to the reader own scores when no community exists', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = realRepo();
    final user = await onboarded(tester);
    final appearance = repo
        .appearancesForPlayer('2690888')
        .firstWhere((a) => a.reviewPermitted);
    await user.saveReview(appearanceId: appearance.id, genelPuan: 8.5);
    await tester.pumpWidget(JuriApp(repository: repo, user: user));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Tr.t('rankings')).last);
    await tester.pumpAndSettle();
    expect(find.text(Tr.t('personalTitle')), findsOneWidget);
    expect(find.byKey(const Key('rank-2690888')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Review history with two ratings for one player pushes cleanly', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = realRepo();
    final user = await onboarded(tester);
    // Two appearances by the same player once shared one hero tag, which threw
    // as soon as the list pushed a route.
    final apps = repo
        .appearancesForPlayer('2690888')
        .where((a) => a.reviewPermitted)
        .take(2)
        .toList();
    expect(apps.length, 2);
    for (final a in apps) {
      await user.saveReview(appearanceId: a.id, genelPuan: 7);
    }
    await tester.pumpWidget(JuriApp(repository: repo, user: user));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Tr.t('profile')).last);
    await tester.pumpAndSettle();
    expect(find.byKey(Key('history-${apps.first.id}')), findsOneWidget);
    await tester.tap(find.byKey(Key('history-${apps.first.id}')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('A club badge is a link to that club from anywhere', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = realRepo();
    final user = await onboarded(tester);
    await tester.pumpWidget(JuriApp(repository: repo, user: user));
    await tester.pumpAndSettle();
    // From the home header.
    await tester.tap(find.byType(ClubBadge).first);
    await tester.pumpAndSettle();
    expect(tester.widget<ClubScreen>(find.byType(ClubScreen)).club.id, '3604');
    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();
    // And from a match scoreboard, where the badge belongs to the opponent.
    await tester.scrollUntilVisible(
      find.byKey(const Key('homeMatch-mk-4542682')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('homeMatch-mk-4542682')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ClubBadge).first);
    await tester.pumpAndSettle();
    // The scoreboard's first badge is the host, not the reader's own club.
    expect(tester.widget<ClubScreen>(find.byType(ClubScreen)).club.id, '3665');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Badges that mean something else do not navigate', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final user = LocalUserState(await SharedPreferences.getInstance());
    await tester.pumpWidget(JuriApp(repository: realRepo(), user: user));
    await tester.pumpAndSettle();
    // In onboarding a badge selects a club; it must not open its page.
    await tester.tap(find.byType(ClubBadge).first);
    await tester.pumpAndSettle();
    expect(find.byType(ClubScreen), findsNothing);
    await tester.tap(find.byKey(const Key('joinClub')));
    await tester.pumpAndSettle();
    expect(user.clubId, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Supporter identity can be corrected and local data cleared', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final user = await onboarded(tester);
    await tester.pumpWidget(JuriApp(repository: realRepo(), user: user));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Tr.t('profile')).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('changeClub')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beşiktaş').last);
    await tester.pumpAndSettle();
    expect(user.clubId, '3590');
    await tester.scrollUntilVisible(
      find.byKey(const Key('clearData')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('clearData')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Tr.t('clearDataConfirm')));
    await tester.pumpAndSettle();
    expect(user.clubId, isNull);
    // Clearing identity returns the reader to onboarding rather than a blank tab.
    expect(find.text(Tr.t('welcomeTitle')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Player profile shows identity fields the dataset always carried', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = realRepo();
    final user = await onboarded(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => JuriApp(repository: repo, user: user),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(Tr.t('clubs')).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Galatasaray').first);
    await tester.pumpAndSettle();
    expect(find.byType(ClubScreen), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('squad-2690888')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('squad-2690888')));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerScreen), findsOneWidget);
    expect(find.text(Tr.t('nationality').toUpperCase()), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
