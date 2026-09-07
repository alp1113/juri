import 'package:flutter/material.dart';
import '../app/scope.dart';
import '../core/theme.dart';
import '../data/aggregation.dart';
import '../data/local_state.dart';
import '../data/match_models.dart';
import '../data/models.dart';
import '../l10n/strings.dart';
import '../shared/analysis.dart';
import '../shared/widgets.dart';
import 'matches.dart';
import 'players.dart';
import 'rating.dart';
import 'take.dart';

void openPerformance(BuildContext context, PlayerAppearance appearance) =>
    openPage(context, PerformanceScreen(appearance: appearance));

class PerformanceScreen extends StatefulWidget {
  final PlayerAppearance appearance;
  const PerformanceScreen({super.key, required this.appearance});
  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  bool reveal = false;
  bool clubOnly = false;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final repo = scope.repository;
    final appearance = widget.appearance;
    final match = repo.match(appearance.matchId);
    final player = repo.player(appearance.playerId);
    if (match == null || player == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }
    final club = repo.club(appearance.clubId);
    final own = scope.user.reviewFor(appearance.id);
    final canShow = reveal || own != null;
    final scores = repo.appearanceScores(appearance);
    final reviews = [
      ...repo.reviewsForAppearance(appearance.id),
      ?own,
    ].where((r) {
      if (scope.user.blockedUsers.contains(r.userId)) return false;
      if (clubOnly) return r.supporterClubId == appearance.clubId;
      return true;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(
        title: Text(player.name, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => openMatch(context, match),
            child: Text(Tr.t('seeMatch')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        children: [
          if (repo.hasDemoContent) ...[
            const DemoBanner(),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              ClubBadge(club, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${club.name} · ${formatMatchDate(match.kickoff)} · ${match.result}',
                  style: const TextStyle(fontSize: 12, color: JuriTheme.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Headline(player.name.toUpperCase(), size: 48),
          const SizedBox(height: 8),
          Text(
            appearanceStatus(appearance),
            style: const TextStyle(color: JuriTheme.muted, fontSize: 12),
          ),
          if (appearance.participationUnknown) ...[
            const SizedBox(height: 10),
            Text(
              Tr.t('participationUnknownBody'),
              style: const TextStyle(fontSize: 11, color: JuriTheme.gold),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: JuriTheme.surface,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DualScoreCard(
                  genel: scores.genel,
                  club: scores.club,
                  clubName: club.name,
                  revealed: canShow,
                  demo: repo.hasDemoContent,
                  accent: JuriTheme.clubColor(player.clubId),
                ),
                if (!canShow) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('revealResults'),
                    onPressed: () => setState(() => reveal = true),
                    child: Text(Tr.t('revealResults')),
                  ),
                ],
              ],
            ),
          ),
          if (canShow) ...[
            SectionHeading(Tr.t('analyzePlayer')),
            AttributeAnalysisBoard(
              accent: JuriTheme.clubColor(player.clubId),
              insights: [
                for (final attr in appearance.template.attributes)
                  AttributeInsight(
                    attribute: attr,
                    community:
                        scores.genelAttributes[attr.key] ??
                        const PopulationScore(count: 0),
                    club: scores.clubAttributes[attr.key],
                    personal: own?.attributes[attr.key],
                  ),
              ],
            ),
          ],
          SectionHeading(Tr.t('yourReview')),
          if (own == null)
            FilledButton(
              key: const Key('rateAppearance'),
              onPressed: appearance.reviewPermitted && match.reviewsOpen
                  ? () => openRating(context, appearance)
                  : null,
              child: Text(
                match.reviewsOpen && appearance.reviewPermitted
                    ? Tr.t('rate')
                    : Tr.t('ratingClosed'),
              ),
            )
          else
            _ownReview(context, own),
          if (appearance.reviewPermitted && match.reviewsOpen)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton(
                key: const Key('takeForAppearance'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: JuriTheme.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => openTakeComposer(context, appearance),
                child: Text(Tr.t('writeTake')),
              ),
            ),
          SectionHeading(Tr.t('publicReviews')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(Tr.t('allSupporters')),
                selected: !clubOnly,
                onSelected: (_) => setState(() => clubOnly = false),
              ),
              ChoiceChip(
                label: Text(Tr.t('clubSupporters')),
                selected: clubOnly,
                onSelected: (_) => setState(() => clubOnly = true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (repo.hasDemoContent) ...[
            DemoLabel(label: Tr.t('demoCommunity')),
            const SizedBox(height: 12),
          ],
          if (reviews.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                Tr.t('unrated'),
                style: const TextStyle(color: JuriTheme.muted, fontSize: 12),
              ),
            ),
          for (final review in reviews)
            _reviewCard(context, review, appearance),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => openPlayer(context, player),
            child: Text(Tr.t('seePlayer')),
          ),
        ],
      ),
    );
  }

  Widget _ownReview(BuildContext context, MatchReview own) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: JuriTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Headline(formatScore(own.genelPuan), size: 40, color: JuriTheme.gold),
          const SizedBox(height: 6),
          Text(Tr.t('localPreview'), style: const TextStyle(fontSize: 11, color: JuriTheme.muted)),
          if (own.juriNotu != null) ...[
            const SizedBox(height: 10),
            Text(own.juriNotu!),
          ],
          if (own.edited)
            Text(
              '${Tr.t('edited')} · ${formatMatchDate(own.editedAt!)}',
              style: const TextStyle(fontSize: 10, color: JuriTheme.muted),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: const Key('editReview'),
                  onPressed: () => openRating(context, widget.appearance),
                  child: Text(Tr.t('editReview')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(Tr.t('deleteReview')),
                        content: Text(Tr.t('deleteConfirm')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(Tr.t('cancel')),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(Tr.t('deleteReview')),
                          ),
                        ],
                      ),
                    );
                    if (ok == true && context.mounted) {
                      await AppScope.of(context).user.deleteReview(own.appearanceId);
                    }
                  },
                  child: Text(Tr.t('deleteReview')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reviewCard(
    BuildContext context,
    MatchReview review,
    PlayerAppearance appearance,
  ) {
    final scope = AppScope.of(context);
    final local = review.userId == localUserId;
    final user = local
        ? null
        : scope.repository.demoUser(review.userId);
    final name = local ? Tr.t('yourReview') : (user?.displayName ?? review.userId);
    final support = scope.repository.club(review.supporterClubId);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: JuriTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClubBadge(support, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                formatScore(review.genelPuan),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            local ? Tr.t('localPreview') : clubScoreLabel(support.name),
            style: const TextStyle(fontSize: 10, color: JuriTheme.muted),
          ),
          if (review.juriNotu != null) ...[
            const SizedBox(height: 8),
            Text(review.juriNotu!),
          ],
          const SizedBox(height: 6),
          Text(
            [
              formatMatchDateLong(review.createdAt),
              if (review.edited) '${Tr.t('edited')} ${formatMatchDate(review.editedAt!)}',
            ].join(' · '),
            style: const TextStyle(fontSize: 10, color: JuriTheme.muted),
          ),
          if (!local) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () async {
                    try {
                      await scope.user.reportReview(review.id);
                    } catch (_) {
                      if (context.mounted) showSaveError(context);
                    }
                  },
                  child: Text(
                    scope.user.reportedReviews.contains(review.id)
                        ? Tr.t('reported')
                        : Tr.t('report'),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await scope.user.blockUser(review.userId);
                    } catch (_) {
                      if (context.mounted) showSaveError(context);
                    }
                  },
                  child: Text(Tr.t('block')),
                ),
              ],
            ),
            Text(
              Tr.t('moderationNote'),
              style: const TextStyle(fontSize: 10, color: JuriTheme.muted),
            ),
          ],
        ],
      ),
    );
  }
}
