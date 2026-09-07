import 'package:flutter/material.dart';
import '../app/scope.dart';
import '../core/theme.dart';
import '../data/attributes.dart';
import '../data/feed_models.dart';
import '../data/match_models.dart';
import '../data/models.dart';
import '../l10n/strings.dart';
import '../shared/widgets.dart';

void openRating(BuildContext context, PlayerAppearance appearance) =>
    openPage(context, RatingScreen(appearance: appearance));

void openAppearancePicker(BuildContext context, Player player) =>
    openPage(context, AppearancePicker(player: player));

class AppearancePicker extends StatelessWidget {
  final Player player;
  const AppearancePicker({super.key, required this.player});
  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    final user = AppScope.of(context).user;
    final apps = repo.appearancesForPlayer(player.id);
    return Scaffold(
      appBar: AppBar(
        title: Text(Tr.t('chooseAppearance'), style: const TextStyle(fontSize: 14)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
        children: [
          Text(
            Tr.t('chooseAppearanceBody'),
            style: const TextStyle(color: JuriTheme.muted, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 16),
          if (apps.isEmpty)
            EmptyView(title: Tr.t('noAppearances'), body: Tr.t('noAppearancesBody')),
          for (final a in apps)
            _row(context, a, repo.match(a.matchId), user.reviewFor(a.id)),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    PlayerAppearance appearance,
    Match? match,
    MatchReview? own,
  ) {
    if (match == null) return const SizedBox.shrink();
    final repo = AppScope.of(context).repository;
    final opponent = repo.club(match.opponentOf(appearance.clubId));
    final open = match.reviewsOpen && appearance.reviewPermitted;
    return ListTile(
      key: Key('pick-${appearance.id}'),
      contentPadding: EdgeInsets.zero,
      leading: ClubBadge(opponent, size: 32),
      title: Text('${opponent.name} · ${match.result}'),
      subtitle: Text(
        [
          formatMatchDate(match.kickoff),
          appearanceStatus(appearance),
          if (!match.reviewsOpen) Tr.t('ratingClosed'),
          if (own != null) '${Tr.t('yourRating')} ${formatScore(own.genelPuan)}',
        ].join(' · '),
      ),
      enabled: open,
      onTap: open ? () => openRating(context, appearance) : null,
    );
  }
}

class RatingScreen extends StatefulWidget {
  final PlayerAppearance appearance;
  const RatingScreen({super.key, required this.appearance});
  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  double? genel;
  late Map<String, double?> attrs;
  late TextEditingController note;
  bool analyze = false, saving = false, saved = false;
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    attrs = {
      for (final a in widget.appearance.template.attributes) a.key: null,
    };
    note = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loaded) return;
    loaded = true;
    final review = AppScope.of(context).user.reviewFor(widget.appearance.id);
    if (review == null) return;
    genel = review.genelPuan;
    for (final e in review.attributes.entries) {
      attrs[e.key] = e.value;
    }
    analyze = review.attributes.isNotEmpty;
    note.text = review.juriNotu ?? '';
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final repo = scope.repository;
    final appearance = widget.appearance;
    final player = repo.player(appearance.playerId);
    final match = repo.match(appearance.matchId);
    if (player == null || match == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final club = repo.club(appearance.clubId);
    if (!appearance.reviewPermitted || !match.reviewsOpen) {
      return Scaffold(
        appBar: AppBar(
          title: Text(player.name, style: const TextStyle(fontSize: 14)),
        ),
        body: EmptyView(
          title: appearance.reviewPermitted
              ? Tr.t('ratingClosed')
              : Tr.t('participationUnknown'),
          body: appearance.reviewPermitted
              ? Tr.t('rankingBody')
              : Tr.t('participationUnknownBody'),
          action: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(Tr.t('back')),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(player.name, style: const TextStyle(fontSize: 14)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        children: [
          Row(
            children: [
              ClubBadge(club, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${club.name} · ${formatMatchDate(match.kickoff)}',
                  style: const TextStyle(fontSize: 12, color: JuriTheme.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Headline(Tr.t('ratingTitle'), size: 46),
          if (saved) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: JuriTheme.elevated,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${Tr.t('saved')} ${Tr.t('keepEditing')}',
                style: const TextStyle(fontSize: 11, height: 1.45),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            Tr.t('ratingBody'),
            style: const TextStyle(color: JuriTheme.muted, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 8),
          Text(
            AttributeCatalog.roleHint,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          if (appearance.positionNote != null) ...[
            const SizedBox(height: 6),
            Text(
              appearance.positionNote!,
              style: const TextStyle(fontSize: 12, color: JuriTheme.gold),
            ),
          ],
          const SizedBox(height: 22),
          Eyebrow(Tr.t('genelPuan'), color: JuriTheme.gold),
          const SizedBox(height: 12),
          Center(
            child: Headline(
              genel == null ? Tr.t('emptyScore') : formatScore(genel!),
              size: 88,
              color: JuriTheme.gold,
            ),
          ),
          _stepper(
            value: genel,
            onChanged: (v) {
              scope.tick();
              setState(() => genel = v);
            },
            sliderKey: const Key('genelSlider'),
            plusKey: const Key('genelPlus'),
            minusKey: const Key('genelMinus'),
          ),
          Text(
            Tr.t('halfStep'),
            style: const TextStyle(fontSize: 10, color: JuriTheme.muted),
          ),
          const SizedBox(height: 22),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(Tr.t('analyzePlayer')),
            value: analyze,
            onChanged: (v) => setState(() => analyze = v),
          ),
          if (analyze)
            for (final attr in appearance.template.attributes)
              _attribute(attr, scope),
          const SizedBox(height: 12),
          Text(Tr.t('juriNotu'), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            Tr.t('optionalNote'),
            style: const TextStyle(fontSize: 11, color: JuriTheme.muted),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: note,
            maxLines: 4,
            maxLength: takeMaxLength,
            decoration: InputDecoration(hintText: Tr.t('takeHint')),
          ),
          const SizedBox(height: 22),
          FilledButton(
            key: const Key('saveReview'),
            onPressed: saving
                ? null
                : () async {
                    if (genel == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(Tr.t('requiredOverall'))),
                      );
                      return;
                    }
                    setState(() => saving = true);
                    try {
                      await scope.saveAndPublish(
                        appearanceId: appearance.id,
                        genelPuan: genel!,
                        attributes: {
                          for (final e in attrs.entries)
                            if (e.value != null) e.key: e.value!,
                        },
                        juriNotu: note.text,
                      );
                      scope.tick();
                      if (mounted) {
                        setState(() {
                          saved = true;
                          saving = false;
                        });
                      }
                    } catch (_) {
                      if (context.mounted) {
                        showSaveError(context);
                        setState(() => saving = false);
                      }
                    }
                  },
            child: Text(Tr.t(saved ? 'updateRating' : 'saveRating')),
          ),
          if (saved) ...[
            const SizedBox(height: 8),
            TextButton(
              key: const Key('closeRating'),
              onPressed: () => Navigator.pop(context),
              child: Text(Tr.t('close')),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            Tr.t('localNote'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: JuriTheme.muted),
          ),
          const SizedBox(height: 8),
          Text(
            Tr.t('affiliationSnapshot'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: JuriTheme.muted),
          ),
        ],
      ),
    );
  }

  Widget _attribute(AttributeDef attr, AppScope scope) {
    final value = attrs[attr.key];
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(attr.label, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              Text(
                value == null ? Tr.t('emptyScore') : formatScore(value),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  attr.prompt,
                  style: const TextStyle(
                    fontSize: 11,
                    color: JuriTheme.muted,
                  ),
                ),
              ),
              Tooltip(
                message: attr.tooltip,
                triggerMode: TooltipTriggerMode.tap,
                showDuration: const Duration(seconds: 6),
                child: const Padding(
                  padding: EdgeInsets.only(left: 8, top: 2),
                  child: Icon(
                    Icons.info_outline,
                    size: 15,
                    color: JuriTheme.muted,
                  ),
                ),
              ),
            ],
          ),
          _stepper(
            value: value,
            onChanged: (v) {
              scope.tick();
              setState(() => attrs[attr.key] = v);
            },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: value == null
                  ? null
                  : () => setState(() => attrs[attr.key] = null),
              child: Text(Tr.t('cannotRate')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepper({
    required double? value,
    required ValueChanged<double>? onChanged,
    Key? sliderKey,
    Key? plusKey,
    Key? minusKey,
  }) {
    final display = value ?? 5.5;
    return Column(
      children: [
        Slider(
          key: sliderKey,
          min: 1,
          max: 10,
          divisions: 18,
          value: display,
          label: formatScore(display),
          onChanged: onChanged == null
              ? null
              : (v) => onChanged(snapHalf(v)),
        ),
        Row(
          children: [
            IconButton(
              key: minusKey,
              onPressed: onChanged == null
                  ? null
                  : () => onChanged(snapHalf((value ?? 6) - 0.5).clamp(1, 10)),
              icon: const Icon(Icons.remove),
              tooltip: Tr.t('lower'),
            ),
            const Spacer(),
            IconButton(
              key: plusKey,
              onPressed: onChanged == null
                  ? null
                  : () => onChanged(snapHalf((value ?? 5) + 0.5).clamp(1, 10)),
              icon: const Icon(Icons.add),
              tooltip: Tr.t('higher'),
            ),
          ],
        ),
      ],
    );
  }
}
