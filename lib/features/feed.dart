import 'package:flutter/material.dart';
import '../app/scope.dart';
import '../core/theme.dart';
import '../data/feed_models.dart';
import '../data/match_models.dart';
import '../data/models.dart';
import '../l10n/strings.dart';
import '../shared/widgets.dart';
import 'clubs.dart';
import 'discovery.dart';
import 'editorial.dart';
import 'matches.dart';
import 'performance.dart';
import 'take.dart';
import 'thread.dart';

/// The feed is the home surface.
///
/// Three things share the scroll: moments the fixture data can prove, takes
/// the reader has written, and the league's own editorial furniture. There
/// are no invented supporters here — the app does not caption fabricated
/// content as real anywhere else, and the most visible screen is the worst
/// place to start.
class FeedScreen extends StatefulWidget {
  final VoidCallback onRankings, onClubs;
  const FeedScreen({
    super.key,
    required this.onRankings,
    required this.onClubs,
  });
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  FeedFilter filter = FeedFilter.forYou;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final repo = scope.repository;
    final club = repo.club(scope.user.clubId!);
    final items = scope.feed.feed(
      filter: filter,
      supporterClubId: scope.user.clubId!,
    );
    final remote = scope.remote;
    final feed = CustomScrollView(
      key: const PageStorageKey('feed'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'jüri',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -3,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(height: 22, width: 1, color: JuriTheme.line),
                    const SizedBox(width: 14),
                    const Expanded(child: Eyebrow('SÜPER LİG')),
                    IconButton(
                      tooltip: Tr.t('search'),
                      onPressed: () => openPage(
                        context,
                        const DiscoveryScreen(searchMode: true),
                      ),
                      icon: const Icon(Icons.search, size: 24),
                    ),
                    Pressable(
                      onTap: () => openClub(context, club),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: JuriTheme.line),
                        ),
                        child: ClubBadge(club, size: 26),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (repo.hasDemoContent) ...[
                  const DemoBanner(),
                  const SizedBox(height: 16),
                ],
                // The hero used to run a 54pt headline and a subtitle above a
                // compose button and a filter row, which is most of a phone
                // screen before the first card. The logo above already says
                // where you are, so this keeps one line of orientation and
                // gives the space back to the feed.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Eyebrow(Tr.t('leagueVoice'), color: JuriTheme.gold),
                          const SizedBox(height: 6),
                          Text(
                            Tr.t('feedSubtitle'),
                            style: const TextStyle(
                              color: JuriTheme.muted,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const ComposeTakeButton(),
                  ],
                ),
                const SizedBox(height: 16),
                _Filters(
                  value: filter,
                  onChanged: (f) {
                    scope.tick();
                    setState(() => filter = f);
                  },
                ),
                const SizedBox(height: 12),
                if (remote == null && scope.feed.takesAreLocalOnly)
                  Text(
                    Tr.t('feedLocalNote'),
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: JuriTheme.muted,
                    ),
                  ),
                if (remote?.failureKey != null)
                  Text(
                    Tr.t(remote!.failureKey!),
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: JuriTheme.gold,
                    ),
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          sliver: SliverList.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, i) => _card(context, items[i]),
          ),
        ),
      ],
    );
    if (remote == null) return feed;
    return RefreshIndicator(
      color: JuriTheme.gold,
      backgroundColor: JuriTheme.surface,
      onRefresh: () => remote.refresh(),
      child: feed,
    );
  }

  Widget _card(BuildContext context, FeedItem item) => switch (item) {
    TakeItem(:final take) => TakeCard(take: take, key: Key('feed-${item.id}')),
    MomentItem(:final moment) => _MomentCard(
      moment: moment,
      key: Key('feed-${item.id}'),
    ),
    PromptItem() => _PromptCard(prompt: item, key: Key('feed-${item.id}')),
    PollItem() => _PollCard(poll: item, key: Key('feed-${item.id}')),
    EditorialItem(:final kind) => _editorial(kind),
  };

  Widget _editorial(EditorialKind kind) {
    final match = spotlightMatch(context);
    return switch (kind) {
      EditorialKind.spotlight => match == null
          ? const SizedBox.shrink()
          : SpotlightCard(match: match),
      EditorialKind.fixtures => const FixturesBlock(),
      EditorialKind.scorers => const ScorersBlock(),
      EditorialKind.standings => StandingsBlock(onClubs: widget.onClubs),
      EditorialKind.links => LeagueLinksBlock(onRankings: widget.onRankings),
    };
  }
}

class _Filters extends StatelessWidget {
  final FeedFilter value;
  final ValueChanged<FeedFilter> onChanged;
  const _Filters({required this.value, required this.onChanged});

  static const _labels = {
    FeedFilter.forYou: 'filterForYou',
    FeedFilter.myClub: 'filterMyClub',
    FeedFilter.league: 'filterLeague',
  };

  // Deliberately a Wrap rather than a horizontal scroller: three chips fit on
  // one line at normal text sizes and fall to a second line at large ones,
  // and a nested Scrollable inside the feed would swallow vertical drags.
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final entry in _labels.entries)
        ChoiceChip(
          key: Key('filter-${entry.key.name}'),
          label: Text(Tr.t(entry.value)),
          selected: value == entry.key,
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: value == entry.key ? JuriTheme.background : JuriTheme.ink,
          ),
          showCheckmark: false,
          onSelected: (_) => onChanged(entry.key),
        ),
    ],
  );
}

class ComposeTakeButton extends StatelessWidget {
  const ComposeTakeButton({super.key});
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: () => openTakeFlow(context),
    child: Container(
      key: const Key('writeTake'),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: JuriTheme.gold,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.edit, size: 16, color: JuriTheme.background),
          const SizedBox(width: 10),
          Text(
            Tr.t('writeTake'),
            style: const TextStyle(
              color: JuriTheme.background,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    ),
  );
}

/// One supporter's opinion, with the badge that gives it its meaning.
///
/// "He's incredible" from a rival's stand is a different sentence from the
/// same words at home, so the badge is never optional on a take.
class TakeCard extends StatelessWidget {
  final Take take;

  /// The thread screen shows the take at the top of its own replies, where a
  /// link back into itself would be a loop.
  final bool showThreadLink;
  const TakeCard({super.key, required this.take, this.showThreadLink = true});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final repo = scope.repository;
    final player = repo.player(take.playerId);
    final appearance = repo.appearance(take.appearanceId);
    final match = repo.match(take.matchId);
    if (player == null || appearance == null || match == null) {
      return const SizedBox.shrink();
    }
    final author = repo.club(take.authorClubId);
    final opponent = repo.club(match.opponentOf(take.clubId));
    return Pressable(
      onTap: () => showThreadLink
          ? openThread(context, take)
          : openPerformance(context, appearance),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: JuriTheme.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClubBadge(author, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Eyebrow(
                    take.mine
                        ? Tr.t('yourTake')
                        : '${take.authorName ?? '?'} · '
                              '${author.name} ${Tr.t('takeBy')}',
                    color: JuriTheme.gold,
                  ),
                ),
                Text(
                  formatMatchDate(take.updatedAt),
                  style: const TextStyle(fontSize: 10, color: JuriTheme.muted),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              take.body,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: JuriTheme.elevated,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Portrait(player, width: 38, height: 44),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          player.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${opponent.name} · ${formatMatchDate(match.kickoff)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: JuriTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ScoreChip(take.score),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Voting on your own take would be applauding yourself, so the
                // arrows only appear on somebody else's.
                if (!take.mine) _TakeVotes(take: take),
                if (showThreadLink) _ReplyLink(take: take, thread: () => openThread(context, take)),
                const Spacer(),
                if (take.mine)
                  TextButton(
                    key: Key('editTake-${take.appearanceId}'),
                    onPressed: () => openTakeComposer(context, appearance),
                    child: Text(
                      Tr.t('editReview'),
                      style: const TextStyle(fontSize: 11),
                    ),
                  )
                else
                  _TakeMenu(take: take),
              ],
            ),
            if (!take.published)
              Text(
                Tr.t('localPreview'),
                style: const TextStyle(fontSize: 10, color: JuriTheme.muted),
              ),
          ],
        ),
      ),
    );
  }
}

class _TakeVotes extends StatelessWidget {
  final Take take;
  const _TakeVotes({required this.take});
  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final remote = scope.remote;
    // With no server there is nobody else's take to vote on, so the local
    // build keeps its like-only toggle rather than inventing a crowd.
    if (remote == null) {
      final liked = scope.user.likedTakes.contains(take.id);
      return TextButton.icon(
        onPressed: () async {
          try {
            await scope.user.toggleLike(take.id);
            scope.tick();
          } catch (_) {
            if (context.mounted) showSaveError(context);
          }
        },
        icon: Icon(
          liked ? Icons.favorite : Icons.favorite_border,
          size: 15,
          color: liked ? JuriTheme.gold : JuriTheme.muted,
        ),
        label: Text(
          take.likeCount == 0 ? '' : '${take.likeCount}',
          style: const TextStyle(fontSize: 11),
        ),
      );
    }
    return VoteBar(
      likeCount: take.likeCount,
      dislikeCount: take.dislikeCount,
      myVote: take.myVote,
      onVote: (v) async {
        try {
          await remote.voteOnTake(take, v);
          scope.tick();
        } catch (_) {
          if (context.mounted) showSaveError(context);
        }
      },
    );
  }
}

class _ReplyLink extends StatelessWidget {
  final Take take;
  final VoidCallback thread;
  const _ReplyLink({required this.take, required this.thread});
  @override
  Widget build(BuildContext context) => TextButton.icon(
    key: Key('replies-${take.id}'),
    onPressed: thread,
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    icon: const Icon(
      Icons.mode_comment_outlined,
      size: 14,
      color: JuriTheme.muted,
    ),
    label: Text(
      take.replyCount == 0 ? Tr.t('reply') : '${take.replyCount}',
      style: const TextStyle(fontSize: 11, color: JuriTheme.muted),
    ),
  );
}

class _MomentCard extends StatelessWidget {
  final LeagueMoment moment;
  const _MomentCard({super.key, required this.moment});

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    final match = repo.match(moment.matchId);
    if (match == null) return const SizedBox.shrink();
    final player = moment.playerId == null
        ? null
        : repo.player(moment.playerId!);
    final appearance = player == null
        ? null
        : repo
              .appearancesForMatch(match.id)
              .where((a) => a.playerId == player.id)
              .firstOrNull;
    final home = repo.club(match.homeClubId);
    final away = repo.club(match.awayClubId);
    return Pressable(
      onTap: () => openMatch(context, match),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: JuriTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: JuriTheme.clubColor(moment.clubId).withValues(alpha: .35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Eyebrow(
                    Tr.t('moment_${moment.kind.name}'),
                    color: JuriTheme.clubColor(moment.clubId),
                  ),
                ),
                Text(
                  formatMatchDate(match.kickoff),
                  style: const TextStyle(fontSize: 10, color: JuriTheme.muted),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (player != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Portrait(player, width: 48, height: 56),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    _sentence(context, moment, match, home, away, player),
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${home.shortName} ${match.result} ${away.shortName} · ${Tr.t('momentSource')}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: JuriTheme.muted,
                    ),
                  ),
                ),
                if (appearance != null && appearance.reviewPermitted)
                  TextButton(
                    key: Key('rateMoment-${appearance.id}'),
                    onPressed: () => openTakeComposer(context, appearance),
                    child: Text(
                      Tr.t('rateThisPlayer'),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _sentence(
    BuildContext context,
    LeagueMoment moment,
    Match match,
    Club home,
    Club away,
    Player? player,
  ) => Tr.fill('momentBody_${moment.kind.name}', {
    'player': player?.name ?? '',
    'club': AppScope.of(context).repository.club(moment.clubId).name,
    'value': '${moment.value ?? ''}',
    'score': match.result,
    'home': home.name,
    'away': away.name,
  });
}

class _PromptCard extends StatelessWidget {
  final PromptItem prompt;
  const _PromptCard({super.key, required this.prompt});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final repo = scope.repository;
    final match = repo.match(prompt.matchId);
    if (match == null) return const SizedBox.shrink();
    final title = prompt.kind == PromptKind.rateLatest
        ? Tr.t('promptRateLatest')
        : Tr.t('promptExplain');
    final body = prompt.kind == PromptKind.rateLatest
        ? Tr.t('promptRateLatestBody')
        : Tr.t('promptExplainBody');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: JuriTheme.gold.withValues(alpha: .5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: JuriTheme.muted,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              FilledButton(
                key: Key('promptOpen-${prompt.id}'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                onPressed: () {
                  final appearance = prompt.appearanceId == null
                      ? null
                      : repo.appearance(prompt.appearanceId!);
                  appearance == null
                      ? openTakePlayerPicker(context, match)
                      : openTakeComposer(context, appearance);
                },
                child: Text(Tr.t('promptOpen')),
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  try {
                    await scope.user.dismissPrompt(prompt.id);
                  } catch (_) {
                    if (context.mounted) showSaveError(context);
                  }
                },
                child: Text(
                  Tr.t('promptDismiss'),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Man of the match over the players the fixture data puts on the scoresheet.
/// The vote is stored on this device and the card says so; there is nobody to
/// send it to yet, and a tally nobody contributed to would be a lie.
class _PollCard extends StatelessWidget {
  final PollItem poll;
  const _PollCard({super.key, required this.poll});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final repo = scope.repository;
    final match = repo.match(poll.matchId);
    if (match == null) return const SizedBox.shrink();
    final home = repo.club(match.homeClubId);
    final away = repo.club(match.awayClubId);
    final chosen = scope.user.voteFor(poll.matchId);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: JuriTheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Eyebrow(Tr.t('pollTitle'), color: JuriTheme.gold)),
              Text(
                '${home.shortName} ${match.result} ${away.shortName}',
                style: const TextStyle(fontSize: 11, color: JuriTheme.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            Tr.t('pollBody'),
            style: const TextStyle(fontSize: 12, color: JuriTheme.muted),
          ),
          const SizedBox(height: 12),
          for (final id in poll.candidateIds)
            if (repo.player(id) != null)
              _option(context, repo.player(id)!, chosen),
          const SizedBox(height: 8),
          Text(
            chosen == null ? Tr.t('pollLocal') : '${Tr.t('pollVoted')} ${Tr.t('pollLocal')}',
            style: const TextStyle(fontSize: 10, color: JuriTheme.muted, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _option(BuildContext context, Player player, String? chosen) {
    final scope = AppScope.of(context);
    final selected = chosen == player.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Pressable(
        key: Key('vote-${poll.matchId}-${player.id}'),
        onTap: () async {
          try {
            await scope.user.vote(poll.matchId, player.id);
            scope.tick();
          } catch (_) {
            if (context.mounted) showSaveError(context);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? JuriTheme.gold : JuriTheme.elevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? JuriTheme.background : JuriTheme.ink,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check, size: 16, color: JuriTheme.background),
            ],
          ),
        ),
      ),
    );
  }
}

/// Report and block, required of anything carrying other people's words.
class _TakeMenu extends StatelessWidget {
  final Take take;
  const _TakeMenu({required this.take});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final remote = scope.remote;
    if (remote == null) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      key: Key('takeMenu-${take.id}'),
      icon: const Icon(Icons.more_horiz, size: 18, color: JuriTheme.muted),
      itemBuilder: (context) => [
        PopupMenuItem(value: 'report', child: Text(Tr.t('reportTake'))),
        PopupMenuItem(value: 'block', child: Text(Tr.t('blockAuthor'))),
      ],
      onSelected: (choice) async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          if (choice == 'report') {
            await remote.report(take.id, Tr.t('reportReason'));
            messenger.showSnackBar(
              SnackBar(content: Text(Tr.t('reportSent'))),
            );
          } else {
            await remote.block(take.authorId);
            messenger.showSnackBar(SnackBar(content: Text(Tr.t('blockSent'))));
          }
        } catch (_) {
          messenger.showSnackBar(SnackBar(content: Text(Tr.t('saveError'))));
        }
      },
    );
  }
}
