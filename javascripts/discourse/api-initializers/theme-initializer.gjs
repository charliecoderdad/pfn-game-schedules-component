import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
      const schedulesToLoad = [
        {
          divId: 'football',
          title: 'Football',
          url: 'https://pfn-static.s3.us-east-2.amazonaws.com/schedule-football.json?v=2025-10-17',
          iconUrl: 'https://pfn-static.s3.us-east-2.amazonaws.com/images/football-game-schedule-icon.png'
        },
        {
          divId: 'mens-basketball',
          title: 'Men\'s Basketball',
          url: 'https://pfn-static.s3.us-east-2.amazonaws.com/schedule-mens-basketball.json?v=2025-10-17',
          iconUrl: 'https://pfn-static.s3.us-east-2.amazonaws.com/images/mens-basketball-game-schedule-icon.png'
        },
        {
          divId: 'womens-basketball',
          title: 'Women\'s Basketball',
          url: 'https://pfn-static.s3.us-east-2.amazonaws.com/schedule-womens-basketball.json?v=2025-10-17',
          iconUrl: 'https://pfn-static.s3.us-east-2.amazonaws.com/images/womens-basketball-game-schedule-icon.png'
        },
        {
          divId: 'baseball',
          title: 'Baseball',
          url: 'https://pfn-static.s3.us-east-2.amazonaws.com/schedule-baseball.json?v=2025-10-17',
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
            const formattedDate = gameDate.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });

            const dateTimeString = upcomingGame.time === 'TBD'
              ? formattedDate
              : `${formattedDate}, ${upcomingGame.time}`;

            targetDiv.innerHTML = `
                            <img src="${config.iconUrl}" alt="${config.title} icon" class="sport-icon">
                            <div class="game-details">
                                <p><strong>Opponent:</strong> ${upcomingGame.opponent}</p>
                                <p><strong>Date:</strong> ${dateTimeString}</p>
                                <p><strong>Location:</strong> ${upcomingGame.location}</p>
                            </div>
                        `;

            targetDiv.style.display = 'flex';
          }
        } catch (error) {
          console.error(`Could not load schedule for ${config.title}:`, error);
        }
      };
      Promise.all(schedulesToLoad.map(config => processSchedule(config)));
});
