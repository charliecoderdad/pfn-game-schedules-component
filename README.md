# Game Schedules v2 — Discourse theme component

A Discourse **theme component** for [packfansnation.com](https://forums.packfansnation.com/)
that renders the next upcoming NC State game for football, men's/women's basketball, and
baseball. It fetches `schedule-<sport>.json` from the `pfn-static` S3 bucket at runtime and
shows the next game on or after today (compared in `America/New_York`).

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

## Notes

- The JSON URLs in `theme-initializer.gjs` are plain (no `?v=` cache-bust). Whether a user's
  browser re-fetches immediately after you update the S3 JSON depends on the S3 object's
  `Cache-Control` headers, not on the component. If stale schedules become a problem, set a
  short `Cache-Control` (e.g. `max-age=300`) on the S3 objects, or re-introduce a `?v=` param
  that you bump on each update.
- The schedule *data* (the JSON files themselves) lives in the `pfn-static` S3 bucket, which
  is the source of truth. This repo is primarily the display component, but it also carries the
  `update-football-schedule` Claude skill (`.claude/skills/`) and a git-tracked staging copy of
  the football schedule at `data/schedule-football.json` — the skill overwrites that copy each
  time it rebuilds the slate, so git keeps a diff record of what changed before it's pushed to S3.
  The other sports' JSON staging copies still live in the main
  [`pfn`](https://github.com/charliecoderdad/pfn) repo's `banners/` area.
