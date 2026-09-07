import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/accounts.dart';
import '../data/feed.dart';
import '../data/local_state.dart';
import '../data/match_models.dart';
import '../data/remote_takes.dart';
import '../data/repository.dart';

class AppScope extends InheritedNotifier<LocalUserState> {
  final FootballRepository repository;

  /// The feed boundary, built over the same sources every screen uses.
  final FeedRepository feed;

  /// Null when the app is running without a server — which is how every data
  /// test builds it, and how the app behaved before there was one.
  final AccountGateway? accounts;
  final RemoteTakes? remote;

  AppScope({
    super.key,
    required this.repository,
    required LocalUserState user,
    required super.child,
    this.accounts,
    this.remote,
  }) : feed = LocalFeedRepository(
         football: repository,
         user: user,
         remoteTakes: remote == null ? null : () => remote.takes,
       ),
       super(notifier: user);

  LocalUserState get user => notifier!;
  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  void tick() {
    if (user.haptics) HapticFeedback.selectionClick();
  }

  /// Saves a rating on the device, then mirrors it to the server.
  ///
  /// The local write is awaited and the push is not: a supporter rating a
  /// match on the metro sees the score land immediately, and the take reaches
  /// everyone else when there is signal. A failed push leaves the review on
  /// the phone, where the next sign-in sweep will pick it up.
  Future<void> saveAndPublish({
    required String appearanceId,
    required double genelPuan,
    Map<String, double> attributes = const {},
    String? juriNotu,
  }) async {
    final review = await user.saveReview(
      appearanceId: appearanceId,
      genelPuan: genelPuan,
      attributes: attributes,
      juriNotu: juriNotu,
    );
    unawaited(_publishAndRecount(review));
  }

  /// Pushes the rating, then pulls the community back down.
  ///
  /// The reader's own rating counts toward the community score, but the
  /// aggregator only ever sees rows that came from the server: pushing without
  /// pulling left the rankings frozen until the next sign-in, which is exactly
  /// what a pilot crowd notices first. The refresh is what clears the
  /// repository's season and leaderboard caches.
  Future<void> _publishAndRecount(MatchReview review) async {
    final server = remote;
    if (server == null) return;
    await server.publish(review);
    await server.refresh();
  }
}

/// Deliberately fire-and-forget. Named so that reads as a decision rather than
/// a missing await.
void unawaited(Future<void>? future) {
  future?.catchError((_) {});
}
