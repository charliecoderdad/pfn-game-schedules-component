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
       * Gets the current date in the 'America/New_York' (EST/EDT) timezone.
       * @returns {string} The current date as a 'YYYY-MM-DD' string.
       */
      const getTodayInEST = () => {
        const now = new Date();
        // Use Intl.DateTimeFormat to get date parts for the specified timezone.
        const formatter = new Intl.DateTimeFormat('en-CA', {
          timeZone: 'America/New_York',
          year: 'numeric',
          month: '2-digit',
          day: '2-digit'
        });
        // 'en-CA' locale reliably gives YYYY-MM-DD format.
        return formatter.format(now);
      };

      // ================================================================
      // Kickoff Countdown pill (mockup take #7). Hard-coded target date —
      // update once a season. The pill only renders while kickoff is in the
      // future, and hides itself the moment the countdown reaches zero.
      // ================================================================
      const KICKOFF_TARGET = new Date('August 29, 2026 00:00:01');
      const COUNTDOWN_ICON = 'https://pfn-static.s3.us-east-2.amazonaws.com/images/kickoff-countdown-icon.png';

      const pad2 = (n) => (n < 10 ? '0' : '') + n;

      // Static skeleton for the countdown pill; numbers are filled by updateCountdown().
      const COUNTDOWN_SKELETON = `
                        <img src="${COUNTDOWN_ICON}" alt="Kickoff Countdown" class="sport-icon">
                        <div class="cdlabel"><span class="l1">Kickoff</span><span class="l2">Countdown</span></div>
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

      // Cache of computed pill HTML keyed by divId. Populated once by the
      // fetches below; the render pass reads from here so it never depends on
      // the network resolving at a particular moment.
      const pillHtml = {};

      // Apply cached content into the CURRENT header DOM. Idempotent and safe to
      // call as often as we like: it no-ops when the nodes are already populated,
      // and (re)fills fresh/empty nodes after Discourse re-renders the header.
      // This is the fix for the old race where getElementById ran after `await
      // fetch` and hit a null (already-replaced) node.
      const render = () => {
        // Countdown pill.
        const cdBox = document.getElementById('kickoff-countdown');
        if (cdBox && KICKOFF_TARGET.getTime() - Date.now() > 0) {
          if (cdBox.dataset.rendered !== '1') {
            cdBox.innerHTML = COUNTDOWN_SKELETON;
            cdBox.style.display = 'flex';
            cdBox.dataset.rendered = '1';
          }
        }

        // Game pills.
        for (const config of schedulesToLoad) {
          const html = pillHtml[config.divId];
          if (!html) continue; // not loaded yet, or no upcoming game
          const div = document.getElementById(config.divId);
          if (!div || div.dataset.rendered === '1') continue;
          div.innerHTML = html;
          div.style.display = 'flex';
          div.dataset.rendered = '1';
        }
      };

      // Update the live countdown numbers on whatever node is currently mounted.
      const updateCountdown = () => {
        const box = document.getElementById('kickoff-countdown');
        if (!box) return;

        let secondsLeft = (KICKOFF_TARGET.getTime() - Date.now()) / 1000;
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

      const loadSchedule = async (config) => {
        try {
          const response = await fetch(config.url);
          if (!response.ok) throw new Error(`HTTP error! Status: ${response.status}`);

          const games = await response.json();

          // Get today's date as a string according to the EST timezone.
          const todayESTString = getTodayInEST();

          // Sort games by date using simple string comparison, which is reliable for YYYY-MM-DD format.
          games.sort((a, b) => a.date.localeCompare(b.date));

          // Find the first game where the date string is on or after today's date string.
          const upcomingGame = games.find(game => game.date >= todayESTString);

          if (upcomingGame) {
            pillHtml[config.divId] = buildGameHtml(config, upcomingGame);
            render(); // apply as soon as this schedule is ready
          }
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
