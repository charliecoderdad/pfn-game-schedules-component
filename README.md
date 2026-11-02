# Game Schedules v2 — Discourse theme component

A Discourse **theme component** for [packfansnation.com](https://forums.packfansnation.com/)
that renders the next upcoming NC State game for football, men's/women's basketball, and
baseball. It fetches `schedule-<sport>.json` from the `pfn-static` S3 bucket at runtime and
shows the next upcoming game (all date/time comparisons happen in `America/New_York`).

A sport's pill disappears the moment that game's listed start time arrives, and stays
hidden for the rest of the day — the *next* game takes over at midnight ET, not at kickoff.
A game whose `time` is `TBD` has no start time to pass, so it holds the pill all day.
The pills re-evaluate on a 1-second tick, so a tab left open through a kickoff or past
midnight updates itself without a reload.

## Layout

- `about.json` — component manifest (name, `component: true`).
- `desktop/header.html` — the `#game-schedules` wrapper and the four per-sport boxes.
- `desktop/desktop.scss` — all styling (NC State red→black gradient banner, white sport cards).
- `javascripts/discourse/api-initializers/theme-initializer.gjs` — fetches the JSON,
  finds the next game per sport, and renders it. This file is *why* the component can't be
  pasted into the Discourse theme editor UI — `javascripts/` files only travel via git or zip.

## Install into Discourse (first time)

Admin → Customize → Themes → **Install** → **From a git repository** → paste this repo's URL:

```
git@github.com:charliecoderdad/pfn-game-schedules-component.git
```

Then add it as a component to the active theme.

## Update after editing

1. Edit the files here, commit, and push to `main`.
2. In Discourse: Admin → Customize → Themes → **Game Schedules v2** → **Check for updates** → **Update**.

No zip juggling and no duplicate components — git is the source of truth.

## Sizing / auto-fit

Every size in `desktop.scss` is an `em` off one property — `#game-schedules { font-size }` —
so that single value scales the entire banner (icons, text, padding, gaps) together.

The initializer measures the visible pills against the width the banner actually has and
sets that font-size inline, so the row grows to use the sides instead of leaving dead space,
and shrinks rather than stacking when space runs short. Knobs live at the top of the
auto-fit block in `theme-initializer.gjs`:

- `MAX_BASE_PX` (24) — how large the banner may grow on a wide monitor (16 = the design size).
- `MIN_BASE_PX` (10) — floor; below this the pills wrap to a second line instead of shrinking further.
- The visible side margin is the `2.25%` horizontal padding on `#game-schedules`.

When only one pill is visible it is measured as if a second pill of the same width sat
beside it, so a lone pill renders at the size two pills would have instead of stretching
across the whole banner.

The `clamp()` on that same property is the no-JS fallback.

## Notes

- **After you overwrite a schedule JSON in S3, bump `SCHEDULE_VERSION` at the top of
  `theme-initializer.gjs`**, then commit, push, and Update the component. That token is
  appended to every schedule fetch as `?v=`.

  Two cache layers sit in front of the JSON and you need both handled:

  1. The S3 objects are served with `Cache-Control: max-age=300` (set 2026-11-02 via
     `aws s3 cp <key> <key> --metadata-directive REPLACE --content-type application/json
     --cache-control max-age=300`). Note that a plain `aws s3 cp <file> s3://...` upload
     does **not** carry that header forward — pass `--cache-control` on the upload too, or
     re-apply it afterwards.
  2. Discourse registers a **service worker**, which can answer the initializer's `fetch()`
     from its own cache regardless of the S3 headers. A hard refresh (Ctrl+Shift+R) bypasses
     the HTTP cache but *not* the service worker, so a stale schedule can survive one. This
     is why `?v=` is back after commit `4dec7d8` removed it: on 2026-11-02 a new men's
     basketball schedule loaded correctly in a plain browser tab while the banner kept
     rendering the previous season.
- The schedule *data* (the JSON files themselves) lives in the `pfn-static` S3 bucket, which
  is the source of truth. This repo is primarily the display component, but it also carries the
  `update-football-schedule` Claude skill (`.claude/skills/`) and a git-tracked staging copy of
  the football schedule at `data/schedule-football.json` — the skill overwrites that copy each
  time it rebuilds the slate, so git keeps a diff record of what changed before it's pushed to S3.
  The other sports' JSON staging copies still live in the main
  [`pfn`](https://github.com/charliecoderdad/pfn) repo's `banners/` area.
