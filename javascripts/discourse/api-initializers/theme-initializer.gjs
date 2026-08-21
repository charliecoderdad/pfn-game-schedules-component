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

      const renderCountdown = () => {
        const box = document.getElementById('kickoff-countdown');
        if (!box) return;

        // Already past kickoff? Leave it hidden entirely.
        if (KICKOFF_TARGET.getTime() - Date.now() <= 0) return;

        box.innerHTML = `
                        <img src="${COUNTDOWN_ICON}" alt="Kickoff Countdown" class="sport-icon">
                        <div class="cdlabel"><span class="l1">Kickoff</span><span class="l2">Countdown</span></div>
                        <div class="cd-units">
                            <div class="cd-unit cd-days"><span class="num cd-d">00</span><span class="lab">Days</span></div>
                            <div class="cd-unit"><span class="num cd-h">00</span><span class="lab">Hrs</span></div>
                            <div class="cd-unit"><span class="num cd-m">00</span><span class="lab">Min</span></div>
                            <div class="cd-unit"><span class="num cd-s">00</span><span class="lab">Sec</span></div>
                        </div>
                    `;
        box.style.display = 'flex';

        const dEl = box.querySelector('.cd-d');
        const hEl = box.querySelector('.cd-h');
        const mEl = box.querySelector('.cd-m');
        const sEl = box.querySelector('.cd-s');

        const tick = () => {
          let secondsLeft = (KICKOFF_TARGET.getTime() - Date.now()) / 1000;
          if (secondsLeft <= 0) {
            box.style.display = 'none';
            return false; // stop ticking
          }
          dEl.textContent = pad2(parseInt(secondsLeft / 86400)); secondsLeft %= 86400;
          hEl.textContent = pad2(parseInt(secondsLeft / 3600));  secondsLeft %= 3600;
          mEl.textContent = pad2(parseInt(secondsLeft / 60));
          sEl.textContent = pad2(parseInt(secondsLeft % 60));
          return true;
        };

        tick();
        const timer = setInterval(() => { if (!tick()) clearInterval(timer); }, 1000);
      };

      const processSchedule = async (config) => {
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
            const targetDiv = document.getElementById(config.divId);

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

            targetDiv.innerHTML = `
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

            targetDiv.style.display = 'flex';
          }
        } catch (error) {
          console.error(`Could not load schedule for ${config.title}:`, error);
        }
      };
      renderCountdown();
      Promise.all(schedulesToLoad.map(config => processSchedule(config)));
});
