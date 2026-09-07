#!/usr/bin/env python3
import json
from datetime import datetime, timezone
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "data" / "demo_matches.json"

OUTFIELD = [
    "teknik",
    "pas",
    "hucum_katkisi",
    "savunma_katkisi",
    "topsuz_oyun",
    "ikili_mucadele",
    "karar_verme",
    "efor",
    "sogukkanlilik",
    "takim_oyunu",
]
GK = [
    "teknik",
    "pas",
    "karar_verme",
    "efor",
    "sogukkanlilik",
    "takim_oyunu",
    "sut_kurtarma",
    "hava_toplari",
    "bire_bir",
    "alan_kontrolu",
]

USERS = [
    ("seed-01", "Ada Kaya", "3604"),
    ("seed-02", "Deniz Arslan", "3604"),
    ("seed-03", "Ege Demir", "3604"),
    ("seed-04", "Lara Çetin", "3604"),
    ("seed-05", "Kerem Aydın", "3604"),
    ("seed-06", "Selin Koç", "3604"),
    ("seed-07", "Mert Uçar", "3604"),
    ("seed-08", "Yağmur Eren", "3604"),
    ("seed-09", "Baran Şen", "3592"),
    ("seed-10", "İpek Yurt", "3592"),
    ("seed-11", "Onur Kılıç", "3592"),
    ("seed-12", "Cemre Aksoy", "3592"),
    ("seed-13", "Tuna Erdem", "3592"),
    ("seed-14", "Nilay Öz", "3592"),
    ("seed-15", "Berkay Can", "3590"),
    ("seed-16", "Sude Kara", "3590"),
    ("seed-17", "Emre Taş", "3590"),
    ("seed-18", "Cansu Gül", "3590"),
    ("seed-19", "Rüzgar Polat", "3596"),
    ("seed-20", "Melis Kurt", "3596"),
    ("seed-21", "Hakan Nur", "3596"),
    ("seed-22", "Ela Sönmez", "3665"),
    ("seed-23", "Yiğit Baş", "3600"),
    ("seed-24", "Duru Akın", "51"),
    ("seed-25", "Alp Tekin", "3597"),
]


def snap(v):
    return round(v * 2) / 2


def attrs(keys, base, skip=(), jitter=0.0):
    out = {}
    for i, key in enumerate(keys):
        if key in skip:
            continue
        if (i + int(base * 10)) % 7 == 0 and jitter >= 0:
            continue
        out[key] = snap(max(1, min(10, base + ((i % 5) - 2) * 0.5)))
    return out


def review(rid, user, appearance, score, keys, note=None, edited=None, skip=(), when=None):
    u = next(x for x in USERS if x[0] == user)
    item = {
        "id": rid,
        "userId": user,
        "appearanceId": appearance,
        "genelPuan": snap(score),
        "attributes": attrs(keys, score, skip=skip),
        "juriNotu": note,
        "supporterClubId": u[2],
        "createdAt": when or "2026-08-25T21:00:00Z",
        "editedAt": edited,
        "valid": True,
    }
    return item


def appearance(match_id, player_id, club_id, role="starter", minutes=90, template="outfield.v1",
               unresolved=False, note=None, verified=True):
    return {
        "id": f"a-{match_id}-{player_id}",
        "matchId": match_id,
        "playerId": player_id,
        "clubId": club_id,
        "role": role,
        "minutes": None if unresolved else minutes,
        "minutesUnresolved": unresolved,
        "template": template,
        "verified": verified,
        "positionNote": note,
    }


matches = [
    {
        "id": "demo-ts-fb",
        "competition": "Süper Lig",
        "season": "2026–2027",
        "homeClubId": "3596",
        "awayClubId": "3592",
        "kickoff": "2026-08-10T18:00:00Z",
        "status": "finished",
        "homeGoals": 1,
        "awayGoals": 1,
        "isDemo": True,
        "events": [
            {"minute": 34, "type": "goal", "playerId": "1792008", "clubId": "3596"},
            {"minute": 71, "type": "goal", "playerId": "2823881", "clubId": "3592"},
        ],
    },
    {
        "id": "demo-ts-bjk",
        "competition": "Süper Lig",
        "season": "2026–2027",
        "homeClubId": "3596",
        "awayClubId": "3590",
        "kickoff": "2026-08-17T18:00:00Z",
        "status": "finished",
        "homeGoals": 2,
        "awayGoals": 0,
        "isDemo": True,
        "events": [
            {"minute": 19, "type": "goal", "playerId": "1792008", "clubId": "3596"},
            {"minute": 77, "type": "goal", "playerId": "1792008", "clubId": "3596"},
        ],
    },
    {
        "id": "demo-gs-fb",
        "competition": "Süper Lig",
        "season": "2026–2027",
        "homeClubId": "3604",
        "awayClubId": "3592",
        "kickoff": "2026-08-24T19:00:00Z",
        "status": "finished",
        "homeGoals": 3,
        "awayGoals": 1,
        "isDemo": True,
        "events": [
            {"minute": 12, "type": "goal", "playerId": "2690888", "clubId": "3604"},
            {"minute": 41, "type": "goal", "playerId": "1462850", "clubId": "3604"},
            {"minute": 63, "type": "goal", "playerId": "2823881", "clubId": "3592"},
            {"minute": 88, "type": "goal", "playerId": "2690888", "clubId": "3604"},
        ],
    },
    {
        "id": "demo-gs-bjk",
        "competition": "Süper Lig",
        "season": "2026–2027",
        "homeClubId": "3604",
        "awayClubId": "3590",
        "kickoff": "2026-08-31T19:00:00Z",
        "status": "finished",
        "homeGoals": 2,
        "awayGoals": 2,
        "isDemo": True,
        "events": [
            {"minute": 8, "type": "goal", "playerId": "2690888", "clubId": "3604"},
            {"minute": 29, "type": "goal", "playerId": "2217597", "clubId": "3590"},
            {"minute": 54, "type": "goal", "playerId": "2217597", "clubId": "3590"},
            {"minute": 81, "type": "goal", "playerId": "2685640", "clubId": "3604"},
        ],
    },
    {
        "id": "demo-gs-ts",
        "competition": "Süper Lig",
        "season": "2026–2027",
        "homeClubId": "3604",
        "awayClubId": "3596",
        "kickoff": "2026-09-14T17:00:00Z",
        "status": "finished",
        "homeGoals": 1,
        "awayGoals": 0,
        "isDemo": True,
        "events": [
            {"minute": 67, "type": "goal", "playerId": "2690888", "clubId": "3604"},
        ],
    },
    {
        "id": "demo-gs-bsh",
        "competition": "Süper Lig",
        "season": "2026–2027",
        "homeClubId": "3604",
        "awayClubId": "3665",
        "kickoff": "2026-09-21T17:00:00Z",
        "status": "finished",
        "homeGoals": 2,
        "awayGoals": 0,
        "isDemo": True,
        "events": [
            {"minute": 22, "type": "goal", "playerId": "2690888", "clubId": "3604"},
            {"minute": 86, "type": "goal", "playerId": "2174480", "clubId": "3604"},
        ],
    },
    {
        "id": "demo-gs-kon",
        "competition": "Süper Lig",
        "season": "2026–2027",
        "homeClubId": "3604",
        "awayClubId": "3600",
        "kickoff": "2026-09-28T17:00:00Z",
        "status": "finished",
        "homeGoals": 1,
        "awayGoals": 1,
        "isDemo": True,
        "events": [
            {"minute": 39, "type": "goal", "playerId": "2935561", "clubId": "3604"},
        ],
    },
    {
        "id": "demo-gs-ala",
        "competition": "Süper Lig",
        "season": "2026–2027",
        "homeClubId": "3604",
        "awayClubId": "51",
        "kickoff": "2026-10-05T17:00:00Z",
        "status": "upcoming",
        "homeGoals": None,
        "awayGoals": None,
        "isDemo": True,
        "events": [],
    },
    {
        "id": "demo-gs-sam",
        "competition": "Süper Lig",
        "season": "2026–2027",
        "homeClubId": "3604",
        "awayClubId": "3597",
        "kickoff": "2026-10-12T17:00:00Z",
        "status": "postponed",
        "homeGoals": None,
        "awayGoals": None,
        "isDemo": True,
        "events": [],
    },
]

appearances = [
    appearance("demo-ts-fb", "1136213", "3596", template="goalkeeper.v1"),
    appearance("demo-ts-fb", "1792008", "3596"),
    appearance("demo-ts-fb", "2823881", "3592"),
    appearance("demo-ts-bjk", "1136213", "3596", template="goalkeeper.v1"),
    appearance("demo-ts-bjk", "1792008", "3596"),
    appearance("demo-ts-bjk", "2217597", "3590"),
    appearance("demo-gs-fb", "1136213", "3604", template="goalkeeper.v1"),
    appearance("demo-gs-fb", "2690888", "3604"),
    appearance("demo-gs-fb", "2698504", "3604", note="Hücum bek"),
    appearance("demo-gs-fb", "2419707", "3604", note="Savunma orta sahası"),
    appearance("demo-gs-fb", "1048397", "3604"),
    appearance("demo-gs-fb", "1462850", "3604"),
    appearance("demo-gs-fb", "2685640", "3604"),
    appearance("demo-gs-fb", "2823881", "3592"),
    appearance("demo-gs-fb", "2935081", "3592"),
    appearance("demo-gs-fb", "2036948", "3592", template="goalkeeper.v1"),
    appearance("demo-gs-bjk", "1136213", "3604", template="goalkeeper.v1"),
    appearance("demo-gs-bjk", "2690888", "3604"),
    appearance("demo-gs-bjk", "2685640", "3604"),
    appearance("demo-gs-bjk", "2217597", "3590"),
    appearance("demo-gs-ts", "1136213", "3604", template="goalkeeper.v1"),
    appearance("demo-gs-ts", "2690888", "3604"),
    appearance("demo-gs-bsh", "2690888", "3604"),
    appearance("demo-gs-bsh", "2174480", "3604", role="substitute", minutes=8),
    appearance("demo-gs-bsh", "2023994", "3604", role="unusedSubstitute", minutes=0),
    appearance("demo-gs-kon", "2690888", "3604"),
    appearance("demo-gs-kon", "2935561", "3604"),
    appearance("demo-gs-kon", "1944296", "3604"),
    appearance("demo-gs-kon", "2117517", "3604", unresolved=True),
    appearance("demo-gs-ala", "2690888", "3604"),
    appearance("demo-gs-sam", "2690888", "3604"),
]

reviews = []

# Osimhen derby: 22 reviews, GS 8 high, others lower
osimhen_fb = "a-demo-gs-fb-2690888"
gs_scores = [8.0, 8.5, 9.0, 8.5, 9.5, 8.0, 9.0, 8.5]
other_scores = [5.0, 4.5, 6.0, 5.5, 4.0, 6.5, 5.0, 5.5, 6.0, 4.5, 5.0, 7.0, 5.5, 6.0]
notes = {
    "seed-01": "İlk dokunuşları ve koşu zamanlaması maçı taşıdı.",
    "seed-09": "Gol attı ama genel katkı abartıldığı kadar yüksek değildi.",
    "seed-15": "Eforu yüksekti; kararları aceleydi.",
}
for i, score in enumerate(gs_scores):
    user = f"seed-{i+1:02d}"
    reviews.append(
        review(
            f"r-gs-fb-osimhen-{user}",
            user,
            osimhen_fb,
            score,
            OUTFIELD,
            note=notes.get(user),
            edited="2026-08-26T10:15:00Z" if user == "seed-01" else None,
            when="2026-08-24T21:30:00Z",
        )
    )
for i, score in enumerate(other_scores):
    user = f"seed-{i+9:02d}"
    reviews.append(
        review(
            f"r-gs-fb-osimhen-{user}",
            user,
            osimhen_fb,
            score,
            OUTFIELD,
            note=notes.get(user),
            skip=("efor",) if i % 3 == 0 else (),
            when="2026-08-24T22:00:00Z",
        )
    )

# Osimhen vs BJK: 8 general, 3 GS — club does not qualify
osimhen_bjk = "a-demo-gs-bjk-2690888"
for user, score in [
    ("seed-01", 8.0),
    ("seed-02", 7.5),
    ("seed-03", 8.5),
    ("seed-09", 5.0),
    ("seed-15", 5.5),
    ("seed-16", 6.0),
    ("seed-19", 6.5),
    ("seed-22", 5.5),
]:
    reviews.append(
        review(
            f"r-gs-bjk-osimhen-{user}",
            user,
            osimhen_bjk,
            score,
            OUTFIELD,
            when="2026-08-31T21:20:00Z",
        )
    )

# Osimhen vs TS: 6 reviews, 5 GS
for user, score in [
    ("seed-01", 7.5),
    ("seed-02", 8.0),
    ("seed-04", 7.0),
    ("seed-05", 8.5),
    ("seed-06", 7.5),
    ("seed-19", 6.0),
]:
    reviews.append(
        review(
            f"r-gs-ts-osimhen-{user}",
            user,
            "a-demo-gs-ts-2690888",
            score,
            OUTFIELD,
            when="2026-09-14T19:10:00Z",
        )
    )

# Osimhen vs BŞH: 5 GS
for user, score in [
    ("seed-01", 8.0),
    ("seed-03", 7.5),
    ("seed-04", 8.0),
    ("seed-07", 7.0),
    ("seed-08", 8.5),
]:
    reviews.append(
        review(
            f"r-gs-bsh-osimhen-{user}",
            user,
            "a-demo-gs-bsh-2690888",
            score,
            OUTFIELD,
            when="2026-09-21T19:05:00Z",
        )
    )

# Osimhen vs Kon: 7, 6 GS
for user, score in [
    ("seed-01", 6.5),
    ("seed-02", 7.0),
    ("seed-03", 6.0),
    ("seed-05", 7.5),
    ("seed-07", 6.5),
    ("seed-08", 7.0),
    ("seed-23", 5.5),
]:
    reviews.append(
        review(
            f"r-gs-kon-osimhen-{user}",
            user,
            "a-demo-gs-kon-2690888",
            score,
            OUTFIELD,
            when="2026-09-28T19:00:00Z",
        )
    )

# Uğurcan TS vs FB: 6, 5 TS, no one-on-ones
for user, score in [
    ("seed-19", 7.5),
    ("seed-20", 8.0),
    ("seed-21", 7.0),
    ("seed-01", 7.5),
    ("seed-09", 6.5),
    ("seed-20", 8.0),
]:
    pass

ugurcan_ts_fb = [
    ("seed-19", 7.5),
    ("seed-20", 8.0),
    ("seed-21", 7.0),
    ("seed-01", 7.5),
    ("seed-09", 6.5),
    ("seed-22", 7.0),
]
for user, score in ugurcan_ts_fb:
    reviews.append(
        review(
            f"r-ts-fb-ugurcan-{user}",
            user,
            "a-demo-ts-fb-1136213",
            score,
            GK,
            skip=("bire_bir",),
            note="Karşı karşıya gelmedi; çıkışları sakin, dağıtımı temizdi."
            if user == "seed-19"
            else None,
            when="2026-08-10T20:10:00Z",
        )
    )

for user, score in [
    ("seed-19", 8.0),
    ("seed-20", 7.5),
    ("seed-21", 8.5),
    ("seed-15", 6.5),
    ("seed-16", 7.0),
]:
    reviews.append(
        review(
            f"r-ts-bjk-ugurcan-{user}",
            user,
            "a-demo-ts-bjk-1136213",
            score,
            GK,
            when="2026-08-17T20:05:00Z",
        )
    )

for user, score in [
    ("seed-01", 7.0),
    ("seed-02", 7.5),
    ("seed-03", 8.0),
    ("seed-04", 7.0),
    ("seed-05", 7.5),
    ("seed-09", 6.0),
]:
    reviews.append(
        review(
            f"r-gs-fb-ugurcan-{user}",
            user,
            "a-demo-gs-fb-1136213",
            score,
            GK,
            when="2026-08-24T21:40:00Z",
        )
    )

for user, score in [
    ("seed-01", 6.5),
    ("seed-02", 7.0),
    ("seed-06", 6.0),
    ("seed-07", 7.5),
    ("seed-08", 7.0),
]:
    reviews.append(
        review(
            f"r-gs-bjk-ugurcan-{user}",
            user,
            "a-demo-gs-bjk-1136213",
            score,
            GK,
            when="2026-08-31T21:30:00Z",
        )
    )

for user, score in [
    ("seed-01", 8.0),
    ("seed-02", 8.5),
    ("seed-03", 7.5),
    ("seed-04", 8.0),
    ("seed-05", 7.5),
    ("seed-19", 6.5),
    ("seed-20", 6.0),
    ("seed-08", 8.0),
]:
    reviews.append(
        review(
            f"r-gs-ts-ugurcan-{user}",
            user,
            "a-demo-gs-ts-1136213",
            score,
            GK,
            when="2026-09-14T19:20:00Z",
        )
    )

# Sallai attacking FB + Torreira defensive mid — same outfield template
for user, score in [
    ("seed-01", 7.5),
    ("seed-02", 8.0),
    ("seed-03", 7.0),
    ("seed-04", 8.5),
    ("seed-05", 7.5),
    ("seed-09", 6.0),
]:
    reviews.append(
        review(
            f"r-gs-fb-sallai-{user}",
            user,
            "a-demo-gs-fb-2698504",
            score,
            OUTFIELD,
            note="Bek gibi durmadı; kanatta sürekli bindirdi." if user == "seed-02" else None,
            when="2026-08-24T21:50:00Z",
        )
    )
    reviews.append(
        review(
            f"r-gs-fb-torreira-{user}",
            user,
            "a-demo-gs-fb-2419707",
            score - 0.5 if score > 1.5 else score,
            OUTFIELD,
            note="Orta sahadan çok savunma hattını toparladı." if user == "seed-03" else None,
            when="2026-08-24T21:55:00Z",
        )
    )

# Other derby participants
for player, users in [
    ("1048397", [("seed-01", 7.0), ("seed-02", 6.5), ("seed-04", 7.5), ("seed-06", 7.0), ("seed-08", 6.5), ("seed-10", 5.5)]),
    ("1462850", [("seed-01", 8.0), ("seed-03", 8.5), ("seed-05", 7.5), ("seed-07", 8.0), ("seed-08", 7.5), ("seed-11", 6.0)]),
    ("2685640", [("seed-02", 7.5), ("seed-03", 7.0), ("seed-04", 7.5), ("seed-06", 8.0), ("seed-07", 7.0), ("seed-12", 6.5)]),
    ("2823881", [("seed-09", 7.5), ("seed-10", 8.0), ("seed-11", 7.0), ("seed-12", 7.5), ("seed-13", 8.0), ("seed-01", 6.0)]),
]:
    for user, score in users:
        reviews.append(
            review(
                f"r-gs-fb-{player}-{user}",
                user,
                f"a-demo-gs-fb-{player}",
                score,
                OUTFIELD,
                when="2026-08-24T22:10:00Z",
            )
        )

# Kökçü vs GS
for user, score in [
    ("seed-15", 8.0),
    ("seed-16", 7.5),
    ("seed-17", 8.5),
    ("seed-18", 7.0),
    ("seed-01", 6.0),
    ("seed-09", 6.5),
]:
    reviews.append(
        review(
            f"r-gs-bjk-kokcu-{user}",
            user,
            "a-demo-gs-bjk-2217597",
            score,
            OUTFIELD,
            when="2026-08-31T21:40:00Z",
        )
    )

# Short sub Ada — 5 reviews, not season eligible
for user, score in [
    ("seed-01", 7.5),
    ("seed-02", 8.0),
    ("seed-03", 7.0),
    ("seed-04", 7.5),
    ("seed-05", 8.0),
]:
    reviews.append(
        review(
            f"r-gs-bsh-ada-{user}",
            user,
            "a-demo-gs-bsh-2174480",
            score,
            OUTFIELD,
            note="Kısa sürede tek net pozisyonu değerlendirdi." if user == "seed-01" else None,
            when="2026-09-21T19:20:00Z",
        )
    )

# Unresolved minutes Arda Ünyay — 5 reviews, season pending
for user, score in [
    ("seed-01", 6.5),
    ("seed-02", 6.0),
    ("seed-03", 7.0),
    ("seed-04", 6.5),
    ("seed-06", 6.0),
]:
    reviews.append(
        review(
            f"r-gs-kon-unyay-{user}",
            user,
            "a-demo-gs-kon-2117517",
            score,
            OUTFIELD,
            when="2026-09-28T19:15:00Z",
        )
    )

# Batrakov 1-4 reviews
for user, score in [("seed-01", 7.0), ("seed-02", 6.5), ("seed-23", 6.0)]:
    reviews.append(
        review(
            f"r-gs-kon-batrakov-{user}",
            user,
            "a-demo-gs-kon-2935561",
            score,
            OUTFIELD,
            when="2026-09-28T19:10:00Z",
        )
    )

# Berat Luş: zero reviews — appearance only

payload = {
    "users": [{"id": i, "displayName": n, "clubId": c} for i, n, c in USERS],
    "matches": matches,
    "appearances": appearances,
    "reviews": reviews,
}

OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"wrote {OUT} users={len(USERS)} matches={len(matches)} appearances={len(appearances)} reviews={len(reviews)}")
