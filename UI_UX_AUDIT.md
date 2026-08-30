# AI Rally Search — UI/UX Audit

> Scope: **Product UI/UX audit + redesign plan only.** No code, backend, API contract,
> search semantics, model, or navigation-logic changes are proposed for implementation in
> this pass. The search architecture (Flutter → FastAPI → QU → SearchPlan → MySQL) is
> treated as fixed and correct. See §26 for the protected list.
>
> **Product decision (supersedes the original single-mic recommendation): BOTH voice
> modes are intentionally retained.** The two voice inputs — "Cloud voice" and "On-device
> voice" — are a deliberate product choice, not dev A/B scaffolding. The redesign keeps both
> fully operational and independent; it removes only the *developer framing* (provider/model
> names, "Native"/"Whisper" wording, and the transcript-provenance line) and re-presents them
> as two clearly labelled, product-facing input modes. Wherever this document earlier said to
> "collapse to one mic", read it as: **keep both, restyle both, strip the debug framing.**
> (Implemented in Phase 1.)

---

## 1. Executive Summary

The backend is a well-architected, safety-first natural-language search engine. The **front
end does not present it as one.** The app currently opens on a technical database registry
(`RallyStreamsPage` — "Database Video Player Registry"), and the AI search — the actual
product — is a secondary screen reached by an app-bar button. When you do reach it, the
search experience leaks its own internals: **two visible voice buttons** ("Native Voice" /
"Cloud Whisper"), a **cost + latency telemetry chip** ("852ms · $0.0003") opening a dialog
with provider name, model, token counts, entity-resolution timings, and raw `SearchQuery`
JSON, and an interpreted-summary string built in schema shape
(`Search Video Actions (jump) | Driver: … | Rally: …`).

None of this is a backend problem. The pipeline does the right thing; the UI narrates the
plumbing instead of the answer. The redesign goal is to make one search-first surface the
whole product, hide every internal concept behind it, and give each of the nine result
intents a purpose-built card rather than a generic one (this part is already largely done and
is a genuine strength — see §3).

**Three things to fix first**

1. Make search the front door (promote `GeneralSearchScreen`, demote the streams registry to
   an optional "Browse" area) and give it a real first-launch hero state.
2. Re-present the two voice buttons as **intentional product modes** ("Cloud voice" /
   "On-device voice") — both retained — and remove all user-facing telemetry/provider/JSON
   surfaces and the transcript-provenance line.
3. Replace the pipe-delimited interpreted summary with **inspectable interpretation chips**,
   and give clarification/empty/error states contextual, non-technical copy.

Effort is mostly SMALL–MEDIUM: the widgets and the intent-specific cards already exist; the
work is re-composition, copy, a token layer, and removing dev scaffolding — not a rewrite.

---

## 2. Product UX Principles

1. **Search-first, not chat-first.** The hero is a search field and a result list. Voice and
   natural language are *input methods*, not a persona to converse with.
2. **The answer is the product; the pipeline is invisible.** Never show `SearchQuery`,
   intent names, canonical IDs, `SearchPlan`, provider/model, tokens, or cost to end users.
3. **Show the interpretation, not the schema.** After a search, the user should see *what was
   understood* as removable chips ("Max Freeman", "Jump", "Rally Ireland"), never a
   pipe-delimited field dump.
4. **A zero-result is a valid, well-designed outcome** — not an error screen.
5. **Editorial motorsport tone, utility discipline.** Strong imagery and bold titles, but
   compact metadata and restrained color — a search product, not a racing game.
6. **Clarification is a feature, presented as a helpful question**, because the backend
   already prefers clarifying over guessing wrong.

---

## 3. Current UI Assessment

### What is genuinely good (keep)
- **Intent-specific result rendering already exists.** The screen dispatches nine intents to
  seven purpose-built widgets (rally card, participation card, finisher leaderboard, video
  action card, video card, uploader leaderboard, driver-wins leaderboard). This is the
  hardest part of §7 and it is already done.
- **Deterministic refinement chips** with inherited-vs-refinement styling and per-chip removal
  (`ActiveContextChipsBar`) — a strong, non-chatbot follow-up model.
- **Breadcrumb history trail** already present (`Rally Aluksne › Videos › Jumps` pattern).
- **Voice-as-editable-transcript** (no auto-submit) is correctly implemented and must be kept.
- **Clarification candidates already carry a `subtitle` discriminator** field — the data for
  §8's "Donegal Rally · 2026 · Ireland" pattern is already there.

### What undermines the product
- **Wrong front door.** `main.dart` → `RallyStreamsPage`, a technical registry exposing Stream
  ID, Video ID, `videoType='sendObs'`, clip windows, share/download counters, on-demand URLs.
  Search is buried behind an app-bar button.
- **Voice modes framed as dev scaffolding.** Two mics labelled "Native Voice" / "Cloud
  Whisper" with a "transcript (edited)" provenance line read as an internal STT comparison.
  (Both modes are a valid product choice — see the Product decision note; the issue is the
  developer *framing*, which Phase 1 replaces with product labels.)
- **Telemetry leakage.** Latency+cost chip and a dialog printing provider, model, tokens,
  cost, "Entity Resolution Time", referent context, and raw query JSON.
- **Schema-shaped interpretation.** The "interpreted summary" bar reads as backend fields.
- **Chrome-heavy layout.** Search bar + STT provenance + chips bar + clarification +
  interpreted bar + result-count bar + results + follow-ups + pagination = up to eight stacked
  horizontal bands competing before a single result is seen.
- **Inconsistent visual system.** Card radii vary (16/14/12), elevations (0/2/3), and the three
  leaderboards use loud full-bleed gradient headers (blue / amber / green) that read as three
  different apps. Colors are hardcoded hex throughout rather than tokenized.
- **No first-launch state.** `initState` immediately runs a search for all rallies, so the user
  never sees an inviting empty hero with example queries.

---

## 4. User Journey

**Current (happy path):** App opens on stream registry → user hunts for and taps "General
Search" → lands on a screen already showing all rallies → types query → sees interpreted
schema string + telemetry → results. Cognitive load front-loaded; product identity unclear.

**Target:** App opens on **Search home** (hero field + a few example queries + recent
searches) → user types or taps mic → context-aware loading → results with a one-line plain
summary and removable interpretation chips → refine via chips or a follow-up → drill in. The
streams registry becomes an optional **Browse** tab for power users.

---

## 5. Search / Home

**Current:** No distinct home. `GeneralSearchScreen` opens mid-results with a cramped input
Row: `[TextField][Native mic][Cloud mic][Search]`. On a phone this is four wide controls on
one line — the field is squeezed and the layout risks overflow.

**Issues:** field is not the hero; two mics; redundant explicit Search button competes with
Enter-to-submit; sparkle (`auto_awesome`) prefix icon signals "AI assistant"; language
dropdown (18 locales) sits in the app bar adding weight; no examples, no recents.

**Proposed hierarchy (first launch / empty):**
1. Minimal header: "Rally Search" (no sparkle).
2. **Hero search field** — full width, tall (56dp), rounded, single trailing **mic**, search
   icon as prefix, generous placeholder: *"Search rallies, drivers, or moments"*.
3. **"Try:"** — 3–4 example query chips (see §5 examples), not a wall.
4. **Recent searches** (once any exist) — plain tappable list, clock icon, clearable.
5. Language moved out of the app bar into a settings affordance (or auto-detect); keep it out
   of the hero.

**Example queries (curated, max 4):**
- Rallies in Ireland in 2025
- Show Max Freeman's rallies
- Jump highlights from Rally Alūksne
- Who won Rally Donegal?

```
┌──────────────────────────────────────┐
│  Rally Search                         │
│                                       │
│  ┌────────────────────────────────┐   │
│  │ 🔍  Search rallies, drivers…  🎤│   │
│  └────────────────────────────────┘   │
│                                       │
│  Try                                  │
│   ▸ Rallies in Ireland in 2025        │
│   ▸ Show Max Freeman's rallies        │
│   ▸ Who won Rally Donegal?            │
│                                       │
│  Recent                               │
│   🕘 Jump highlights — Rally Alūksne  │
└──────────────────────────────────────┘
```

---

## 6. Search Input

**Current:** `TextField` + 2 voice buttons + `FilledButton` "Search". Below it, an STT
provenance line ("Native transcript (edited)").

**Redesign:**
- **One full-width hero field, two voice modes below it.** The search icon is the prefix; a
  clear button and an inline submit arrow appear in the field only when text is present
  (Enter/keyboard "Search" also submits). The two voice modes ("Cloud voice" / "On-device
  voice") are **both retained** as labelled pills directly beneath the field (§16).
- **Remove the STT provenance line** for users. If provider comparison is still needed, gate it
  behind a hidden debug flag — it is not product UI.
- **Sticky field.** After a search, the field stays pinned at top and shows the current query,
  so refining is always one tap away.
- Keyboard: `textInputAction: search`, autocorrect off for entity-heavy queries, submit on
  action key.
- Focus state: subtle accent border + elevation; no heavy glow.

---

## 7. Loading

**Current:** Centered `CircularProgressIndicator` with status text that includes
`"Searching database..."` and `"Understanding your search..."` — the first leaks the DB layer.

**Redesign:**
- **Context-aware, non-technical copy** derived from the parsed intent once known, else a
  neutral default:
  - `Searching rallies…`
  - `Finding jump highlights…`
  - `Looking for Max Freeman…`
- **Skeleton rows** matching the target card type (rally banner skeleton, leaderboard row
  skeleton) instead of a bare spinner, so the result shape is anticipated.
- Never surface `Resolving OpenEntity`, `Calling Gemini`, DB, or plan steps.

---

## 8. Result Cards (design system for results)

Keep the intent-specific approach; unify the *shell* (radius, border, elevation, spacing,
type scale) so seven card types read as one family. Standardize on: 16dp radius, 1px hairline
border, elevation 0 (rely on border + surface), 16dp internal padding, consistent title/meta
type ramp (§21). Retire the loud gradient headers on leaderboards in favor of a compact solid
header bar using accent-tint, not full-saturation gradients.

---

## 9. Rally Results

**Current (`RallyResultCard`):** 160px banner image (or motorsport placeholder), stages badge,
status badge, title, location, date range. Good structure.

**Assessment:** Strong already. Tighten: title 18→ card-title token; ensure two-line long-name
handling (present); the "ACTIVE"/status badge color logic is ad-hoc (green/blue-grey) — move to
tokens. Tapping drills to top finishers (good), but the affordance is invisible — add a subtle
trailing chevron or "View results ›".

**Hierarchy:** Primary = event name. Secondary = location, date. Tertiary = stage count,
status. Action = whole-card tap → finishers.

---

## 10. Driver Results

**Current (`DriverParticipationCard`):** event name + location, finish-position badge, avatar
initial, car/number, total time. Winner state highlighted amber. Solid.

**Assessment:** Position badge copy is verbose (`🏆 1st Place (Winner)`, `Participated (role)`);
compress to `P1`, `2nd`, `DNF`, or a small rosette for wins. Avatar is initial-only — fine.
Keep win-highlight but through a token, not raw `Colors.amber`.

**Hierarchy:** Primary = event + finish position. Secondary = driver, car. Tertiary = time.

---

## 11. Video / Highlight Results

**Two widgets:** `VideoActionCard` (moments: jump/drift/crash…) and `VideoResultCard`
(driver/stage videos). Both have thumbnail, play affordance, duration, context. Good.

**Assessment:** Per-action color+icon map is a nice touch but currently very saturated across 8
colors — soften to a restrained set (one accent + neutral, action name as the differentiator).
`VideoActionCard` action-type key uses `start_line`/`near_miss` (underscore) while the summary
localizer uses `start line`/`near miss` (space) — cosmetic mismatch worth aligning so labels
render consistently. Ensure play target ≥44dp.

**Hierarchy:** Primary = action type + thumbnail. Secondary = rally / stage. Tertiary =
timecode / duration. Action = play.

---

## 12. Classification & Rankings

**Widgets:** `RallyLeaderboard`, `DriverWinsLeaderboard`, `UploaderLeaderboard`.

**Assessment:** Information-dense and well-structured (POS / NO / DRIVER-CREW-CAR / TIME with
+diff; medal emoji top-3). This is the FotMob-density strength. Problems: **three different
gradient identities** and inconsistent header treatments make them feel like separate features.
`totalTime` renders as raw seconds (`123s`) — format as `mm:ss.t`. Medal emoji are fine but
should be consistent in size/baseline.

**Unify:** one leaderboard shell, one header style (solid accent-tint bar + title + count
pill), shared row spec, tokenized top-3 highlight.

---

## 13. Clarification

**Current (`ClarificationCard`):** amber card titled **"Clarification Needed"** + the backend
question + candidate `ActionChip`s (`Name (subtitle)`).

**Assessment:** The generic "Clarification Needed" label is the weak point; the backend already
supplies a good question and candidates already carry `subtitle`. Redesign presentation only:
- **Contextual title from the ambiguous entity type**: "Which driver did you mean?", "Which
  rally did you mean?", "Which stage did you mean?" (derive from candidate `EntityType`).
- **Show discriminators on their own line**, not in parentheses:
  `Donegal International Rally` / `2026 · Ireland`.
- Larger tap targets (list rows, not tight chips) when 2–5 candidates; keep chips only for many.
- Drop the amber "warning" framing; this is a helpful question, use neutral/accent surface.

```
Which rally did you mean?
┌───────────────────────────────┐
│ 🏁 Donegal International Rally │
│    2026 · Ireland             │
├───────────────────────────────┤
│ 🏁 Donegal Forest Rally       │
│    2024 · Ireland             │
└───────────────────────────────┘
```
Semantics unchanged (§26): selection still reuses the pending parsed query and canonical ID,
no LLM call.

---

## 14. Empty States

**Current:** `search_off` icon, friendly message, "Active search context is preserved. Try
removing a filter…" (jargon), optional "Did you mean?" candidate chips, Reset / Show All
Rallies buttons.

**Redesign — treat zero-result as a designed outcome:**
- Plain title naming the miss in the user's terms: **"No jump highlights found"**.
- **Echo the active filters as removable chips** right there: `[Max Freeman] [Jump] [Rally
  Ireland]`, each removable to broaden.
- **Offer explicit next actions, do not auto-broaden**:
  - "Search all Max Freeman videos"
  - "Remove Rally Ireland"
  - "Edit query"
- Keep "Did you mean?" candidates (already present) but style as list rows.
- Drop "Active search context is preserved" and "Reset Session" wording.

```
No jump highlights found
Filters:  [Max Freeman ✕]  [Jump ✕]  [Rally Ireland ✕]

Try
 ▸ Search all Max Freeman videos
 ▸ Remove “Rally Ireland”
 ▸ Edit your search
```

---

## 15. Error States

**Current:** One generic red `error_outline` + message + Retry, plus voice errors via red
snackbars. No differentiation; the interpreted-summary path can show `"Query parsing failed"`.

**Redesign — four distinct states, no stack traces / HTTP codes / provider names:**
1. **No results** → §14 (not an error).
2. **Couldn't understand the query** → "We couldn't turn that into a search. Try rephrasing —
   e.g. *rallies in Ireland in 2025*." + example chips.
3. **Service unavailable (network/backend)** → "Search is temporarily unavailable." + [Try
   again]. (Generic, calm; the app already maps exceptions to friendly text — good, keep it,
   just split copy.)
4. **Voice transcription failed** → inline near the field: "Couldn't transcribe that." + [Try
   again], not a red error snackbar.

---

## 16. Voice

**Current:** Two `VoiceSearchButton`s (Native + Cloud). Each animates: idle → listening
(red pulse) → processing (spinner) → error. Transcript lands editable in the field; no
auto-submit. State handling is solid.

**Redesign (preserve the flow, fix the surface) — BOTH modes retained:**
- **Two intentional voice modes**, presented as labelled pills: "Cloud voice" and "On-device
  voice". Both stay fully operational and independent (neither silently falls back to the
  other). Remove only the provider/model wording and the transcript-provenance line from the
  UI. Provider terminology ("Native", "Whisper", "OpenAI") is not shown to users.
- Idle: labelled pill with a mode icon. Recording: red pulsing pill + "Listening…"; a
  clear **Stop** and a **Cancel**. Transcribing: inline spinner + "Transcribing…". Result:
  editable text in field, cursor at end, **user submits manually** (unchanged).
- Voice errors inline (§15.4), not modal red.
- Keep permission and cancel-on-language-change behavior.

```
Idle:        [ 🔍  Search…                       🎤 ]
Recording:   [ 🔴  Listening…      ▁▂▄▆▄▂   Stop ✕ ]
Transcribing:[ ⏳  Transcribing…                    ]
Ready:       [ show max freeman's rallies|      🎤 ]  ← user taps Search
```

---

## 17. Follow-up Search / Conversation

**Current:** Not a chatbot (good). Refinement chips + breadcrumb trail + a "Suggested
Follow-ups" bar with 2–4 deterministic chips. This is the right pattern and already built.

**Assessment / refinements:**
- Keep the **breadcrumb refinement trail** (`Rally Alūksne › Videos › Jumps`) — it is the
  strongest non-chat follow-up affordance; make it more prominent than today's 11.5px grey text.
- Consolidate the *two* separate context strips (active-context chips bar + suggested-follow-ups
  bar) so refinement lives in one visual zone, reducing the stacked-band problem.
- Suggested follow-ups: keep, but cap at 3 and place them directly under the results header, not
  in a bottom bar competing with pagination.

---

## 18. Navigation

**Current:** `RallyStreamsPage` (home) with app-bar routes to `GeneralSearchScreen` and
`VideoActionSearchScreen` (a third, manual dropdown-based moments search with a hardcoded
country list). Three overlapping search surfaces; the AI one is not primary.

**Redesign:**
- **Search is home.** Promote `GeneralSearchScreen` to the launch surface.
- Introduce a minimal **bottom nav or segmented shell**: **Search** (primary) · **Browse**
  (the streams registry, relabeled and de-jargoned) — only if browse is a real user need;
  otherwise drop browse from the default path.
- **Fold `VideoActionSearchScreen` into the NL search.** Its dropdowns (action type, country,
  stage) duplicate what natural language + interpretation chips + the advanced-filter sheet
  already do. Keep the advanced-filter sheet as the "manual controls" escape hatch; retire the
  separate screen (or keep it only as an internal tool).
- Language selector → settings, not app bar.

---

## 19. Mobile Ergonomics

- **Input row overflow (P0-ish):** four wide controls in one `Row` on the search screen crowd
  the field on narrow screens. Collapsing to one field + inline mic fixes reach and overflow.
- **Touch targets:** several icon-only controls (chip `✕`, telemetry chip, pagination icons) sit
  at ~14–20dp; enforce ≥44dp hit area.
- **Long names:** rally/person names already use `ellipsis`/`maxLines` in most cards — good;
  verify in chips and clarification rows.
- **Keyboard overlap:** ensure results scroll clear of the keyboard; sticky field must not be
  hidden.
- **Bottom safe area:** pagination footer already uses `SafeArea` — keep.
- **Chip wrapping:** context chips are in a horizontal scroller (fine) but discoverability of
  off-screen chips is low; consider wrap on the empty/clarification surfaces.
- **One-handed reach:** primary actions (mic, submit) reachable at bottom/thumb zone — currently
  top-anchored; acceptable for search, but keep the mic reachable.

---

## 20. Accessibility

- **Icon-only buttons lack semantic labels:** mic, telemetry, chip-remove, pagination — add
  `Semantics`/`tooltip` (tooltips exist on some, not all).
- **Contrast:** grey-on-grey metadata (`Colors.grey.shade600`, `theme.hintColor` on tinted
  fills) risks <4.5:1; verify and tokenize secondary/tertiary text.
- **Color-only meaning:** action-type and status rely on color; pair with label/icon (mostly
  done) and ensure it survives color-blind palettes.
- **Loading/error announcements:** wrap state changes with live-region semantics so screen
  readers announce "Searching…", "No results", "Search unavailable".
- **Selected chip state:** inherited-vs-refinement is a subtle color shift; add a semantic
  selected/label so it is not color-only.
- **Text scaling:** dense 11–12.5px labels should respect `textScaleFactor`; avoid fixed tiny
  sizes where possible.

---

## 21. Proposed Design System

Lightweight, token-driven. Introduce a single `AppTheme` / token file; stop hardcoding hex.

**Typography (motorsport-editorial + utility):**
| Role | Size / weight | Use |
|---|---|---|
| Display / search hero | 22–24 / 700 | home title, hero |
| Section title | 16 / 700 | leaderboard headers, "Try" |
| Card title | 16–18 / 700 | rally/event/stage names |
| Body | 14 / 500 | primary metadata |
| Metadata | 12–13 / 500 | location, date, role |
| Label / overline | 11 / 600, tracked | table headers, chips, badges |

Consider one distinctive display face for titles (bold, condensed-ish) with Roboto for body.

**Spacing scale:** 4 · 8 · 12 · 16 · 24 · 32 (already roughly used; formalize).

**Radius:** 8 (chips/badges/controls) · 12 (inner media) · 16 (cards/sheets). Retire 14.

**Elevation:** flat by default — elevation 0 + 1px hairline border + surface tint. Reserve a
single soft shadow for the sticky search field and modals only. Remove card elevation 2/3.

**Color roles (dark-first, restrained accent):**
| Role | Note |
|---|---|
| background | near-black (dark) / near-white neutral (light) |
| surface / surface-variant | cards, sheets, bars |
| primary text / secondary / tertiary | 3-step ramp, contrast-checked |
| accent | ONE motorsport accent (current blue `#1E88E5` is fine, or a bolder rally hue) |
| success / warning / destructive | status only, not decoration |
| top-3 / winner highlight | one gold token, not raw amber everywhere |

**Icon style:** the existing rounded Material set (`*_rounded`) — keep, consistently.

**Chip style:** 8dp radius, hairline border, filled tint for active/refinement, neutral for
inherited; `✕` with 44dp hit area.

**Button style:** filled accent for primary submit; text/tonal for secondary; consistent 12dp
radius and padding.

**Result-card style:** the unified shell in §8.

**Loading skeleton style:** neutral shimmer blocks matching each card's silhouette.

---

## 22. Components — Keep / Restyle / Refactor / Remove

| Component | Current purpose | Decision | Why |
|---|---|---|---|
| `GeneralSearchScreen` | AI NL/voice search | **REFACTOR** | Promote to home; split first-launch vs results; remove telemetry/dual-mic; single context zone |
| `RallyStreamsPage` | Technical stream registry (current home) | **REFACTOR / DEMOTE** | Not search-first; de-jargon and move to optional "Browse", or drop from default path |
| `VideoActionSearchScreen` | Manual dropdown moments search | **REMOVE / MERGE** | Duplicates NL search + advanced filters; hardcoded country list |
| `VoiceSearchButton` | Voice capture w/ state anim | **KEEP (restyle)** | Solid state machine; keep BOTH instances, restyle as labelled pills |
| Dual-voice presentation | Two voice modes shown as dev A/B controls | **RESTYLE (both retained)** | Keep both modes; product labels ("Cloud voice" / "On-device voice"); drop provider wording |
| STT provenance line | "Native/Cloud transcript (edited)" | **REMOVE** | Dev artifact leaked to users |
| Telemetry chip + `_showTelemetryDialog` | Provider/cost/latency/JSON | **REMOVE** (from user UI) | Violates "hide internals"; gate behind debug flag if needed |
| Interpreted-summary bar (pipe string) | Show interpretation | **REFACTOR → interpretation chips** | Schema-shaped; replace with removable chips |
| `ActiveContextChipsBar` | Refinement/inherited chips + breadcrumb | **KEEP (restyle)** | Core non-chat follow-up model; merge with follow-ups zone |
| `SuggestedFollowUpsBar` | Deterministic follow-ups | **KEEP (restyle)** | Good; relocate near results header, cap at 3 |
| `ClarificationCard` | Disambiguation | **RESTYLE** | Contextual title, discriminator lines, larger targets, drop warning framing |
| `RallyResultCard` | Rally result | **KEEP (restyle)** | Strong; tokenize, add drill affordance |
| `DriverParticipationCard` | Driver participation | **KEEP (restyle)** | Compress position copy, tokenize |
| `VideoActionCard` | Moment clip | **KEEP (restyle)** | Soften action palette; align action-type keys |
| `VideoResultCard` | Driver/stage video | **KEEP (restyle)** | Tokenize |
| `RallyLeaderboard` / `DriverWinsLeaderboard` / `UploaderLeaderboard` | Rankings | **RESTYLE (unify)** | One shell/header; format times; tokenize gold |
| Empty-state block (inline in screen) | No-results | **REFACTOR → component** | Filter-echo chips + explicit actions; de-jargon |
| Error-state block (inline) | Errors | **REFACTOR** | Split into 4 typed states |
| Loading block (spinner + status) | Loading | **REFACTOR** | Context copy + skeletons; drop "database" |
| Pagination footers | Paging | **KEEP (restyle)** | Fine; consider load-more on mobile |
| Language dropdown in app bar | Locale select | **RESTYLE / MOVE** | To settings; not in hero |
| `AdvancedFiltersSheet` | Manual filters | **KEEP** | Good power-user escape hatch |
| — | Design tokens / `AppTheme` | **NEW** | Centralize color/type/spacing/radius |
| — | First-launch hero (examples + recents) | **NEW** | No home state exists today |
| — | Card/leaderboard skeletons | **NEW** | Replace bare spinner |

---

## 23. Screen-by-Screen Redesign

**SEARCH / HOME (first launch)**
1. Minimal header ("Rally Search")
2. Hero search field (single mic inline)
3. "Try" — ≤4 example chips
4. Recent searches (when present)

**SEARCH RESULTS**
1. Sticky search field (shows current query)
2. Interpretation chips (removable) + breadcrumb (one zone)
3. Plain one-line summary ("12 rallies in Ireland, 2025")
4. Result list (intent-specific cards)
5. Up to 3 suggested follow-ups (under header)
6. Pagination / load-more

**RALLY RESULTS** — banner · name · location · date · stages/status · drill affordance.

**DRIVER RESULTS** — event + finish position (compact) · driver/car · time.

**VIDEOS / MOMENTS** — thumbnail · action type · rally/stage · timecode · play.

**CLASSIFICATION / RANKINGS** — unified leaderboard shell · rank · driver/crew/car · time/wins/uploads.

**CLARIFICATION** — contextual question · candidate rows with discriminator lines.

**NO RESULTS** — plain title · filter-echo chips · explicit broaden actions · did-you-mean rows.

**ERROR** — one of four typed states (understand / unavailable / voice / no-result) · retry.

**VOICE** — inline idle/recording/transcribing states in the field · manual submit.

---

## 24. Prioritized Improvements

**P0 — blocks the product being understood as search**
- Make search the front door; demote the streams registry. *(MEDIUM)*
- Remove telemetry chip + telemetry dialog from user UI. *(SMALL)*
- Re-present both voice modes as product-facing pills; remove STT provenance line. *(SMALL)*
- Fix input-row crowding/overflow on mobile (full-width field; voice modes below). *(SMALL)*

**P1 — major UX gains**
- Replace pipe-summary with removable interpretation chips. *(MEDIUM)*
- First-launch hero with examples + recents. *(MEDIUM)*
- Contextual clarification (title + discriminator lines, bigger targets). *(SMALL–MEDIUM)*
- Redesigned empty state (filter-echo + explicit actions). *(SMALL)*
- Four typed error states + inline voice errors. *(SMALL–MEDIUM)*
- Context-aware loading + skeletons. *(MEDIUM)*
- Introduce design tokens / `AppTheme`. *(MEDIUM)*

**P2 — polish**
- Unify leaderboard shells; format times; tokenize gold. *(MEDIUM)*
- Unify card radii/elevation/spacing; soften action palette. *(SMALL–MEDIUM)*
- Merge context-chips + follow-ups into one zone; cap follow-ups at 3. *(SMALL)*
- Compress verbose position/copy strings. *(SMALL)*
- Accessibility pass (labels, contrast, live regions, hit areas). *(MEDIUM)*

**P3 — optional**
- Bottom-nav shell (Search / Browse). *(MEDIUM)*
- Distinctive display typeface. *(SMALL)*
- Load-more instead of numbered pagination on mobile. *(SMALL)*
- Rich imagery/editorial treatment on rally banners. *(MEDIUM)*

*(Effort tags: SMALL/MEDIUM/LARGE. Priority order favors high-impact SMALL/MEDIUM.)*

---

## 25. Implementation Plan (phased)

**Phase 1 — Search shell + design system (IMPLEMENTED)**
Promote search to home; no auto-search on launch; full-width hero field with inline
clear/submit; **both** voice modes retained and re-presented as labelled pills ("Cloud voice" /
"On-device voice") with provider/debug framing removed; remove telemetry chip + dialog and the
STT provenance line; add lightweight design tokens (`lib/theme/app_theme.dart`); first-launch
hero with example queries (recent searches deferred). Streams registry retained as a secondary
"Browse" area reachable from the search app bar.

**Phase 2 — Result surface + clarification + states (IMPLEMENTED)**
Combined the audit's original Phases 2 and 3. Shipped: shared `RallyCardShell` (16dp radius,
hairline border, flat elevation) applied to the rally / participation / video / video-action
cards; shared `LeaderboardScaffold` replacing the three divergent gradient headers with one
restrained accent-tinted header (finishers / driver-wins / uploaders); `formatRaceTime` for
readable times (UI only); softened, icon-led action palette via `RallyActionVisual` (accent /
warning / destructive, with `start_line`/`start line` key normalization); tokenized
winner/top-3 gold (`kRallyGold`); rally "View results ›" drill affordance. Removed the
schema/pipe interpreted-summary band — interpretation is now the removable
`ActiveContextChipsBar`. Redesigned clarification (`ClarificationCard`: contextual type-derived
title, tappable ≥44dp discriminator rows, neutral treatment). Redesigned no-results (plain
title, removable filter chips, explicit broaden actions, clean "Did you mean" — jargon removed).
Split errors into typed states (`_SearchErrorKind`: service-unavailable vs
couldn't-understand). Context-aware loading copy + a lightweight `ResultsSkeleton` (pure
Flutter, no new package). Follow-ups capped at 3. Accessibility: semantics/live-regions on
states, ≥44dp targets, removable chips announce what they remove. Voice unchanged — **both
modes retained**.

**Phase 3 — Remaining polish (deferred)**
Migrate the leaderboard rows and remaining cards fully onto the token type ramp; distinctive
display typeface; richer rally imagery; load-more on mobile; optional bottom-nav shell; broader
contrast/text-scaling audit across untouched surfaces.

Each phase is independently shippable and touches only presentation.

---

## 26. Things NOT to Change

Protected — presentation-only redesign must not alter:
- **Backend architecture** (Flutter → FastAPI → QU → Router → OpenEntity → SearchPlan →
  Repository → MySQL).
- **Query semantics** — OR-within-dimension / AND-across-dimensions; the 9-intent model;
  `SearchQuery` field contract.
- **Clarification semantics** — selection reuses the pending parsed query and replaces only the
  ambiguous entity dimension; **no LLM call on selection**; filters/referents/generation
  preserved.
- **Canonical ID behavior** — canonical entity/event IDs survive follow-ups and clarification.
- **No-auto-submit voice** — transcript is always editable; the user submits manually.
- **Deterministic router/OpenEntity** and the safety ordering (correct-confident >
  clarification > safe no-match > wrong-confident).
- **API contracts / endpoints** (`/v1/conversation/search`, `/v1/voice/transcribe`, session/
  requestId handling).

---

## 27. Final Recommended Visual Direction

**Modern search utility with a motorsport-editorial skin.** Dark-first, near-black surfaces
with a single restrained accent (keep the current blue or move to a bolder rally hue used
sparingly). Bold, slightly condensed titles; compact, technical metadata (FotMob-grade density
in leaderboards); strong rally imagery where available with a clean placeholder otherwise. Flat
surfaces, hairline borders, one soft shadow reserved for the sticky search field and modals.
Restraint over decoration: retire multi-gradient headers and the 8-color action palette; let
type, spacing, and one accent carry the identity. The result should feel like Google-search
simplicity + FotMob density + Linear-level polish — never a chatbot, a dashboard, or a racing
game.
```
┌───────────────────────────────┐   Search-first.
│ 🔍 Search rallies, drivers  🎤│   One field. One mic.
├───────────────────────────────┤   Interpretation as chips.
│ [Max Freeman ✕][Jump ✕]       │   Internals invisible.
│ 12 jump highlights            │   Editorial, restrained.
│ + intent-specific result cards│
└───────────────────────────────┘
```
