import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../features/feed.dart';
import '../features/clubs.dart';
import '../features/discovery.dart';
import '../features/games.dart';
import '../features/posts.dart';
import '../features/profile.dart';
import '../l10n/strings.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: AnimatedSwitcher(
        duration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 230,
        ),
        child: KeyedSubtree(
          key: ValueKey(tab),
          child: switch (tab) {
            0 => FeedScreen(
              onRankings: () => setState(() => tab = 3),
              onClubs: () => setState(() => tab = 2),
            ),
            1 => const PostsScreen(),
            2 => const ClubsScreen(),
            3 => const DiscoveryScreen(),
            4 => const GamesScreen(),
            _ => ProfileScreen(onExplore: () => setState(() => tab = 3)),
          },
        ),
      ),
    ),
    bottomNavigationBar: Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: JuriTheme.line)),
      ),
      // Six destinations do not fit six scaled-up labels on a 390pt phone: at
      // the app's 1.35 ceiling the row overflowed. The bar is chrome rather
      // than content and every destination keeps its icon and its semantic
      // label, so the text here takes a tighter ceiling than the pages do.
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.1,
        child: NavigationBar(
        height: 74,
        backgroundColor: JuriTheme.background,
        indicatorColor: JuriTheme.elevated,
        surfaceTintColor: Colors.transparent,
        // Six destinations across a narrow phone: the label has to give up a
        // point, and the indicator has to stop padding itself into the
        // neighbouring tab.
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -.1,
            color: s.contains(WidgetState.selected)
                ? JuriTheme.gold
                : JuriTheme.muted,
          ),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(CupertinoIcons.bolt, size: 22),
            selectedIcon: const Icon(
              CupertinoIcons.bolt_fill,
              size: 22,
              color: JuriTheme.gold,
            ),
            label: Tr.t('home'),
          ),
          NavigationDestination(
            icon: const Icon(CupertinoIcons.text_bubble, size: 21),
            selectedIcon: const Icon(
              CupertinoIcons.text_bubble_fill,
              size: 21,
              color: JuriTheme.gold,
            ),
            label: Tr.t('posts'),
          ),
          NavigationDestination(
            icon: const Icon(CupertinoIcons.shield, size: 21),
            selectedIcon: const Icon(
              CupertinoIcons.shield_fill,
              size: 21,
              color: JuriTheme.gold,
            ),
            label: Tr.t('clubs'),
          ),
          NavigationDestination(
            icon: const Icon(CupertinoIcons.chart_bar, size: 21),
            selectedIcon: const Icon(
              CupertinoIcons.chart_bar_fill,
              size: 21,
              color: JuriTheme.gold,
            ),
            label: Tr.t('rankings'),
          ),
          NavigationDestination(
            icon: const Icon(CupertinoIcons.game_controller, size: 21),
            selectedIcon: const Icon(
              CupertinoIcons.game_controller_solid,
              size: 21,
              color: JuriTheme.gold,
            ),
            label: Tr.t('games'),
          ),
          NavigationDestination(
            icon: const Icon(CupertinoIcons.person_crop_circle, size: 21),
            selectedIcon: const Icon(
              CupertinoIcons.person_crop_circle_fill,
              size: 21,
              color: JuriTheme.gold,
            ),
            label: Tr.t('profile'),
          ),
        ],
        ),
      ),
    ),
  );
}
