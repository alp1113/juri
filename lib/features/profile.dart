import 'package:flutter/material.dart';
import '../app/scope.dart';
import '../core/config.dart';
import '../data/thresholds.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../shared/widgets.dart';
import 'performance.dart';
import 'rating.dart';

class ProfileScreen extends StatelessWidget {
  final VoidCallback onExplore;
  const ProfileScreen({super.key, required this.onExplore});

  Future<void> _changeClub(BuildContext context) async {
    final scope = AppScope.of(context);
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Tr.t('changeClub'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    Tr.t('changeClubBody'),
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: JuriTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final c in scope.repository.clubs)
                    ListTile(
                      leading: ClubBadge(c, size: 30, linked: false),
                      title: Text(c.name),
                      trailing: c.id == scope.user.clubId
                          ? const Icon(Icons.check, color: JuriTheme.gold)
                          : null,
                      onTap: () => Navigator.pop(context, c.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (chosen == null || !context.mounted) return;
    try {
      await AppScope.of(context).user.changeClub(chosen);
    } catch (_) {
      if (context.mounted) showSaveError(context);
    }
  }

  Future<void> _clearData(BuildContext context) async {
    final scope = AppScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(Tr.t('clearData')),
        content: Text(Tr.t('clearDataBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(Tr.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(Tr.t('clearDataConfirm')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await scope.user.clearAll();
    } catch (_) {
      if (context.mounted) showSaveError(context);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final scope = AppScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(Tr.t('signOutConfirm')),
        content: Text(Tr.t('signOutBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(Tr.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(Tr.t('signOut')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await scope.accounts?.signOut();
    } catch (_) {
      if (context.mounted) showSaveError(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final club = scope.repository.club(scope.user.clubId!);
    final reviews = scope.user.reviewHistory;
    final takes = reviews
        .where((r) => (r.juriNotu ?? '').trim().isNotEmpty)
        .length;
    final legacy = scope.user.legacyRatings;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(Tr.t('localMvp'), color: JuriTheme.gold),
                const SizedBox(height: 14),
                Headline(Tr.t('profileTitle'), size: 54),
                const SizedBox(height: 26),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        JuriTheme.clubColor(club.id).withValues(alpha: .19),
                        JuriTheme.surface,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Eyebrow(Tr.t('supporter')),
                          const Spacer(),
                          const Text(
                            'jüri',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      ClubBadge(club, size: 65),
                      const SizedBox(height: 22),
                      Headline(club.name.toUpperCase(), size: 38),
                      if (scope.accounts?.profile != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          scope.accounts!.profile!.username,
                          key: const Key('profileUsername'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: JuriTheme.gold,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              Tr.t('identityLocked'),
                              style: const TextStyle(
                                color: JuriTheme.muted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          TextButton(
                            key: const Key('changeClub'),
                            onPressed: () => _changeClub(context),
                            child: Text(
                              Tr.t('changeClub'),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Headline('${reviews.length}', size: 38),
                                Text(
                                  Tr.t('ratings'),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: JuriTheme.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Headline('$takes', size: 38),
                                Text(
                                  Tr.t('takesHeading'),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: JuriTheme.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Headline('${scope.user.highScore}', size: 38),
                                Text(
                                  Tr.t('record'),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: JuriTheme.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SectionHeading(Tr.t('ratings')),
              ],
            ),
          ),
        ),
        if (reviews.isEmpty)
          SliverToBoxAdapter(
            child: EmptyView(
              title: Tr.t('noRatings'),
              body: Tr.t('noRatingsBody'),
              action: FilledButton(
                onPressed: onExplore,
                child: Text(Tr.t('explorePlayers')),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList.builder(
            itemCount: reviews.length,
            itemBuilder: (context, i) {
              final review = reviews[i];
              final appearance = scope.repository.appearance(review.appearanceId);
              final player = appearance == null
                  ? null
                  : scope.repository.player(appearance.playerId);
              final match = appearance == null
                  ? null
                  : scope.repository.match(appearance.matchId);
              if (player == null || appearance == null || match == null) {
                return const SizedBox.shrink();
              }
              final opponent = scope.repository.club(
                match.opponentOf(appearance.clubId),
              );
              return PlayerRow(
                key: Key('history-${review.appearanceId}'),
                player: player,
                club: scope.repository.club(player.clubId),
                score: review.genelPuan,
                subtitle:
                    '${opponent.name} · ${formatMatchDate(match.kickoff)} · ${Tr.t('localPreview')}',
                onTap: () => openPerformance(context, appearance),
              );
            },
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (legacy.isNotEmpty) ...[
                  SectionHeading(Tr.t('legacyTitle')),
                  Text(
                    Tr.t('legacyBody'),
                    style: const TextStyle(
                      color: JuriTheme.muted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final item in legacy)
                    if (scope.repository.player(item.playerId) != null)
                      PlayerRow(
                        player: scope.repository.player(item.playerId)!,
                        club: scope.repository.club(
                          scope.repository.player(item.playerId)!.clubId,
                        ),
                        score: item.score,
                        subtitle: Tr.t('legacyBody'),
                        onTap: () => openAppearancePicker(
                          context,
                          scope.repository.player(item.playerId)!,
                        ),
                      ),
                  TextButton(
                    onPressed: onExplore,
                    child: Text(Tr.t('legacyCta')),
                  ),
                ],
                const Divider(),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    Tr.t('haptics'),
                    style: const TextStyle(fontSize: 13),
                  ),
                  value: scope.user.haptics,
                  onChanged: (v) async {
                    try {
                      await scope.user.setHaptics(v);
                    } catch (_) {
                      if (context.mounted) showSaveError(context);
                    }
                  },
                ),
                if (scope.accounts != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const Key('signOut'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      side: const BorderSide(color: JuriTheme.line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => _signOut(context),
                    child: Text(Tr.t('signOut')),
                  ),
                ],
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const Key('clearData'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    side: const BorderSide(color: JuriTheme.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => _clearData(context),
                  child: Text(Tr.t('clearData')),
                ),
                const SizedBox(height: 18),
                Text(
                  '${Tr.t('dataSource')} · ${scope.repository.meta.season}',
                  style: const TextStyle(color: JuriTheme.muted, fontSize: 11),
                ),
                if (scope.repository.matchMeta.provider.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${Tr.t('sourceLine')}: ${scope.repository.matchMeta.provider} · '
                    '${scope.repository.matchMeta.matchCount} ${Tr.t('seasonMatches').toLowerCase()}',
                    style: const TextStyle(
                      color: JuriTheme.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  Tr.t('offline'),
                  style: const TextStyle(color: JuriTheme.muted, fontSize: 11),
                ),
                if (Thresholds.pilot) ...[
                  const SizedBox(height: 8),
                  Text(
                    Tr.fill('pilotThresholds', {
                      'n': '${Thresholds.publish}',
                      'prod': '5',
                    }),
                    style: const TextStyle(
                      color: JuriTheme.gold,
                      fontSize: 11,
                      height: 1.45,
                    ),
                  ),
                ],
                if (scope.repository.hasDemoContent) ...[
                  const SizedBox(height: 8),
                  Text(
                    Tr.t('demoNote'),
                    style: const TextStyle(
                      color: JuriTheme.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Eyebrow(
                  Backend.buildStamp.isEmpty
                      ? 'JÜRİ · 0.1.0'
                      : 'JÜRİ · 0.1.0 · ${Backend.buildStamp}',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
