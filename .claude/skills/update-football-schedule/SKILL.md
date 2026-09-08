---
name: update-football-schedule
description: Refresh the NC State football schedule that the game-schedules banner displays. Downloads the current schedule-football.json from the pfn-static S3 bucket, scrapes the current-season schedule from gopack.com (official) to rebuild the future-games slate, drops games older than today, shows the result as a table for the user to confirm, and only then overwrites the S3 object (and the repo staging copy). Use whenever the user wants to update, refresh, or rebuild the football schedule / schedule-football.json, add newly-announced games, or pull in a new football season.
---

# Update Football Schedule

Rebuilds `schedule-football.json` (the file the `game-schedules-banner`
fetches from the `pfn-static` S3 bucket) from the current official NC State
football schedule, keeping only games on or after today.

**The upload overwrites the live S3 object with no backup.** Never run the
upload script until the user has explicitly approved the final schedule
table in this conversation turn (Step 5). The git diff on the repo staging
copy is the only record of what changed.

## JSON shape (do not deviate)

The banner expects an array of game objects in exactly this shape, sorted by
`date` ascending:

```json
[
  {
    "opponent": "East Carolina",
    "date": "2025-08-28",
    "time": "7:00 PM",
    "home": true,
    "location": "Carter-Finley Stadium",
    "tv": "ACC Network"
  }
]
```

- `date` is `YYYY-MM-DD`.
- `time` is a display string like `"7:00 PM"`, or `"TBD"` when kickoff isn't
  announced yet.
- `home` is a boolean (true = home game at Carter-Finley).
- `location` is a venue or city string.
- `tv` is a network string, or `null` when no broadcast is announced yet.

Match the existing formatting conventions (`"TBD"` for unknown times, `null`
for unknown TV) rather than inventing new placeholders.

## Step 1: Download the current schedule

```bash
.claude/skills/update-football-schedule/scripts/fetch_current.sh \
  "$SCRATCHPAD/schedule-football.current.json"
```

Use the session scratchpad directory for the download (the path Claude Code
gives you for temp files). Read the downloaded file so you know the current
state and can diff against the rebuild.

## Step 2: Scrape the current-season schedule from gopack.com

Primary source is the **official** NC State athletics schedule:
`https://gopack.com/sports/football/schedule` (append the season/year if the
current season isn't the default view, e.g. `.../schedule/2026`).

Fetch it with WebFetch and pull, for every game: opponent, date, kickoff
time, home/away, location/venue, and TV network.

If gopack.com blocks the fetch or returns unusable markup, fall back to a
web search for the current NC State football schedule and synthesize from
authoritative results (prefer gopack.com, ESPN, or the ACC site). Note in
your eventual summary which source you actually used.

Convert everything to the JSON shape above:
- Home games are at `Carter-Finley Stadium` unless the source says otherwise.
- Unannounced kickoff -> `"time": "TBD"`. Unannounced broadcast ->
  `"tv": null`.

## Step 3: Rebuild the future slate (full rebuild)

This is a **full rebuild**, not a merge: gopack.com is the source of truth.
Take the scraped games as the complete slate and do not carry forward games
from the old file except by virtue of them also appearing in the scrape.

## Step 4: Drop past games

Compute today's date as a `YYYY-MM-DD` string in the `America/New_York`
timezone (the banner normalizes to `America/New_York`):

```bash
TZ=America/New_York date +%F
```

Keep every game whose `date` is **>= today** (string comparison on
`YYYY-MM-DD` is reliable). Drop games whose `date` is strictly earlier than
today. This matches the banner's own cutoff (`game.date >= todayESTString`
in `index.html`), so a game happening *today* is kept, not dropped. Sort the
remaining games by `date` ascending.

Write the rebuilt array to `$SCRATCHPAD/schedule-football.new.json`
(pretty-printed with 2-space indent to match the existing file style).

## Step 5: Show the table and wait for approval

Print the final future slate as a Markdown table for the user, with columns:
Date, Opponent, Home/Away, Time, Location, TV. Below it, note how many past
games were dropped (and, briefly, which). State which source you scraped.

Then **stop and ask the user to confirm** before anything is uploaded. Do
not proceed to Step 6 on implicit or assumed approval. If the user asks for
edits (a corrected time, a missing game, a TV fix), apply them to
`schedule-football.new.json` and reprint the table, looping until they
explicitly approve.

## Step 6: Write the repo copy and upload

Only after explicit approval:

1. Overwrite the repo staging copy so the repo stays in sync with S3:
   ```bash
   cp "$SCRATCHPAD/schedule-football.new.json" \
      data/schedule-football.json
   ```
2. Upload to S3 (the script re-downloads and verifies the bytes match):
   ```bash
   .claude/skills/update-football-schedule/scripts/upload_schedule.sh \
     data/schedule-football.json
   ```

The script sources nothing and needs no secrets — it uses the ambient AWS
CLI credentials, same as the rest of this repo's S3 work. It sets
`Content-Type: application/json` and refuses to upload invalid JSON.

## Step 7: Report and remind

Report the outcome: confirm the upload verified, and show the git status of
`data/schedule-football.json` so the user has the
diff as a record.

Then print the cache-bust reminder: this v2 component
(`javascripts/discourse/api-initializers/theme-initializer.gjs`) fetches the
JSON with plain URLs and no `?v=` param, so whether a user's browser
re-fetches right away depends on the S3 object's `Cache-Control` headers, not
on the component. If stale schedules become a problem, set a short
`Cache-Control` (e.g. `max-age=300`) on the S3 object, or re-introduce a
`?v=` param in `theme-initializer.gjs` that you bump on each update (then
commit and push, and Update the component in Admin > Customize > Themes).
