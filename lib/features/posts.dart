import 'package:flutter/material.dart';
import '../app/scope.dart';
import '../core/theme.dart';
import '../data/feed_models.dart';
import '../l10n/strings.dart';
import '../shared/widgets.dart';
import 'feed.dart';

/// Which slice of the ground a reader is listening to.
enum PostScope { all, myClub, mine }

/// Nothing but what people said.
///
/// The feed mixes takes with moments, prompts, polls and editorial, which is
/// what makes it a landing page and also what makes it busy. This surface is
/// the other half of that trade: one kind of card, newest first, so a reader
/// who came to read opinions is not scrolling past furniture to find them.
class PostsScreen extends StatefulWidget {
  const PostsScreen({super.key});
  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  PostScope scope = PostScope.all;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final club = app.user.clubId;
    final remote = app.remote;
    final posts = [
      for (final take in app.feed.allTakes)
        if (switch (scope) {
          PostScope.all => true,
          PostScope.mine => take.mine,
          PostScope.myClub =>
            take.clubId == club || take.authorClubId == club,
        })
          take,
    ];

    final body = CustomScrollView(
      key: const PageStorageKey('posts'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(
                  Tr.t('posts').toUpperCase(),
                  color: JuriTheme.gold,
                ),
                const SizedBox(height: 14),
                Headline(Tr.t('postsTitle'), size: 50),
                const SizedBox(height: 12),
                Text(
                  Tr.t('postsBody'),
                  style: const TextStyle(color: JuriTheme.muted, fontSize: 12),
                ),
                const SizedBox(height: 18),
                const ComposeTakeButton(),
                const SizedBox(height: 18),
                // Three chips fit a phone until the reader turns text size up,
                // so the row scrolls rather than overflowing.
                SizedBox(
                  height: 38 * MediaQuery.textScalerOf(context).scale(1),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final option in PostScope.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            key: Key('postScope-${option.name}'),
                            label: Text(
                              switch (option) {
                                PostScope.all => Tr.t('postsAll'),
                                PostScope.myClub => Tr.t('postsMyClub'),
                                PostScope.mine => Tr.t('postsMine'),
                              },
                            ),
                            selected: scope == option,
                            onSelected: (_) {
                              app.tick();
                              setState(() => scope = option);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
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
        if (posts.isEmpty)
          SliverToBoxAdapter(
            child: EmptyView(
              title: Tr.t('postsEmpty'),
              body: Tr.t('postsEmptyBody'),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          sliver: SliverList.separated(
            itemCount: posts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, i) =>
                TakeCard(take: posts[i], key: Key('post-${posts[i].id}')),
          ),
        ),
      ],
    );

    if (remote == null) return body;
    return RefreshIndicator(
      color: JuriTheme.gold,
      backgroundColor: JuriTheme.surface,
      onRefresh: () => remote.refresh(),
      child: body,
    );
  }
}
