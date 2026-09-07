import 'package:flutter/material.dart';
import '../app/scope.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../l10n/strings.dart';
import '../shared/widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  Club? selected;
  bool saving = false;
  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final accent = selected == null
        ? JuriTheme.gold
        : JuriTheme.clubColor(selected!.id);
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(.8, -.65),
            radius: 1.05,
            colors: [accent.withValues(alpha: .13), JuriTheme.background],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'jüri',
                                  style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -3,
                                  ),
                                ),
                                const Spacer(),
                                Eyebrow('01 / 01', color: accent),
                              ],
                            ),
                            const SizedBox(height: 26),
                            Eyebrow(Tr.t('tagline'), color: accent),
                            const SizedBox(height: 16),
                            Headline(Tr.t('welcomeTitle'), size: 66),
                            const SizedBox(height: 16),
                            Text(
                              Tr.t('welcomeBody'),
                              style: const TextStyle(
                                color: JuriTheme.muted,
                                fontSize: 14,
                                height: 1.7,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Row(
                              children: [
                                Text(
                                  Tr.t('chooseClub'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                const Eyebrow('SÜPER LİG · 18'),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) => SliverGrid(
                          delegate: SliverChildBuilderDelegate((context, i) {
                            final c = scope.repository.clubs[i];
                            final active = selected?.id == c.id;
                            return Semantics(
                              selected: active,
                              label: c.name,
                              child: Pressable(
                                onTap: () => setState(() {
                                  selected = c;
                                  scope.tick();
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? accent.withValues(alpha: .12)
                                        : JuriTheme.surface.withValues(
                                            alpha: .85,
                                          ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: active
                                          ? accent
                                          : JuriTheme.line.withValues(
                                              alpha: .6,
                                            ),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          ClubBadge(c, size: 43, linked: false),
                                          if (active)
                                            Positioned(
                                              right: -15,
                                              top: -3,
                                              child: Icon(
                                                Icons.check_circle,
                                                size: 16,
                                                color: accent,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        c.name,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: active
                                              ? accent
                                              : JuriTheme.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }, childCount: scope.repository.clubs.length),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount:
                                    constraints.crossAxisExtent > 600 ? 6 : 3,
                                mainAxisExtent:
                                    108 *
                                    MediaQuery.textScalerOf(context).scale(1),
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                decoration: const BoxDecoration(
                  color: JuriTheme.background,
                  border: Border(top: BorderSide(color: JuriTheme.line)),
                ),
                child: Column(
                  children: [
                    FilledButton(
                      key: const Key('joinClub'),
                      style: FilledButton.styleFrom(backgroundColor: accent),
                      onPressed: selected == null || saving
                          ? null
                          : () async {
                              setState(() => saving = true);
                              try {
                                scope.tick();
                                // The server first: its insert policy refuses
                                // a take whose badge does not match a chosen
                                // club, so a device that thinks it has one
                                // while the account does not would be able to
                                // rate and never publish.
                                await scope.accounts?.chooseClub(selected!.id);
                                await scope.user.chooseClub(selected!.id);
                              } catch (_) {
                                if (context.mounted) {
                                  showSaveError(context);
                                  setState(() => saving = false);
                                }
                              }
                            },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (selected != null) ...[
                            ClubBadge(selected!, size: 24, linked: false),
                            const SizedBox(width: 12),
                          ],
                          Text(Tr.t('continue')),
                          const SizedBox(width: 12),
                          const Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      Tr.t('identityNote'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: JuriTheme.muted,
                        fontSize: 9,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
