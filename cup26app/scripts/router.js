import { store, getTeam, getStadium, getMatchSummary,
         formatLocalTime, dmsToDecimal, t, td } from './data.js';

const routes = {
    '/': () => {
        const now = new Date();
        const today = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;

        const todayMatches   = store.main.matches.filter(m => m.date === today);
        const upcomingMatches = store.main.matches.filter(m => m.date >= today).slice(0, 4);

        const displayMatches = todayMatches.length > 0 ? todayMatches : upcomingMatches;
        const title = todayMatches.length > 0 ? t('todays_matches') : t('next_matches');

        return `
            <div class="hero">
                <h2>${t('hero_title')}</h2>
                <p>${t('hero_subtitle')}</p>
            </div>
            <h3>${title}</h3>
            <div class="match-list">
                ${displayMatches.map(renderMatchCard).join('')}
            </div>
        `;
    },

    '/schedule': () => {
        const fullHash  = window.location.hash.slice(1);
        const urlParams = new URLSearchParams(fullHash.includes('?') ? fullHash.split('?')[1] : '');
        const filter    = urlParams.get('filter') || 'completed';

        let filteredMatches = store.main.matches;
        if (filter === 'completed') {
            filteredMatches = filteredMatches.filter(m => !!m.score);
        } else if (filter === 'upcoming') {
            filteredMatches = filteredMatches.filter(m => !m.score);
        }

        const groups = filteredMatches.reduce((acc, m) => {
            const key = m.round;
            if (!acc[key]) acc[key] = [];
            acc[key].push(m);
            return acc;
        }, {});

        const filterBar = `
            <div class="filter-bar">
                <button class="btn-filter ${filter === 'completed' ? 'active' : ''}" 
                        onclick="location.hash='#/schedule?filter=completed'">${t('filter_completed')}</button>
                <button class="btn-filter ${filter === 'upcoming' ? 'active' : ''}" 
                        onclick="location.hash='#/schedule?filter=upcoming'">${t('filter_upcoming')}</button>
            </div>
        `;

        const content = Object.entries(groups).map(([round, matches]) => `
            <div class="round-section">
                <h3 class="round-title">${td(round)}</h3>
                <div class="match-list">${matches.map(renderMatchCard).join('')}</div>
            </div>
        `).join('');

        return `<h2>${t('schedule')}</h2>` + filterBar + (content || `<p class="empty-state">${t('no_results')} —</p>`);
    },

    '/groups': () =>
        `<h2>${t('groups')}</h2>` + store.groups.groups.map(renderGroupTable).join(''),

    '/scorers': () => {
        // Aggregate goals from goals1 / goals2 across all finished matches
        const scorerMap = {};

        store.main.matches.forEach(m => {
            if (!m.score) return;

            const addGoals = (goalsList, teamName) => {
                (goalsList || []).forEach(g => {
                    if (!g.name) return;
                    if (!scorerMap[g.name]) {
                        scorerMap[g.name] = { name: g.name, team: teamName, goals: 0, matchSet: new Set() };
                    }
                    scorerMap[g.name].goals++;
                    scorerMap[g.name].matchSet.add(`${m.date}-${m.team1}-${m.team2}`);
                });
            };

            addGoals(m.goals1, m.team1);
            addGoals(m.goals2, m.team2);
        });

        const scorers = Object.values(scorerMap)
            .map(s => ({ ...s, matchCount: s.matchSet.size }))
            .sort((a, b) => b.goals - a.goals || a.name.localeCompare(b.name));

        if (scorers.length === 0) {
            return `<h2>${t('top_scorers')}</h2><p class="empty-state">${t('no_results')} —</p>`;
        }

        // Assign ranks (tied players share same rank number)
        let currentRank = 1;
        const ranked = scorers.map((s, i) => {
            if (i > 0 && s.goals < scorers[i - 1].goals) currentRank = i + 1;
            return { ...s, rank: currentRank };
        });

        return `
            <h2>${t('top_scorers')}</h2>
            <div class="scorers-list">
                ${ranked.map(s => renderScorerCard(s)).join('')}
            </div>
        `;
    },

    '/teams': () => `
        <h2>${t('teams')}</h2>
        <div class="team-grid">
            ${store.teams.map(tm => `
                <a href="#/teams/${tm.fifa_code}" class="team-card-link">
                    <div class="team-card">
                        <span class="flag">${tm.flag_icon}</span>
                        <span class="name">${td(tm.name)}</span>
                        <span class="code">${tm.fifa_code}</span>
                    </div>
                </a>
            `).join('')}
        </div>
    `,

    '/teams/': () => {
        const fullHash = window.location.hash.slice(1);
        const code = fullHash.split('/').pop();
        const team = store.teams.find(t => t.fifa_code === code);
        const squad = store.squads.find(s => s.fifa_code === code);

        if (!team || !squad) return `<h2>${t('teams')}</h2><p>${t('no_results')}</p>`;

        return `
            <div class="squad-header">
                <a href="#/teams" class="btn-back">← ${t('teams')}</a>
                <h2>${team.flag_icon} ${td(team.name)}</h2>
            </div>
            <div class="squad-list">
                <table class="squad-table">
                    <thead>
                        <tr>
                            <th>#</th>
                            <th>${t('pos')}</th>
                            <th>${t('player')}</th>
                            <th>${t('club')}</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${squad.players.map(p => `
                            <tr>
                                <td class="player-num">${p.number}</td>
                                <td class="player-pos">${p.pos}</td>
                                <td class="player-name">
                                    <div class="name-main">${p.name}</div>
                                    <div class="player-dob">${p.date_of_birth}</div>
                                </td>
                                <td class="player-club">
                                    <div class="club-name">${p.club.name}</div>
                                    <div class="club-country">${p.club.country}</div>
                                </td>
                            </tr>
                        `).join('')}
                    </tbody>
                </table>
            </div>
        `;
    },

    '/stadiums': () => `
        <h2>${t('stadiums')}</h2>
        <div class="stadium-list">
            ${store.stadiums.stadiums.map(s => renderStadiumCard(s)).join('')}
        </div>
    `,

    '/search': () => {
        const fullHash  = window.location.hash.slice(1);
        const urlParams = new URLSearchParams(fullHash.includes('?') ? fullHash.split('?')[1] : '');
        const query     = urlParams.get('q')?.toLowerCase() || '';

        if (!query) return `<h2>${t('search_results')}</h2><p>${t('search_placeholder')}</p>`;

        const filteredTeams    = store.teams.filter(tm =>
            tm.name.toLowerCase().includes(query) || tm.fifa_code.toLowerCase().includes(query));
        const filteredStadiums = store.stadiums.stadiums.filter(s =>
            s.name.toLowerCase().includes(query) || s.city.toLowerCase().includes(query));
        const teamMatches      = store.main.matches.filter(m =>
            m.team1.toLowerCase().includes(query) || m.team2.toLowerCase().includes(query));
        const venueMatches     = store.main.matches.filter(m =>
            !teamMatches.includes(m) && m.ground.toLowerCase().includes(query));

        return `
            <h2>${t('search_results')} "${query}"</h2>

            ${filteredTeams.length > 0 ? `
                <h3>${t('teams')}</h3>
                <div class="team-grid">
                    ${filteredTeams.map(tm => `
                        <a href="#/teams/${tm.fifa_code}" class="team-card-link">
                            <div class="team-card">
                                <span class="flag">${tm.flag_icon}</span>
                                <span class="name">${td(tm.name)}</span>
                                <span class="code">${tm.fifa_code}</span>
                            </div>
                        </a>
                    `).join('')}
                </div>
            ` : ''}

            ${filteredStadiums.length > 0 ? `
                <h3>${t('stadiums')}</h3>
                <div class="stadium-list">
                    ${filteredStadiums.map(s => renderStadiumCard(s)).join('')}
                </div>
            ` : ''}

            ${teamMatches.length > 0 ? `
                <h3>${t('team_matches')}</h3>
                <div class="match-list">${teamMatches.map(renderMatchCard).join('')}</div>
            ` : ''}

            ${venueMatches.length > 0 ? `
                <h3>${t('venue_matches').replace('{city}', query.charAt(0).toUpperCase() + query.slice(1))}</h3>
                <div class="match-list">${venueMatches.map(renderMatchCard).join('')}</div>
            ` : ''}

            ${filteredTeams.length === 0 && filteredStadiums.length === 0 &&
              teamMatches.length === 0 && venueMatches.length === 0 ? `
                <p>${t('no_results')} "${query}".</p>
            ` : ''}
        `;
    }
};

/* ── Stadium card ─────────────────────────────────────────────────── */
function renderStadiumCard(s) {
    const loc     = store.stadiumlocMap?.[s.name];        // may be undefined
    const imgFile = loc?.imgfile;
    const coords  = loc?.coords;
    const decimal = dmsToDecimal(coords);

    // Google Maps URL — works in any browser/app; on Android opens the Maps app
    const mapsUrl = decimal
        ? `https://www.google.com/maps?q=${decimal.lat},${decimal.lng}`
        : coords
            ? `https://www.google.com/maps?q=${encodeURIComponent(coords)}`
            : null;

    return `
        <div class="card stadium-card">
            ${imgFile ? `
                <div class="stadium-img-wrap">
                    <img
                        src="imgs/${imgFile}"
                        alt="${s.name}"
                        class="stadium-img"
                        loading="lazy"
                        onerror="this.closest('.stadium-img-wrap').style.display='none'"
                    >
                </div>
            ` : ''}
            <div class="stadium-info">
                <h4>${s.name}</h4>
                <p>📍 ${td(s.city)}, ${s.cc.toUpperCase()}</p>
                <p>👥 ${s.capacity.toLocaleString()}</p>
                ${mapsUrl ? `
                    <a href="${mapsUrl}" target="_blank" rel="noopener noreferrer"
                       class="btn-map">
                        🗺️ View Location
                    </a>
                ` : ''}
            </div>
        </div>
    `;
}

/* ── Scorer card ──────────────────────────────────────────────────── */
function renderScorerCard(s) {
    const teamObj   = getTeam(s.team);
    const goalsWord = s.goals === 1 ? t('scorers_goal') : t('scorers_goals');
    const isTopThree = s.rank <= 3;

    // Medal for top 3
    const medals = { 1: '🥇', 2: '🥈', 3: '🥉' };
    const rankDisplay = medals[s.rank]
        ? `<span class="scorer-medal">${medals[s.rank]}</span>`
        : `<span class="scorer-rank">#${s.rank}</span>`;

    // Goal bar: width relative to top scorer's count (passed via dataset)
    const barPct = Math.round((s.goals / s.goals) * 100); // always 100% for self; parent sets max

    return `
        <div class="scorer-card ${isTopThree ? 'scorer-top' : ''}" data-goals="${s.goals}">
            <div class="scorer-left">
                ${rankDisplay}
                <div class="scorer-info">
                    <span class="scorer-name">${s.name}</span>
                    <span class="scorer-team">${teamObj.flag_icon} ${td(s.team)}</span>
                </div>
            </div>
            <div class="scorer-right">
                <span class="scorer-goals">${s.goals}</span>
                <span class="scorer-goals-label">${goalsWord}</span>
            </div>
        </div>
    `;
}

/* ── Match card ───────────────────────────────────────────────────── */
function renderMatchCard(m) {
    const t1       = getTeam(m.team1);
    const t2       = getTeam(m.team2);
    const stadium  = getStadium(m.ground);
    const hasScore = !!m.score;
    const score    = hasScore ? `${m.score.ft[0]} - ${m.score.ft[1]}` : 'vs';
    const summary  = hasScore ? getMatchSummary(m.date, m.team1, m.team2) : null;
    const localTime = formatLocalTime(m.date, m.time);

    const goals1 = (m.goals1 || []).map(g => `<li>${g.name} (${g.minute}')</li>`).join('');
    const goals2 = (m.goals2 || []).map(g => `<li>${g.name} (${g.minute}')</li>`).join('');

    return `
        <div class="card match-card ${hasScore ? 'finished' : ''}" data-match-id="${m.date}-${m.team1}-${m.team2}">
            <div class="match-meta">
                <span>${m.date} | ${m.time}</span>
                <span>${stadium.name}</span>
            </div>
            ${localTime ? `<div class="local-time">🕒 ${t('local_time')}: ${localTime}</div>` : ''}
            <div class="match-teams">
                <div class="team">
                    <span class="flag">${t1.flag_icon}</span>
                    <span class="name">${td(m.team1)}</span>
                </div>
                <div class="score">${score}</div>
                <div class="team">
                    <span class="name">${td(m.team2)}</span>
                    <span class="flag">${t2.flag_icon}</span>
                </div>
            </div>
            ${hasScore ? `
            <div class="match-details" style="display: none;">
                <div class="goals-section">
                    <ul class="goals-list">${goals1}</ul>
                    <ul class="goals-list">${goals2}</ul>
                </div>
                ${summary ? `<div class="match-summary">${summary}</div>` : ''}
            </div>
            ` : ''}
        </div>
    `;
}

/* ── Group table ──────────────────────────────────────────────────── */
function renderGroupTable(group) {
    const stats = group.teams.map(teamName => {
        const teamMatches = store.main.matches.filter(m =>
            (m.team1 === teamName || m.team2 === teamName) && m.score);

        let gp=0, w=0, d=0, l=0, gf=0, ga=0, pts=0;
        teamMatches.forEach(m => {
            gp++;
            const isTeam1 = m.team1 === teamName;
            const score   = isTeam1 ? m.score.ft : [m.score.ft[1], m.score.ft[0]];
            gf += score[0]; ga += score[1];
            if      (score[0] > score[1]) { w++; pts += 3; }
            else if (score[0] === score[1]) { d++; pts += 1; }
            else    { l++; }
        });

        return { name: teamName, flag: getTeam(teamName).flag_icon, gp, w, d, l, gf, ga, gd: gf-ga, pts };
    }).sort((a, b) => b.pts - a.pts || b.gd - a.gd);

    return `
        <div class="card group-card">
            <h4>${td(group.name)}</h4>
            <table class="standings">
                <thead><tr>
                    <th>${t('standings.team')}</th>
                    <th>${t('standings.p')}</th>
                    <th>${t('standings.w')}</th>
                    <th>${t('standings.d')}</th>
                    <th>${t('standings.l')}</th>
                    <th>${t('standings.gd')}</th>
                    <th>${t('standings.pts')}</th>
                </tr></thead>
                <tbody>
                    ${stats.map(s => `
                        <tr>
                            <td class="team-cell">${s.flag} ${td(s.name)}</td>
                            <td>${s.gp}</td><td>${s.w}</td><td>${s.d}</td><td>${s.l}</td>
                            <td>${s.gd > 0 ? '+' : ''}${s.gd}</td>
                            <td><strong>${s.pts}</strong></td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        </div>
    `;
}

/* ── Router init ──────────────────────────────────────────────────── */
export function initRouter() {
    const handleRoute = () => {
        const fullHash  = window.location.hash.slice(1) || '/';
        const routePath = fullHash.split('?')[0];
        
        // Find matching route - support exact match or dynamic prefix
        let viewFunc = routes[routePath];
        if (!viewFunc) {
            // Find longest matching prefix route that ends with /
            const dynamicRoute = Object.keys(routes)
                .filter(r => r.length > 1 && r.endsWith('/'))
                .find(r => routePath.startsWith(r));
            if (dynamicRoute) viewFunc = routes[dynamicRoute];
        }
        
        if (!viewFunc) viewFunc = routes['/'];

        document.getElementById('app').innerHTML = viewFunc();
        window.scrollTo(0, 0);

        document.querySelectorAll('.nav-item').forEach(nav => {
            const navHref = nav.getAttribute('href').slice(1) || '/';
            const isActive = navHref === '/' 
                ? routePath === '/' 
                : routePath.startsWith(navHref);
            nav.classList.toggle('active', isActive);
        });
    };

    document.getElementById('app').addEventListener('click', (e) => {
        const card = e.target.closest('.match-card.finished');
        if (card) {
            const details  = card.querySelector('.match-details');
            if (details) {
                const isExpanded = details.style.display === 'block';
                details.style.display = isExpanded ? 'none' : 'block';
                card.classList.toggle('expanded', !isExpanded);
            }
        }
    });

    window.addEventListener('hashchange', handleRoute);
    handleRoute();
}

