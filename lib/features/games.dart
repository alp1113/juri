import 'package:flutter/material.dart';
import '../app/scope.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/value_game.dart';
import '../l10n/strings.dart';
import '../shared/widgets.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
      children: [
        Eyebrow('JÜRİ · ${Tr.t('games').toUpperCase()}', color: JuriTheme.gold),
        const SizedBox(height: 14),
        Headline(Tr.t('gameTitle'), size: 54),
        const SizedBox(height: 28),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: const Color(0xFF282F25),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -30,
                width: 230,
                height: 420,
                child: CustomPaint(painter: PitchLines()),
              ),
              Padding(
                padding: const EdgeInsets.all(26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('01 / MARKET VALUE', color: JuriTheme.gold),
                    const SizedBox(height: 36),
                    const Row(
                      children: [
                        Icon(Icons.north_east, size: 68, color: JuriTheme.gold),
                        SizedBox(width: 16),
                        Icon(
                          Icons.south_east,
                          size: 68,
                          color: Color(0xFF6E7963),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Headline(Tr.t('gameName'), size: 54),
                    const SizedBox(height: 20),
                    Text(
                      Tr.t('gameBody'),
                      style: const TextStyle(
                        color: Color(0xFFB9C0B1),
                        height: 1.7,
                      ),
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      key: const Key('startGame'),
                      onPressed: () =>
                          openPage(context, const ValueGameScreen()),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(Tr.t('play')),
                          const SizedBox(width: 12),
                          const Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: JuriTheme.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const Icon(Icons.emoji_events_outlined, color: JuriTheme.gold),
              const SizedBox(width: 13),
              Text(Tr.t('record')),
              const Spacer(),
              Headline('${scope.user.highScore}', size: 34),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          Tr.t('gameNote'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: JuriTheme.muted, fontSize: 10),
        ),
      ],
    );
  }
}

class ValueGameScreen extends StatefulWidget {
  const ValueGameScreen({super.key});
  @override
  State<ValueGameScreen> createState() => _ValueGameScreenState();
}

class _ValueGameScreenState extends State<ValueGameScreen> {
  ValueGame? game;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    game ??= ValueGame(AppScope.of(context).repository.valuedPlayers);
  }

  Future<void> _choose(bool higher) async {
    final scope = AppScope.of(context);
    if (game!.correct != null) return;
    setState(() => game!.choose(higher));
    scope.tick();
    try {
      await scope.user.recordScore(game!.streak);
    } catch (_) {
      if (mounted) showSaveError(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = game!;
    return Scaffold(
      appBar: AppBar(
        title: Eyebrow('MARKET VALUE'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: Center(
              child: Text(
                '${Tr.t('streak')}  ${g.streak}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: JuriTheme.gold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            _card(g.left, hidden: false),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 13),
              child: Center(child: Eyebrow('VS', color: JuriTheme.gold)),
            ),
            _card(g.right, hidden: g.correct == null),
            const SizedBox(height: 26),
            if (g.correct == null) ...[
              Center(
                child: Text(
                  Tr.t('gameQuestion'),
                  style: const TextStyle(color: JuriTheme.muted, fontSize: 12),
                ),
              ),
              const SizedBox(height: 17),
              FilledButton(
                key: const Key('higher'),
                onPressed: () => _choose(true),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.north_east, size: 18),
                    const SizedBox(width: 10),
                    Text(Tr.t('higher')),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                key: const Key('lower'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  side: const BorderSide(color: JuriTheme.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => _choose(false),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.south_east, size: 18),
                    const SizedBox(width: 10),
                    Text(Tr.t('lower')),
                  ],
                ),
              ),
            ] else ...[
              Center(
                child: Headline(
                  Tr.t(g.correct! ? 'correct' : 'incorrect'),
                  size: 40,
                  color: JuriTheme.gold,
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  '${Tr.t('streak')}: ${g.streak} · ${Tr.t('record')}: ${AppScope.of(context).user.highScore}',
                  style: const TextStyle(fontSize: 12, color: JuriTheme.muted),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('nextRound'),
                onPressed: () => setState(() => g.next()),
                child: Text(Tr.t(g.correct! ? 'next' : 'again')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _card(Player p, {required bool hidden}) => Container(
    height: 210 * MediaQuery.textScalerOf(context).scale(1),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: JuriTheme.surface,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Stack(
      children: [
        Positioned(right: 0, top: 0, bottom: 0, width: 165, child: Portrait(p)),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  JuriTheme.surface,
                  JuriTheme.surface.withValues(alpha: .9),
                  Colors.transparent,
                ],
                stops: const [0, .43, 1],
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          top: 18,
          bottom: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClubBadge(
                AppScope.of(context).repository.club(p.clubId),
                size: 28,
              ),
              const Spacer(),
              SizedBox(
                width: 200,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Headline(p.name.toUpperCase(), size: 30),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                hidden ? '€ ? ? ?' : formatValue(p.marketValue),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: JuriTheme.gold,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
