#!/usr/bin/env python3
"""Download Süper Lig scores and lineups from Mackolik for a date range."""

from __future__ import annotations

import argparse
import sys
from datetime import date, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tff_scraper.mackolik import MackolikClient, scrape_superlig_matches, write_matches


# First day of the season. Everything from here to today is refetched on each
# run, so the league table and the fixture list are always whole rather than
# accumulated across runs.
SEASON_START = date(2026, 8, 1)


def parse_day(value: str) -> date:
    return date.fromisoformat(value)


def default_end() -> date:
    """Today, plus a fortnight so the upcoming fixtures come along too."""
    return date.today() + timedelta(days=14)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Scrape Süper Lig matches from Mackolik into app-ready JSON."
    )
    parser.add_argument(
        "--from",
        dest="start",
        default=SEASON_START,
        type=parse_day,
        help="Defaults to the start of the season.",
    )
    parser.add_argument(
        "--to",
        dest="end",
        default=None,
        type=parse_day,
        help="Defaults to two weeks out, so upcoming fixtures are included.",
    )
    parser.add_argument(
        "--app",
        default="data/app.json",
        type=Path,
        help="Existing app.json used to map clubs and players.",
    )
    parser.add_argument("--out", default="data/matches.json", type=Path)
    parser.add_argument("--delay", type=float, default=0.6)
    parser.add_argument("--skip-lineups", action="store_true")
    parser.add_argument(
        "--weekends",
        action="store_true",
        default=True,
        help="Only request Thursday–Monday livedata (default).",
    )
    parser.add_argument("--all-days", action="store_true")
    args = parser.parse_args()
    if args.end is None:
        args.end = default_end()
    if args.end < args.start:
        raise SystemExit("--to must be on or after --from")

    client = MackolikClient(delay=args.delay)
    payload = scrape_superlig_matches(
        client,
        start=args.start,
        end=args.end,
        app_path=args.app,
        include_lineups=not args.skip_lineups,
        weekends_only=not args.all_days,
    )
    write_matches(payload, args.out)
    meta = payload["meta"]
    print(
        f"Done. {meta['match_count']} matches, {meta['appearance_count']} appearances "
        f"({meta.get('substitute_count', 0)} came on, "
        f"{meta.get('unused_substitute_count', 0)} unused), "
        f"{meta.get('event_count', 0)} events, "
        f"{meta.get('standing_count', 0)} standings rows, "
        f"{len(meta['unmapped_players'])} unmapped players -> {args.out}",
        flush=True,
    )
    for note in meta.get("standing_notes") or []:
        print(f"  standings check: {note}", flush=True)
    for item in meta["unmapped_players"]:
        print(f"  unmatched {item['matchId']} {item['clubId']} {item['name']}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
