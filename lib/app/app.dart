import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../data/accounts.dart';
import '../data/local_state.dart';
import '../data/remote_takes.dart';
import '../data/repository.dart';
import '../l10n/strings.dart';
import '../shared/widgets.dart';
import '../features/auth.dart';
import '../features/onboarding.dart';
import 'navigation.dart';
import 'scope.dart';

class JuriApp extends StatefulWidget {
  final FootballRepository? repository;
  final LocalUserState? user;

  /// Null runs the app exactly as it ran before there was a server: local
  /// ratings, no accounts, no other supporters. Every widget test builds it
  /// this way, and so does a build with no Supabase configuration.
  final SupabaseClient? client;
  const JuriApp({super.key, this.repository, this.user, this.client});
  @override
  State<JuriApp> createState() => _JuriAppState();
}

class _JuriAppState extends State<JuriApp> {
  FootballRepository? repository;
  LocalUserState? user;
  SupabaseAccounts? accounts;
  RemoteTakes? remote;
  bool error = false;
  String? syncedProfileId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    accounts?.removeListener(_onAccountChanged);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => error = false);
    try {
      final repo = widget.repository ?? await LocalFootballRepository.load();
      final state =
          widget.user ?? LocalUserState(await SharedPreferences.getInstance());
      if (!mounted) return;
      final client = widget.client;
      setState(() {
        repository = repo;
        user = state;
        if (client != null) {
          accounts = SupabaseAccounts(client)..addListener(_onAccountChanged);
          remote = RemoteTakes(client: client, football: repo);
        }
      });
      _onAccountChanged();
    } catch (_) {
      if (mounted) setState(() => error = true);
    }
  }

  /// Brings the device into line with the account.
  ///
  /// The server is authoritative for who you support, because that is what its
  /// policies check when you try to say something. Ratings are reconciled both
  /// ways by [_sync].
  void _onAccountChanged() {
    final gateway = accounts;
    final state = user;
    if (gateway == null || state == null) return;
    final profile = gateway.profile;
    if (profile == null) {
      syncedProfileId = null;
      remote?.clear();
      return;
    }
    if (profile.clubId != null && profile.clubId != state.clubId) {
      state.changeClub(profile.clubId!).catchError((_) {});
    }
    if (syncedProfileId == profile.id) return;
    syncedProfileId = profile.id;
    unawaited(_sync(state, profile));
  }

  /// Reconciles the device with the account, in that order: down, then up.
  ///
  /// Pulling first is the whole point. A device signing in for the first time
  /// holds nothing — a new browser, a reinstall, or the same phone's
  /// home-screen app, which iOS gives storage entirely separate from Safari's
  /// — while the account holds everything. Pushing without pulling leaves that
  /// reader staring at an empty profile and concluding their ratings are gone.
  ///
  /// Then push, because the reverse case is just as real: someone who rated
  /// matches before signing in must not lose them.
  Future<void> _sync(LocalUserState state, SupporterProfile profile) async {
    final server = remote;
    if (server == null) return;
    try {
      await state.importReviews(await server.fetchMine());
    } catch (_) {
      // No signal, or the rows would not parse. The device keeps what it has;
      // the next sign-in tries again.
    }
    if (profile.clubId != null) {
      try {
        await server.publishAll(state.matchReviews.values);
      } catch (_) {}
    }
    try {
      await server.refresh();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      title: 'Jüri',
      debugShowCheckedModeBanner: false,
      theme: JuriTheme.theme,
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // The layout is typographic and dense; honour the reader's text size
      // setting but cap the multiplier so headline blocks and score cards
      // stay inside their containers instead of overflowing.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 1,
        maxScaleFactor: 1.35,
        child: child ?? const SizedBox.shrink(),
      ),
      home: repository == null
          ? Scaffold(body: Center(child: error ? _retry() : const _Splash()))
          : ListenableBuilder(
              // remote belongs here too: a refresh that lands community scores
              // or other supporters' takes has to repaint the screen showing
              // them, and without this it waited for an unrelated rebuild.
              listenable: Listenable.merge([user!, accounts, remote]),
              builder: (context, _) => _route(),
            ),
    );
    return repository == null
        ? app
        : AppScope(
            repository: repository!,
            user: user!,
            accounts: accounts,
            remote: remote,
            child: app,
          );
  }

  Widget _retry() => EmptyView(
    title: Tr.t('loadError'),
    body: '',
    action: FilledButton(onPressed: _load, child: Text(Tr.t('retry'))),
  );

  Widget _route() {
    final gateway = accounts;
    // No server attached: the app is the local MVP, and a club is the only
    // identity there is.
    if (gateway == null) {
      return user!.clubId == null
          ? const OnboardingScreen()
          : const MainNavigation();
    }
    // Hold the splash while a stored session is being restored, or a signed-in
    // reader would see the login screen flash past on every cold start.
    if (gateway.restoring) return const Scaffold(body: Center(child: _Splash()));
    if (!gateway.signedIn) return const AuthScreen();
    // An account without a club cannot post — the server's own insert policy
    // says so — so picking one is the first thing after signing up.
    if (!gateway.profile!.hasClub) return const OnboardingScreen();
    return const MainNavigation();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text(
        'jüri',
        style: TextStyle(
          fontSize: 72,
          fontWeight: FontWeight.w800,
          letterSpacing: -6,
        ),
      ),
      const SizedBox(height: 18),
      Eyebrow(Tr.t('loading')),
      const SizedBox(height: 24),
      SizedBox(
        width: 100,
        child: LinearProgressIndicator(
          color: JuriTheme.gold,
          backgroundColor: JuriTheme.surface,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    ],
  );
}
