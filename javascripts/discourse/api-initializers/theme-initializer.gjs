import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
      const schedulesToLoad = [
        {
          divId: 'football',
          title: 'Football',
          url: 'https://pfn-static.s3.us-east-2.amazonaws.com/schedule-football.json',
          iconUrl: 'https://pfn-static.s3.us-east-2.amazonaws.com/images/football-game-schedule-icon.png'
        },
        {
          divId: 'mens-basketball',
          title: 'Men\'s Basketball',
          url: 'https://pfn-static.s3.us-east-2.amazonaws.com/schedule-mens-basketball.json',
          iconUrl: 'https://pfn-static.s3.us-east-2.amazonaws.com/images/mens-basketball-game-schedule-icon.png'
        },
        {
          divId: 'womens-basketball',
          title: 'Women\'s Basketball',
          url: 'https://pfn-static.s3.us-east-2.amazonaws.com/schedule-womens-basketball.json',
          iconUrl: 'https://pfn-static.s3.us-east-2.amazonaws.com/images/womens-basketball-game-schedule-icon.png'
        },
        {
          divId: 'baseball',
          title: 'Baseball',
          url: 'https://pfn-static.s3.us-east-2.amazonaws.com/schedule-baseball.json',
          iconUrl: 'https://pfn-static.s3.us-east-2.amazonaws.com/images/baseball-game-schedule-icon.png'
        }
      ];

      /**
       * Gets the current date AND clock in the 'America/New_York' (EST/EDT)
       * timezone. Reading both from Intl keeps this DST-correct without ever
       * hard-coding a -04:00/-05:00 offset.
       * @returns {{date: string, minutes: number}} 'YYYY-MM-DD' plus minutes since ET midnight.
       */
      const getNowInEST = () => {
        const parts = new Intl.DateTimeFormat('en-CA', {
          timeZone: 'America/New_York',
          year: 'numeric',
          month: '2-digit',
          day: '2-digit',
          hour: '2-digit',
          minute: '2-digit',
          hour12: false
        }).formatToParts(new Date());

        const get = (type) => parts.find((p) => p.type === type).value;
        // Some engines report midnight as hour 24 in the h23/h24 cycle.
        const hour = parseInt(get('hour'), 10) % 24;

        return {
          date: `${get('year')}-${get('month')}-${get('day')}`,
          minutes: hour * 60 + parseInt(get('minute'), 10)
        };
      };

      /**
       * Turns a schedule time like "7:00 PM" into minutes since midnight.
       * Returns null for 'TBD', null, or anything unparseable.
       */
      const parseGameMinutes = (time) => {
        const m = /^(\d{1,2}):(\d{2})\s*([AP])\.?M\.?$/i.exec(String(time || '').trim());
        if (!m) return null;
        const hour = (parseInt(m[1], 10) % 12) + (m[3].toUpperCase() === 'P' ? 12 : 0);
        return hour * 60 + parseInt(m[2], 10);
      };

      /**
       * The pill shows the next game on or after today (ET) — but once a game
       * has kicked off, its pill goes away for the rest of that day rather than
       * jumping straight to the next opponent. The following game takes over at
       * midnight ET. A game whose time is 'TBD' has no kickoff to pass, so it
       * holds the pill for the whole day.
       * @returns the game to display, or null to hide the pill.
       */
      const pickUpcomingGame = (games, now) => {
        const next = games.find((game) => game.date >= now.date);
        if (!next) return null;
        if (next.date === now.date) {
          const kickoff = parseGameMinutes(next.time);
          if (kickoff !== null && now.minutes >= kickoff) return null;
        }
        return next;
      };

      // ================================================================
      // Tip Off Countdown pill (mockup take #7). Hard-coded target date —
      // update once a season. The pill only renders while tip-off is in the
      // future, and hides itself the moment the countdown reaches zero.
      // Tip-off: Nov 2 2026, 7:00 PM ET. The explicit -05:00 offset pins it
      // to Eastern (EST) so the countdown is correct regardless of the
      // viewer's local timezone.
      // ================================================================
      const TIPOFF_TARGET = new Date('2026-11-02T19:00:00-05:00');
      const COUNTDOWN_ICON = 'https://pfn-static.s3.us-east-2.amazonaws.com/images/mens-basketball-game-schedule-icon.png';

      const pad2 = (n) => (n < 10 ? '0' : '') + n;

      // Static skeleton for the countdown pill; numbers are filled by updateCountdown().
      const COUNTDOWN_SKELETON = `
                        <img src="${COUNTDOWN_ICON}" alt="Tip Off Countdown" class="sport-icon">
                        <div class="cdlabel"><span class="l1">Tip Off</span><span class="l2">Countdown</span></div>
                        <div class="cd-units">
                            <div class="cd-unit cd-days"><span class="num cd-d">00</span><span class="lab">Days</span></div>
                            <div class="cd-unit"><span class="num cd-h">00</span><span class="lab">Hrs</span></div>
                            <div class="cd-unit"><span class="num cd-m">00</span><span class="lab">Min</span></div>
                            <div class="cd-unit"><span class="num cd-s">00</span><span class="lab">Sec</span></div>
                        </div>
                    `;

      // Build the inner HTML for one game pill from its upcoming game.
      const buildGameHtml = (config, upcomingGame) => {
        // For display formatting, we create a Date object from parts to avoid timezone shifts.
        const gameDateParts = upcomingGame.date.split('-'); // -> ["2025", "09", "11"]
        // new Date(year, monthIndex, day) is the most reliable constructor.
        const gameDate = new Date(gameDateParts[0], gameDateParts[1] - 1, gameDateParts[2]);
        const formattedDate = gameDate.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });

        const dateTimeString = upcomingGame.time === 'TBD'
          ? formattedDate
          : `${formattedDate} &middot; ${upcomingGame.time}`;

        // Home/away prefix only when the data explicitly says so.
        const homeAway = typeof upcomingGame.home === 'boolean'
          ? `<span class="ha">${upcomingGame.home ? 'vs' : '@'}</span> `
          : '';

        // TV network chip only when a network is set (tv can be null).
        const tvChip = upcomingGame.tv
          ? `<span class="tv-chip"><span class="dot"></span>${upcomingGame.tv}</span>`
          : '';

        return `
                            <div class="game-cluster">
                                <img src="${config.iconUrl}" alt="${config.title} icon" class="sport-icon">
                                <div class="game-matchup">
                                    <p class="kicker">Next &middot; ${config.title}</p>
                                    <p class="opponent">${homeAway}${upcomingGame.opponent}</p>
                                </div>
                            </div>
                            <div class="game-when">
                                <p class="meta">${dateTimeString}</p>
                                <p class="loc">${upcomingGame.location}</p>
                            </div>
                            ${tvChip}
                        `;
      };

      // Per-sport state keyed by divId. The fetches below fill scheduleGames
      // once; refreshPills() then re-picks the game to show on every tick, so a
      // tab left open through a kickoff (or past midnight) still updates. The
      // render pass reads from here, so it never depends on the network
      // resolving at a particular moment.
      const scheduleGames = {}; // divId -> sorted games array
      const pillHtml = {};      // divId -> rendered pill HTML ('' = show nothing)
      const pillKey = {};       // divId -> key of the game currently in pillHtml

      // Re-evaluate which game each sport should be showing. Cheap enough to
      // run on the 1s tick: one Intl read plus a find() per sport, and the HTML
      // is only rebuilt when the chosen game actually changes.
      const refreshPills = () => {
        const now = getNowInEST();
        for (const config of schedulesToLoad) {
          const games = scheduleGames[config.divId];
          if (!games) continue; // not loaded yet
          const game = pickUpcomingGame(games, now);
          const key = game ? `${game.date}|${game.opponent}` : '';
          if (pillKey[config.divId] === key) continue;
          pillKey[config.divId] = key;
          pillHtml[config.divId] = game ? buildGameHtml(config, game) : '';
        }
      };

      // Apply cached content into the CURRENT header DOM. Idempotent and safe to
      // call as often as we like: it no-ops when the nodes are already populated,
      // and (re)fills fresh/empty nodes after Discourse re-renders the header.
      // This is the fix for the old race where getElementById ran after `await
      // fetch` and hit a null (already-replaced) node.
      const render = () => {
        refreshPills();

        // Countdown pill.
        const cdBox = document.getElementById('tipoff-countdown');
        if (cdBox && TIPOFF_TARGET.getTime() - Date.now() > 0) {
          if (cdBox.dataset.rendered !== '1') {
            cdBox.innerHTML = COUNTDOWN_SKELETON;
            cdBox.style.display = 'flex';
            cdBox.dataset.rendered = '1';
          }
        }

        // Game pills. The node carries the key of whatever it is showing, so
        // this both fills a freshly re-rendered (empty) node and swaps the
        // content when refreshPills() picked a different game — or hides the
        // pill entirely once today's game has started.
        for (const config of schedulesToLoad) {
          const key = pillKey[config.divId];
          if (key === undefined) continue; // not loaded yet
          const div = document.getElementById(config.divId);
          if (!div || div.dataset.gameKey === key) continue;
          div.dataset.gameKey = key;
          const html = pillHtml[config.divId];
          div.innerHTML = html;
          div.style.display = html ? 'flex' : 'none';
        }

        fitIfNeeded();
      };

      // Update the live countdown numbers on whatever node is currently mounted.
      const updateCountdown = () => {
        const box = document.getElementById('tipoff-countdown');
        if (!box) return;

        let secondsLeft = (TIPOFF_TARGET.getTime() - Date.now()) / 1000;
        if (secondsLeft <= 0) {
          box.style.display = 'none';
          return;
        }

        const dEl = box.querySelector('.cd-d');
        const hEl = box.querySelector('.cd-h');
        const mEl = box.querySelector('.cd-m');
        const sEl = box.querySelector('.cd-s');
        if (!dEl) return; // skeleton not rendered into this node yet

        dEl.textContent = pad2(parseInt(secondsLeft / 86400)); secondsLeft %= 86400;
        hEl.textContent = pad2(parseInt(secondsLeft / 3600));  secondsLeft %= 3600;
        mEl.textContent = pad2(parseInt(secondsLeft / 60));
        sEl.textContent = pad2(parseInt(secondsLeft % 60));
      };

      // ================================================================
      // Auto-fit: scale the banner to the width it actually has.
      //
      // Every size in desktop.scss is an `em` off #game-schedules'
      // font-size, so this one inline property scales icons, text, padding
      // and gaps together. We measure the visible pills at the 16px design
      // size, compare that against the space left inside the banner, and
      // pick the largest base size that still keeps them on one line —
      // capped by MAX_BASE_PX so a very wide monitor doesn't blow the
      // banner up, floored by MIN_BASE_PX so a narrow window degrades to
      // wrapping instead of unreadable text.
      // ================================================================
      const BASE_PX = 16;       // the size every em in the SCSS was designed against
      const MIN_BASE_PX = 10;
      const MAX_BASE_PX = 24;   // 1.5x the design size
      const ROW_GAP_EM = 1.25;  // must match #game-schedules gap
      const FIT_SLACK = 0.99;   // a hair of room so a rounding error can't wrap the row

      let fitRow = null;
      let fitSig = '';
      let fitWidth = 0;
      let fitObserver = null;

      const applyFit = (row) => {
        const pills = Array.from(row.children).filter((el) => el.style.display !== 'none');
        if (!pills.length) return;

        const previous = row.style.fontSize;
        row.style.fontSize = BASE_PX + 'px';
        row.classList.add('gs-measuring');

        const cs = getComputedStyle(row);
        // clientWidth includes padding, so subtract it to get the usable space.
        const available =
          row.clientWidth - parseFloat(cs.paddingLeft) - parseFloat(cs.paddingRight);
        let natural = BASE_PX * ROW_GAP_EM * (pills.length - 1);
        for (const pill of pills) natural += pill.getBoundingClientRect().width;

        row.classList.remove('gs-measuring');

        if (!(natural > 0) || !(available > 0)) {
          row.style.fontSize = previous;
          return;
        }

        const wanted = BASE_PX * ((available * FIT_SLACK) / natural);
        const size = Math.min(MAX_BASE_PX, Math.max(MIN_BASE_PX, wanted));
        row.style.fontSize = size.toFixed(2) + 'px';
      };

      // Cheap guard so the 1s tick doesn't re-measure when nothing moved. The
      // signature only changes when a pill appears/disappears or its content
      // changes — the countdown digits are always two characters, so ticking
      // does not churn it.
      const fitIfNeeded = () => {
        const row = document.getElementById('game-schedules');
        if (!row) return;

        const sig = Array.from(row.children)
          .map((el) => (el.style.display === 'none' ? '' : el.innerHTML.length))
          .join('|');
        if (row === fitRow && sig === fitSig && row.clientWidth === fitWidth) return;

        fitRow = row;
        fitSig = sig;
        fitWidth = row.clientWidth;
        applyFit(row);

        // Re-fit on width changes (window resize, sidebar toggle, zoom). Height
        // changes from our own font-size write are ignored by the width guard.
        if (fitObserver) fitObserver.disconnect();
        if (window.ResizeObserver) {
          fitObserver = new ResizeObserver(() => {
            if (row.clientWidth !== fitWidth) {
              fitWidth = row.clientWidth;
              applyFit(row);
            }
          });
          fitObserver.observe(row);
        }
      };

      // Webfonts land after first paint and change every measurement.
      if (document.fonts && document.fonts.ready) {
        document.fonts.ready.then(() => { fitSig = ''; fitIfNeeded(); });
      }

      const loadSchedule = async (config) => {
        try {
          const response = await fetch(config.url);
          if (!response.ok) throw new Error(`HTTP error! Status: ${response.status}`);

          const games = await response.json();

          // Sort games by date using simple string comparison, which is reliable for YYYY-MM-DD format.
          games.sort((a, b) => a.date.localeCompare(b.date));

          scheduleGames[config.divId] = games;
          render(); // pick and apply as soon as this schedule is ready
        } catch (error) {
          console.error(`Could not load schedule for ${config.title}:`, error);
        }
      };

      // Kick off the data loads once.
      Promise.all(schedulesToLoad.map(config => loadSchedule(config)));

      // Re-apply on every route change (Discourse re-renders the header outlet),
      // and once now in case the header is already mounted.
      api.onPageChange(() => { render(); updateCountdown(); });
      render();
      updateCountdown();

      // Self-healing tick: repopulates any freshly re-rendered (empty) nodes and
      // keeps the countdown ticking. render()/updateCountdown() are cheap no-ops
      // when nothing needs doing.
      setInterval(() => { render(); updateCountdown(); }, 1000);
});
