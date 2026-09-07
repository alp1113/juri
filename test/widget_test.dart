import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:juri/app/app.dart';
import 'package:juri/data/repository.dart';
import 'package:juri/data/local_state.dart';
import 'package:juri/features/matches.dart';
import 'package:juri/features/performance.dart';
import 'package:juri/features/games.dart';
import 'package:juri/l10n/strings.dart';

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
  testWidgets('Onboard, rate a match appearance, search, play, and inspect profile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final user = LocalUserState(await SharedPreferences.getInstance());
    final repo = LocalFootballRepository.fromJson(
      jsonDecode(File('data/app.json').readAsStringSync()),
      matchData: jsonDecode(File('data/matches.json').readAsStringSync()),
    );
    await tester.pumpWidget(JuriApp(repository: repo, user: user));
    await tester.pumpAndSettle();
    expect(find.text(Tr.t('welcomeTitle')), findsOneWidget);
    await tester.tap(find.text('Galatasaray').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('joinClub')));
    await tester.pumpAndSettle();
    expect(user.clubId, '3604');
    expect(find.text(Tr.t('leagueVoice')), findsOneWidget);
    expect(find.textContaining('2–3'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byKey(const Key('homeMatch-mk-4542682')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('homeMatch-mk-4542682')));
    await tester.pumpAndSettle();
    expect(find.byType(MatchScreen), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('appearance-a-mk-4542682-2690888')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.byKey(const Key('appearance-a-mk-4542682-2690888')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('appearance-a-mk-4542682-2690888')));
    await tester.pumpAndSettle();
    expect(find.byType(PerformanceScreen), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('rateAppearance')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('rateAppearance')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('genelPlus')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveReview')));
    await tester.pumpAndSettle();
    expect(user.reviewFor('a-mk-4542682-2690888'), isNotNull);
    expect(user.ratings['2690888'], isNull);
    expect(find.textContaining('bu cihazda kaydedildi'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(Tr.t('rankings')).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('playerSearch')), 'abdulkerim');
    await tester.pumpAndSettle();
    expect(find.text('Abdülkerim Bardakcı'), findsOneWidget);
    await tester.tap(find.text(Tr.t('games')).last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('startGame')));
    await tester.tap(find.byKey(const Key('startGame')));
    await tester.pumpAndSettle();
    expect(find.byType(ValueGameScreen), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('higher')));
    await tester.tap(find.byKey(const Key('higher')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nextRound')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Tr.t('profile')).last);
    await tester.pumpAndSettle();
    expect(find.text(Tr.t('profileTitle')), findsOneWidget);
    expect(find.text('Victor Osimhen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
