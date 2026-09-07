# Jüri

A Turkish-first Flutter MVP for supporter opinion around Süper Lig players. Built from the product brief in `DESCRIPTION.md`.

## Run

```sh
flutter pub get
flutter run -d 7D7784B8-6A02-460C-B12C-1B5D6BB9A33A
```

The project includes native iOS and Android targets, plus a Flutter web target for development previews. iOS uses Flutter's Swift Package Manager integration for local persistence. Android compilation requires an Android SDK, which is not installed on this machine.

## Implemented

- An Akış tab that is the home surface: league moments folded out of the fixture data, supporters' takes, man-of-the-match polls, rating prompts, and the league's editorial blocks, under **Sana Özel / Takımım / Süper Lig** filters.
- A Sözler tab that is nothing but what people said: takes and their ratings, newest first, under **Hepsi / Takımım / Benim**. Akış is the mixed landing page; Sözler is the one card type, for readers who came to read opinions rather than scroll past furniture.
- Threaded replies to any take, nesting without a fixed limit, with per-branch collapse. Indentation stops stepping after five levels so a deep argument stays readable on a phone while keeping its true shape.
- Up and down votes on takes and on replies, both counts public, second tap clears. A buried take sinks in the feed ranking.
- Club selection with all 18 real badges, animated selection and persistent supporter identity that can be corrected later.
- Editorial home driven by the data itself: your club's latest fixture as the spotlight, the season's top scorers, the standings.
- All 617 players, club profiles, grouped squads, stadium details and career records.
- Player profiles with source photos, hero transitions, age, nationality, registration name, market value, season goals and assists.
- Match pages for the 34 scraped Süper Lig fixtures: a club-tinted scoreboard, a two-sided event timeline, and a team sheet split by club — starting XI grouped into keeper/defence/midfield/attack, confirmed substitutes, and an unconfirmed bench — with goal, assist and card markers per player.
- Every club badge in the app is a link to that club's page, except where a tap already means something else (picking a club in onboarding, a dropdown, or the club's own page).
- Tactile 1–10 ratings in half-point steps across ten role-aware attributes, saved on device and editable in place.
- Community aggregation with published/withheld/low-sample states, club-vs-general splits, per-club spells and a rating distribution under every average.
- A personal ranking that stands in for the community board until real ratings exist.
- A statistics section where every group pairs what the fixture data can count with what only supporters can judge: eleven counted boards (goals, assists, contributions, impact off the bench, yellows, reds, cards per 90, minutes, starts, clean sheets, goals conceded per 90) beside fourteen rated ones (passing, duels, defensive work, effort, composure, shot-stopping and the rest). Filterable by club, tied ranks shared rather than invented, and a board that separates nobody says so.
- Turkish-normalized player/club search; club, position, age and market-value filters.
- Higher/Lower game with missing-value and tie exclusion, streaks and persistent best score.
- Local supporter profile, haptic preference and a full local-data reset.

## The feed

The brief asks for a social feed (§26) and per-player takes (§25). Both are built. The constraint that shaped every decision was that there was no backend and therefore no other supporters — a feed of invented usernames would have been the one place in the app that captions fabricated content as real, which the rating surfaces already refuse to do. So it shipped with no fake people in it.

The server exists now and the feed carries real supporters, but that rule still holds: nothing in it is generated. Every card is either a published fixture fact or something a person actually wrote.

### A take is a rating with a reason

A take is never free-floating text. It hangs off a `MatchReview` for one appearance — one player, one match — which is what makes the supporter badge mean something: *a Galatasaray supporter said this about a Fenerbahçe player, 8,5, in that fixture*. It also rate-limits the feed to football somebody actually watched, and gives it a matchday rhythm instead of a 24/7 timeline.

`juriNotu` already existed on `MatchReview`; `Take` is a view over it, and the composer (`TakeComposerScreen`) writes back through the same `saveReview` path. The composer never asks about the ten attribute ratings, so it carries the existing ones through rather than wiping a full analysis somebody gave on the rating form — a test asserts that.

Takes are capped at 280 characters, on both the composer and the rating form.

### What fills the feed on day one

| item | source | honest because |
| --- | --- | --- |
| League moments | `data/matches.json` | every one restates a published lineup, minute, goal, assist or card |
| Takes | saved reviews, yours from the device and everyone else's from the server | a take that has not reached the server is labelled "kaydedildi, yayınlanmadı" rather than implying an audience |
| Prompts | your unrated fixtures and unexplained scores | asks, never asserts; individually dismissible |
| Polls | the players on a fixture's scoresheet | the vote is stored on device and the card says so; no tally is shown |
| Editorial | standings, fixtures, scorers, spotlight | the same league data the old Home tab carried |

Eleven moment kinds are derived: hat-trick, comeback, late winner, red card, rout, derby, impact off the bench, brace, double assist, clean sheet and a player's first goal of the season.

Two rules keep them from lying:

- **A comeback or a late winner needs a scoreline the events can rebuild.** Four of the thirty-four scraped fixtures publish fewer goal events than their own result, so replaying their events would invent a match that never happened. Those fixtures get no running-score moment. Own goals are credited to the opponent, which is how the source folds them into the score.
- **One moment per player per fixture, and at most three per fixture.** A brace that was also somebody's first goal of the season is one story; the stronger claim wins. Without the per-fixture cap a seven-goal game would push a whole round off the screen.

### Ranking

A pure function over a heterogeneous list, so it is testable without a widget: `weight × recency decay × club affinity`, then a diversity pass that never places two cards about the same player or fixture back to back unless everything remaining shares that subject. "Süper Lig" drops the affinity term so the league tab is the same league for everybody. Editorial blocks are dealt in at fixed depths afterwards.

### What the feed deliberately does not have

No follows, no direct messages, no images, no free-standing text posts — the brief keeps profiles football-centric (§27) and the feed has to match.

Replies were held back for a long time on the reasoning that Turkish football is tribal, takes are aimed at named individuals, and threaded argument is where that becomes a moderation and legal problem. They are in now, and that reasoning did not stop being true — it became the specification. A reply is a row under the same RLS as a take: hidden by moderation or written by somebody you blocked means it is not there, the supporter badge is snapshotted and unforgeable, and `reports` and `blocks` cover replies through the same paths. **The report queue still has nobody reading it**, which is the gap that matters before this is public, not the absence of the feature.

Voting renders only on a take the reader did not write: nobody is invited to applaud themselves.

### Where the backend plugs in

`FeedRepository` is the boundary, mirroring `FootballRepository`: `AppScope.feed` hands widgets a `LocalFeedRepository` built over the football data and local user state, with server takes injected through a callback rather than a second code path. `Take` carries `authorId`, `authorClubId`, `likeCount`, `dislikeCount`, `replyCount`, `myVote` and `published`, and `FeedItem` is a sealed hierarchy, so remote takes and real vote counts drop into the same ranking pass — `weight` is `90 + likes − dislikes`, so a buried take sinks.

## Data and architecture

```
UI → FootballRepository → LocalJsonDataSource → data/app.json + data/matches.json
UI → FeedRepository     → LocalFeedRepository → football data + LocalUserState
```

`lib/data/models.dart` and `lib/data/match_models.dart` hold typed domain models. The repository parses once — on a background isolate, so a 2.4 MB decode never blocks the first frame — then indexes clubs, players, squads, careers, fixtures and appearances by stable identifier. Widgets never parse JSON. Community aggregates are memoised per player and per appearance; they are derived from immutable bundled reviews, so the caches need no invalidation. `FootballRepository` is the boundary for a future remote implementation.

`LocalUserState` wraps SharedPreferences for supporter identity, reviews, takes, likes, poll votes, dismissed prompts, haptics and game records. Writes complete before observable state changes. Onboarding locks the first club choice, but the profile allows a deliberate, confirmed change and a complete wipe of local data.

### What the fixture data does and does not know

`data/matches.json` comes from Mackolik and carries lineups, minutes, substitutions, goals, assists and cards. Earlier snapshots arrived without minutes, so the app still treats participation as something to be proven rather than assumed:

| Source says | App behaviour |
| --- | --- |
| Named in the XI | Confirmed as played. Counts toward season aggregates: a starter withdrawn before the 20th minute is rare enough that excluding every starter would be the larger distortion. |
| On the bench, credited with a goal, assist or card | Confirmed as played and ratable. Excluded from season aggregates, because "came on" alone could mean ninety minutes or ninety seconds. |
| On the bench, no event | Participation unconfirmed. Listed separately, labelled, and not ratable. |

The scraper also reports lineup names it could not map onto a player record (`meta.unmapped_players`); match pages say so instead of silently showing a short squad.

The ranking floor adapts to the season's progress. A full season requires five rated matches; four rounds in, that threshold is unreachable for every player alive, so the repository lowers it to the rounds actually played and never below three. The "rated in at least half your appearances" rule does the real work either way.

### What the statistics section can and cannot rank

Every fixture-derived board is folded from the feed in one pass over finished matches: the appearances carry workload and the keeper numbers, the events carry goals, assists and cards. A few rules are worth stating because they change the answers:

- **Assists are counted once.** The feed emits a standalone `assist` event *and* repeats the passer as `assistPlayerId` on the goal. Only the event is counted; a test asserts the league total against the raw file so the two can never drift.
- **Ties share a rank.** Four rounds in, four players hold one red card each. They are all first. Numbering them 01–04 would invent an order the data does not contain, and a board where nobody separates carries a note saying so — computed over the whole field, not the three-row preview.
- **Rate boards need 270 timed minutes**, and the goals-conceded rate additionally needs three keeper appearances. Below that a per-ninety number is one bad afternoon wearing a disguise.
- **A clean sheet needs the full ninety.** Splitting one between two keepers would credit a shutout to someone who watched half of it from the bench.
- **Unused substitutes reach no board.** Participation has to be proven — by the XI, by minutes, or by an event — before it counts anywhere.

The feed publishes lineups, minutes and five event types (`goal`, `assist`, `own_goal`, `yellow`, `red`) and nothing else. **There is no passing, tackling, saves, shots, dribbles or distance data**, and the Mackolik archive has none to give: `MatchData.aspx?t=dtl` returns lineups, events and squad market value, and the other tab identifiers return empty bodies. So the app ships no board for those qualities rather than a fabricated one.

The rated boards are the answer instead, and they sit inside the same groups rather than in a annexe of their own:

| group | counted | rated |
| --- | --- | --- |
| Hücum | goals, assists, contributions, impact off the bench | hücum katkısı, pas, teknik |
| Savunma | *nothing free exists* | savunma katkısı, ikili mücadele, topsuz oyun |
| Disiplin | yellows, reds, cards per 90 | soğukkanlılık, karar verme |
| Süre ve forma | minutes, starts | efor, takım oyunu |
| Kalecilik | clean sheets, goals conceded per 90 | şut kurtarma, bire bir, hava topları, alan kontrolü |

So "most tackles" is `İkili Mücadele`, "best passer" is `Pas`, "most distance covered" is `Efor` and "most saves" is `Şut Kurtarma` — ranked by the people watching rather than by a counter. Defence is the one group with no counted half, and it is shown that way rather than filled with a guess.

A rated board never merges the two rating templates. Both carry a `pas` attribute, but a keeper's distribution and a midfielder's passing answer different prompts, so `OpinionBoardDef` keys on `templateId:attributeKey` and a test asserts a keeper's passing score cannot reach the outfield board. A community score is used wherever it clears the thresholds; until then the reader's own ratings are ranked and the board says so. `docs/advanced-stats.md` records why no commercial feed will be licensed, with the endpoint probes behind it.

### Community data

Community ratings come from the server: `RemoteTakes.refresh` fetches every review and hands them to `adoptCommunityReviews`, which is the only thing that rebuilds the aggregate and clears the season and leaderboard caches. Every community surface reports its true state — unrated, withheld below the publish threshold, low sample under twenty — and the rankings tab falls back to the reader's own scores rather than showing an empty flagship screen. `hasDemoContent` drives the demo labelling, so real league data is never captioned as a mock-up.

Publishing a rating pulls the community back down (`AppScope._publishAndRecount`). Pushing without pulling left the rankings frozen until the next sign-in, because the aggregator only ever sees rows that came back from the server — the tab looked broken to the first people who used it.

Strings live in `lib/l10n/strings.dart`; the application currently supports Turkish. The football dataset describes the 2026–2027 season and was scraped September 5, 2026; the fixture data covers 7 August – 6 September 2026. Both are snapshots, not a live service.

The original scrapers and source files are preserved on disk but excluded from this repository while it is public, since they target commercial sites. `.gitignore` also excludes `data/` and the cached badge, stadium and portrait assets; a checkout is a record of the application source, not a buildable tree. Enhanced featured portraits and their source URLs are recorded in `assets/portraits/manifest.json`. Font licenses are in `assets/fonts/`.

`tools/cache_assets.py` caches club badges, stadium images and fonts. One source stadium photo (Gençlerbirliği) currently returns 404; the UI omits the image and retains the available stadium facts. Eyüpspor has no stadium record, so no stadium section is shown. `tools/cache_portraits.py` fetches larger versions of six featured portraits without modifying the original dataset.

## Backend

A Supabase project in `eu-west-1`. The schema lives in `supabase/migrations/` and the auth settings in `supabase/config.toml`, so both are reproducible with `supabase db push` and `supabase config push`. Both directories are kept out of this repository while it is public — RLS is the entire security boundary and `config.toml` records which auth protections are currently off.

**The server holds opinions, not football.** `app.json` and `matches.json` stay bundled in the app — the offline dataset is a feature, and it means the database never needs a squad, a fixture or a player row. Reviews key off `appearance_id` as plain text, with `player_id`, `match_id` and `club_id` denormalised alongside purely so the feed can be filtered by club without the server learning the league.

```
UI → FootballRepository → bundled JSON     (players, clubs, fixtures — offline)
UI → FeedRepository     → Supabase         (reviews, takes, replies, votes, polls, reports)
```

### Identity

Auth is email + password underneath, because a password reset needs a real inbox. The username is what the app shows and what people type to log in: `email_for_login(username, password)` resolves one to the other and **returns the email only once the password already matched**, so usernames cannot be walked to harvest addresses — the obvious version of that RPC is an email-harvesting endpoint with extra steps.

Usernames are `^[a-z0-9_]{3,20}$`. ASCII deliberately: Turkish casing is locale-dependent — `İ` lowercases differently under a Turkish locale than an invariant one — so a username with Turkish letters could resolve differently depending on who is asking, and mixed scripts make impersonation trivial in a product about which stand you speak from.

A signup trigger creates the profile; there is no insert policy, so a profile cannot exist without an account or an account without a username.

### Club before anything else

`profiles.supported_club_id` starts null, and the insert policy on `reviews` requires `supporter_club_id` to equal the author's current club. A null never matches, so **a new account cannot post until it picks a club** — the product rule is enforced by the database, not by the screen order. The same policy makes the badge on a take unforgeable: you cannot post as a Fenerbahçe supporter unless you are one.

### What a client may not do

The anon key ships inside the app binary, so RLS is the entire security boundary. Beyond the policies, a trigger pins the columns a client must never move on its own row — `like_count`, `dislike_count`, `reply_count`, `hidden`, `user_id`, `supporter_club_id`, `appearance_id`, `created_at` — because an `UPDATE` policy cannot restrict individual columns. `replies` carries the same guard over its own immutable columns, including the `depth` and `review_id` the server derives from the parent, so a reply cannot be filed under a conversation it is not part of.

Votes are counted from `take_votes` and `reply_votes` by trigger; a client can never write a number nobody earned. `take_votes` was `take_likes` until a vote needed a direction: the rename keeps every row, and the `value` column defaults to `1`, which is what an existing like was.

That guard originally fired on its own like-count trigger and broke liking entirely: `SECURITY DEFINER` changes the acting user but not the `role` PostgREST sets, so the internal write looked like a client write. It now carries a transaction-local flag that only the trigger sets. **Every count trigger must set it** — `sync_like_count`, `sync_reply_count` and `sync_reply_vote_counts` all write a guarded column, and one that forgets reintroduces the same bug.

### Aggregates

`appearance_aggregates` holds `(appearance_id, supporter_club_id)` → count, sum and the five-band distribution, with `''` meaning every supporter. It is recomputed for one appearance on any change rather than updated by deltas: delta arithmetic has to get insert, edit, delete, hide and unhide all right and drifts silently the first time one is missed, and the row set per appearance is bounded by the number of accounts. Attribute scores are read far less often, so they stay a `security_invoker` view until they are actually hot.

### The app on top of it

`main()` initialises Supabase and hands `JuriApp` a client. **Pass no client and the app is exactly the local MVP it was**: bundled football, ratings on the device, no accounts. Every widget test builds it that way, and so does a build with no configuration — losing the server costs the community, not the app.

Routing: restoring a stored session holds the splash, no session shows `AuthScreen`, a session whose profile has no club goes to the existing onboarding, and everything else is the app. The club gate is not a UI convention — the server's insert policy refuses a take whose badge does not match a chosen club, so onboarding writes the club to the server *before* the device.

**Ratings stay offline-first.** `AppScope.saveAndPublish` awaits the local write and does not await the push, so a supporter rating a match on the metro sees the score land immediately and the take reaches everyone else when there is signal. Anything the phone holds is swept up to the server once per sign-in, so a reader who rated matches before making an account keeps every one of them.

The reader's own takes in the feed come from local state, not from the server's echo of them: local is authoritative for your own words, current the instant you save, and there with no signal. Remote takes are merged in, sorted into the same ranking pass, and a take the server echoes back to its author is dropped rather than shown twice.

The publishable key sits in `lib/core/config.dart`, which is gitignored while this repository is public; copy `config.dart.example` and fill it in. The key is public by construction — it ships in every copy of the binary, and RLS is what actually stops it doing anything — but a key sitting in a public repo is harvested by automated scanners in a way a minified bundle is not. Both it and the URL can be overridden with `--dart-define`.

### Verified against the live project

Signup → profile trigger → username uniqueness → login-by-username → club selection → post a take → aggregate row with the right distribution → vote up → flip to down → clear. Plus the refusals: posting before choosing a club, claiming a club you do not support, awarding yourself likes, hiding your own take, and calling the aggregate-refresh function.

### Not wired yet

**Nothing reads `appearance_aggregates`.** The server computes and stores it correctly, but the client aggregates on the device instead, from the raw reviews `refresh` fetches. That works and keeps one aggregator rather than two, at the cost of pulling every review to every device — fine for a pilot, not for a league. Moving the read to the server table is the change that scales, and the one that makes a supporter-split card cheap.

The signup screen itself has not been driven end to end on a device: every server call it makes is verified by the checks above, and the screen renders, but nothing has typed into it except me reading the code.

### Before this is public

- **Custom SMTP** (Resend, Postmark, SES) and email confirmation, which the pilot configuration relaxes so testers can sign up instantly. The shared Supabase sender allows only a couple of emails an hour, which is not a password-reset flow.
- **Captcha** on signup (`[auth.captcha]`, hCaptcha or Turnstile) and leaked-password protection.
- **Account deletion** — an App Store requirement for accounts, and it needs an Edge Function with `service_role`.
- **Moderation** — `reports`, `blocks` and `hidden` exist, but nothing reads the report queue yet. Apple rejects user-generated-content apps without a report path, a block path and a stated moderation commitment.
- **KVKK** — privacy policy, consent text, data export, and standard contractual clauses for storing Turkish users' data in Ireland.
- **MFA TOTP** was enabled by default and `config push` turned it off; nobody had enrolled. Re-enable in `config.toml` if you want it.

## Thresholds and pilot mode

`lib/data/thresholds.dart` holds the numbers that decide when a score is honest enough to show: five ratings on one appearance before it publishes, three rated matches before a season score, five before a player can be ranked.

A ten-person pilot cannot clear those. Five ratings on the *same player in the same match*, across 617 players and 34 fixtures, is a threshold built for thousands of supporters. So there is a pilot mode, and it is deliberately **a build flag, not an edited constant** — "we'll put it back before launch" is the kind of promise that gets forgotten, whereas a default of `false` means a release build has the real thresholds unless somebody asks otherwise:

```sh
flutter build web --dart-define=PILOT_MODE=true   # publish at 2, season at 1, rank at 1
```

`tools/deploy_web.sh` sets it, so **every GitHub Pages build a tester sees is running pilot numbers.** Nothing about the honesty machinery changes underneath: a two-rating score still carries the low-sample caption, the distribution bars still show the shape, and a club score still needs its own supporters. The bar moves; the labelling does not, and the copy interpolates the live threshold rather than hard-coding a number that would lie in one of the two builds.

**Run the suite both ways.** Plain `flutter test` exercises the production thresholds; the deployed configuration needs its own run:

```sh
flutter test
flutter test --dart-define=PILOT_MODE=true
```

Skipping the second is how the rankings tab shipped broken: `CommunityAggregator.season` kept its own hardcoded copies of the numbers, so under pilot thresholds a score reported `published` with no `mean`, and every `.mean!` in the ranking paths threw — the release error widget replaced the whole screen. Never hardcode a threshold; read it from `Thresholds`, `seasonScoreFloor` or `seasonRankingFloor`. `pilot_thresholds_test.dart` holds the guard that a published score always carries a mean.

The ranking floor adapts on its own: with four rounds played, `rankingMinimumMatches` lowers the five-match rule to three rather than ranking nobody.

## Accessibility

Text scaling is honoured up to 1.35×; above that the layout is dense enough that headline blocks and score cards would clip, so the multiplier is clamped rather than allowed to break the page. The navigation bar takes a tighter 1.1× ceiling of its own: six destinations do not fit six scaled-up labels on a 390pt phone, and the bar is chrome rather than content — every destination keeps its icon and its semantic label. Grid extents and card heights scale with the reader's setting. `journey_test.dart` and `posts_and_replies_test.dart` walk every tab and every detail screen at an above-clamp scale factor and fail on any render overflow.

Widget tests that measure layout must load the real fonts in `setUpAll`; the fallback test font has different metrics and reports overflows the app does not have.

## Validation

```sh
dart analyze lib test
flutter test
flutter test --dart-define=PILOT_MODE=true   # the configuration that actually ships
flutter build ios --simulator --debug
```

Use `dart analyze lib test` directly: the installed Flutter 3.44.3 `flutter analyze` wrapper encounters an LSP encoding error with the accented workspace path. Direct Dart analysis works.

Tests cover the feed (moment derivation against a direct count over the raw file, the running-score gate, the per-fixture cap, the club filter, the diversity pass, that no take in the feed is anybody but the reader, and that the composer preserves attribute ratings), data relationships and asset completeness, the background decode path, Turkish search, birthday boundaries, unknown values, participation evidence, the season-aware ranking floor, aggregation thresholds and equal match weighting, game correctness/ties/streaks, persistence, identity change and reset, layout under text scaling, and the onboarding → match → rating → search → game → profile journey.

## Next product milestone

The backend and the ten-person supporter test are live: real accounts, server-side reviews, published takes with real vote counts, and threaded replies all ship. What remains outside this implementation is **a moderator actually reading the `reports` queue**, account deletion, sharing, fantasy and app-store distribution — the first of those gates any public release, not just the App Store review.

Reading `appearance_aggregates` instead of aggregating on device is the change that lets the community outgrow a pilot. Minutes and substitution events are the highest-value data addition: they would move every confirmed substitute into the season aggregate. Android build verification awaits an installed Android SDK.
