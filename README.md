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

- The JSON URLs in `theme-initializer.gjs` carry a `?v=YYYY-MM-DD` cache-bust. Bump it when
  you want every user's browser to re-fetch the schedule JSON immediately.
- The schedule *data* (the JSON files themselves) lives in the `pfn-static` S3 bucket and in
  the main [`pfn`](https://github.com/charliecoderdad/pfn) repo's `banners/game-schedules-banner/`
  staging copies — not here. This repo is only the display component.
