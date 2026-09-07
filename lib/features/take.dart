import 'package:flutter/material.dart';
import '../app/scope.dart';
import '../core/theme.dart';
import '../data/feed_models.dart';
import '../data/match_models.dart';
import '../data/models.dart';
import '../l10n/strings.dart';
import '../shared/widgets.dart';
import 'feed.dart';

/// Writing a take: pick a fixture, pick somebody who actually played, score
/// them, say why.
///
/// The order matters. A take that starts from a blank text box is a tweet
/// about football; a take that starts from an appearance is an opinion about
/// ninety minutes somebody watched, which is the only kind this app carries.
void openTakeFlow(BuildContext context) {
  final repo = AppScope.of(context).repository;
  final clubId = AppScope.of(context).user.clubId;
  final finished =
      repo.matches.where((m) => m.status == MatchStatus.finished).toList()
        ..sort((a, b) => b.kickoff.compareTo(a.kickoff));
  // Your own club's fixtures first: they are the ones you watched.
  bool yours(Match m) => m.homeClubId == clubId || m.awayClubId == clubId;
  final ordered = <Match>[
    ...finished.where(yours),
    ...finished.where((m) => !yours(m)),
  ];
  if (ordered.isEmpty) return;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              Tr.t('pickMatch'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final match in ordered.take(12))
                  ListTile(
                    key: Key('pickMatch-${match.id}'),
                    leading: ClubBadge(
                      repo.club(match.homeClubId),
                      size: 28,
                      linked: false,
                    ),
                    title: Text(
                      '${repo.club(match.homeClubId).name} ${match.result} '
                      '${repo.club(match.awayClubId).name}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(formatMatchDate(match.kickoff)),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      openTakePlayerPicker(context, match);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

void openTakePlayerPicker(BuildContext context, Match match) =>
    openPage(context, TakePlayerPicker(match: match));

void openTakeComposer(BuildContext context, PlayerAppearance appearance) =>
    openPage(context, TakeComposerScreen(appearance: appearance));

/// Only players the fixture data proves were on the pitch. An unused
/// substitute cannot be judged, so they are not offered.
class TakePlayerPicker extends StatelessWidget {
  final Match match;
  const TakePlayerPicker({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    final rateable = repo
        .appearancesForMatch(match.id)
        .where((a) => a.reviewPermitted)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(Tr.t('pickPlayer'), style: const TextStyle(fontSize: 14)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
        children: [
          Text(
            Tr.t('pickPlayerBody'),
            style: const TextStyle(
              color: JuriTheme.muted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          if (rateable.isEmpty)
            EmptyView(
              title: Tr.t('noLineup'),
              body: Tr.t('noAppearancesBody'),
            ),
          for (final clubId in [match.homeClubId, match.awayClubId]) ...[
            SectionHeading(repo.club(clubId).name),
            for (final a in rateable.where((a) => a.clubId == clubId))
              if (repo.player(a.playerId) != null)
                PlayerRow(
                  key: Key('takeFor-${a.id}'),
                  player: repo.player(a.playerId)!,
                  club: repo.club(clubId),
                  subtitle: appearanceStatus(a, includeRole: false),
                  onTap: () => openTakeComposer(context, a),
                ),
          ],
        ],
      ),
    );
  }
}

/// The score and the sentence, saved together.
///
/// A take without a score is a shout; a score without a take is a number. The
/// form insists on the first and invites the second.
class TakeComposerScreen extends StatefulWidget {
  final PlayerAppearance appearance;
  const TakeComposerScreen({super.key, required this.appearance});
  @override
  State<TakeComposerScreen> createState() => _TakeComposerScreenState();
}

class _TakeComposerScreenState extends State<TakeComposerScreen> {
  double? score;
  late TextEditingController body;
  bool saving = false, loaded = false;

  @override
  void initState() {
    super.initState();
    body = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loaded) return;
    loaded = true;
    final review = AppScope.of(context).user.reviewFor(widget.appearance.id);
    if (review == null) return;
    score = review.genelPuan;
    body.text = review.juriNotu ?? '';
  }

  @override
  void dispose() {
    body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final scope = AppScope.of(context);
    if (score == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(Tr.t('takeNeedsScore'))));
      return;
    }
    setState(() => saving = true);
    try {
      // The composer only edits the score and the note. Attribute ratings
      // given on the full rating form are carried through untouched rather
      // than being wiped by a screen that never asked about them.
      final existing = scope.user.reviewFor(widget.appearance.id);
      await scope.saveAndPublish(
        appearanceId: widget.appearance.id,
        genelPuan: score!,
        attributes: existing?.attributes ?? const {},
        juriNotu: body.text,
      );
      scope.tick();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(Tr.t('takeSaved'))));
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        showSaveError(context);
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final repo = scope.repository;
    final player = repo.player(widget.appearance.playerId);
    final match = repo.match(widget.appearance.matchId);
    if (player == null || match == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final club = repo.club(widget.appearance.clubId);
    final opponent = repo.club(match.opponentOf(widget.appearance.clubId));
    final existing = scope.user.reviewFor(widget.appearance.id);
    final remaining = takeMaxLength - body.text.characters.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(player.name, style: const TextStyle(fontSize: 14)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        children: [
          Headline(Tr.t('takeTitle'), size: 40),
          const SizedBox(height: 14),
          Text(
            Tr.t('takeBody'),
            style: const TextStyle(
              color: JuriTheme.muted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: JuriTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Portrait(player, width: 48, height: 56),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${club.name} · ${opponent.name} · '
                        '${formatMatchDate(match.kickoff)}',
                        maxLines: 2,
                        style: const TextStyle(
                          fontSize: 11,
                          color: JuriTheme.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appearanceStatus(widget.appearance, includeRole: false),
                        style: const TextStyle(
                          fontSize: 11,
                          color: JuriTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Eyebrow(Tr.t('genelPuan'), color: JuriTheme.gold),
          const SizedBox(height: 8),
          Center(
            child: Headline(
              score == null ? Tr.t('emptyScore') : formatScore(score!),
              size: 72,
              color: JuriTheme.gold,
            ),
          ),
          Slider(
            key: const Key('takeScore'),
            min: 1,
            max: 10,
            divisions: 18,
            value: score ?? 5.5,
            label: formatScore(score ?? 5.5),
            onChanged: (v) {
              scope.tick();
              setState(() => score = snapHalf(v));
            },
          ),
          Text(
            Tr.t('halfStep'),
            style: const TextStyle(fontSize: 10, color: JuriTheme.muted),
          ),
          const SizedBox(height: 24),
          Text(
            Tr.t('juriNotu'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('takeBody'),
            controller: body,
            maxLines: 5,
            maxLength: takeMaxLength,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: Tr.t('takeHint'),
              counterText: '',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$remaining ${Tr.t('takeRemaining')}',
            style: const TextStyle(fontSize: 11, color: JuriTheme.muted),
          ),
          const SizedBox(height: 22),
          FilledButton(
            key: const Key('saveTake'),
            onPressed: saving ? null : _save,
            child: Text(
              Tr.t(existing?.juriNotu == null ? 'takePublish' : 'takeUpdate'),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            Tr.t('localNote'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: JuriTheme.muted),
          ),
          const SizedBox(height: 6),
          Text(
            Tr.t('affiliationSnapshot'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: JuriTheme.muted),
          ),
          const SizedBox(height: 6),
          Text(
            Tr.t('noCommentsBody'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: JuriTheme.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Every take written about one player, for the player profile.
class PlayerTakes extends StatelessWidget {
  final Player player;
  const PlayerTakes({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final takes = scope.feed.takesForPlayer(player.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(Tr.t('takesHeading')),
        if (takes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: JuriTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Tr.t('takeEmpty'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  Tr.t('takeEmptyBody'),
                  style: const TextStyle(
                    fontSize: 11,
                    color: JuriTheme.muted,
                  ),
                ),
              ],
            ),
          ),
        for (final take in takes)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TakeCard(take: take, key: Key('playerTake-${take.id}')),
          ),
      ],
    );
  }
}
