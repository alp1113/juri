import 'package:flutter/material.dart';
import '../app/scope.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../l10n/strings.dart';
import '../shared/widgets.dart';
import 'players.dart';

class ClubsScreen extends StatefulWidget {
  const ClubsScreen({super.key});
  @override
  State<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends State<ClubsScreen> {
  String query = '';
  bool table = false;
  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    final clubs = repo.clubs
        .where((c) => normalizeSearch(c.name).contains(normalizeSearch(query)))
        .toList();
    final visible = {for (final c in clubs) c.id};
    final table_ = repo.standings
        .where((s) => visible.contains(s.clubId))
        .toList();
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(
                  '${repo.meta.season} · SÜPER LİG',
                  color: JuriTheme.gold,
                ),
                const SizedBox(height: 14),
                Headline(Tr.t('clubTitle'), size: 54),
                const SizedBox(height: 12),
                Text(
                  Tr.t('clubSubtitle'),
                  style: const TextStyle(color: JuriTheme.muted),
                ),
                const SizedBox(height: 24),
                TextField(
                  onChanged: (v) => setState(() => query = v),
                  decoration: InputDecoration(
                    hintText: Tr.t('search'),
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ChoiceChip(
                      label: Text(Tr.t('clubs')),
                      selected: !table,
                      onSelected: (_) => setState(() => table = false),
                    ),
                    ChoiceChip(
                      label: Text(Tr.t('standings')),
                      selected: table,
                      onSelected: (_) => setState(() => table = true),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
        if (clubs.isEmpty)
          SliverToBoxAdapter(
            child: EmptyView(
              title: Tr.t('noResults'),
              body: Tr.t('noResultsBody'),
            ),
          ),
        if (table)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList.builder(
              itemCount: table_.length,
              itemBuilder: (context, i) => StandingRow(
                standing: table_[i],
                club: repo.club(table_[i].clubId),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) => SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: constraints.crossAxisExtent > 650 ? 4 : 2,
                  mainAxisExtent:
                      177 * MediaQuery.textScalerOf(context).scale(1),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate((context, i) {
                  final c = clubs[i];
                  final s = repo.standing(c.id);
                  return Pressable(
                    onTap: () => openPage(context, ClubScreen(club: c)),
                    child: Container(
                      padding: const EdgeInsets.all(17),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [
                            JuriTheme.clubColor(c.id).withValues(alpha: .09),
                            JuriTheme.surface,
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ClubBadge(c, size: 43),
                              const Spacer(),
                              Text(
                                s == null
                                    ? '—'
                                    : s.rank.toString().padLeft(2, '0'),
                                style: const TextStyle(
                                  fontFamily: 'BarlowCondensed',
                                  fontSize: 30,
                                  color: JuriTheme.muted,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            c.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c.city,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: JuriTheme.muted,
                                  ),
                                ),
                              ),
                              Text(
                                '${s?.points ?? '—'} P',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: JuriTheme.gold,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }, childCount: clubs.length),
              ),
            ),
          ),
      ],
    );
  }
}

class StandingRow extends StatelessWidget {
  final Standing standing;
  final Club club;
  const StandingRow({super.key, required this.standing, required this.club});
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: () => openPage(context, ClubScreen(club: club)),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: JuriTheme.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              standing.rank.toString().padLeft(2, '0'),
              style: const TextStyle(color: JuriTheme.muted, fontSize: 11),
            ),
          ),
          ClubBadge(club, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              club.name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          Text(
            '${standing.played} O',
            style: const TextStyle(color: JuriTheme.muted, fontSize: 11),
          ),
          const SizedBox(width: 25),
          Text(
            '${standing.points}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ],
      ),
    ),
  );
}

const _groups = <String?>['GK', 'DF', 'MF', 'FW', null];

void openClub(BuildContext context, Club club) =>
    openPage(context, ClubScreen(club: club));

class ClubScreen extends StatelessWidget {
  final Club club;
  const ClubScreen({super.key, required this.club});
  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    final squad = repo.squad(club.id);
    final grouped = {
      for (final group in _groups)
        group: squad
            .where(
              (p) => group == null
                  ? !_groups.contains(p.positionGroup)
                  : p.positionGroup == group,
            )
            .toList(),
    };
    final stadium = repo.stadium(club.id);
    final standing = repo.standing(club.id);
    return Scaffold(
      appBar: AppBar(title: Eyebrow(Tr.t('clubs').toUpperCase())),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: RadialGradient(
                        center: Alignment.topRight,
                        radius: 1.3,
                        colors: [
                          JuriTheme.clubColor(club.id).withValues(alpha: .2),
                          JuriTheme.surface,
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ClubBadge(club, size: 75, linked: false),
                            const Spacer(),
                            Eyebrow('${repo.meta.season}\nSÜPER LİG'),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Headline(club.name.toUpperCase(), size: 46),
                        const SizedBox(height: 8),
                        Text(
                          club.city,
                          style: const TextStyle(color: JuriTheme.muted),
                        ),
                        if (standing != null) ...[
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              _stat(Tr.t('rankings'), '${standing.rank}.'),
                              _stat(Tr.t('points'), '${standing.points}'),
                              _stat(Tr.t('played'), '${standing.played}'),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Text(
                            '${standing.won} ${Tr.t('won')} · ${standing.drawn} ${Tr.t('drawn')} · ${standing.lost} ${Tr.t('lost')}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: JuriTheme.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SectionHeading('${Tr.t('squad')} · ${squad.length}'),
                ],
              ),
            ),
          ),
          for (final group in _groups) ...[
            if (grouped[group]!.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 6),
                sliver: SliverToBoxAdapter(
                  child: Eyebrow(
                    Tr.group(group).toUpperCase(),
                    color: JuriTheme.gold,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList.builder(
                  itemCount: grouped[group]!.length,
                  itemBuilder: (context, i) {
                    final p = grouped[group]![i];
                    return PlayerRow(
                      key: Key('squad-${p.id}'),
                      player: p,
                      club: club,
                      hero: true,
                      onTap: () => openPlayer(context, p),
                    );
                  },
                ),
              ),
            ],
          ],
          if (stadium != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeading(Tr.t('stadium')),
                    if (stadium.hasPhoto)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          stadium.photo,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, e, s) => const SizedBox.shrink(),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      stadium.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (stadium.capacity != null)
                          _stat(Tr.t('capacity'), '${stadium.capacity}'),
                        if (stadium.pitch != null)
                          _stat(Tr.t('pitch'), stadium.pitch!),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: JuriTheme.muted),
        ),
      ],
    ),
  );
}
