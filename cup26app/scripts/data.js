export const store = {
    main: null, teams: null, groups: null, squads: null,
    stadiums: null, summaries: null, i18n: null,
    stadiumloc: null,   // ← new
    lang: 'en', isLoaded: false
};

export async function fetchData() {
    try {
        const files = [
            'worldcup.json',
            'worldcup.teams.json',
            'worldcup.groups.json',
            'worldcup.squads.json',
            'worldcup.stadiums.json',
            'worldcup.summaries.json',
            'i18n.json',
            'stadiumloc.json'   // ← new
        ];
        const results = await Promise.all(files.map(f => fetch(f).then(res => res.json())));
        [store.main, store.teams, store.groups, store.squads,
         store.stadiums, store.summaries, store.i18n,
         store.stadiumloc] = results;

        // Build a lookup map: stadium name → loc entry
        store.stadiumlocMap = {};
        for (const entry of store.stadiumloc) {
            store.stadiumlocMap[entry.stadium] = entry;
        }

        store.lang = localStorage.getItem('wc_lang') || 'en';

        store.main.matches.sort((a, b) => {
            if (a.date !== b.date) return a.date.localeCompare(b.date);
            return a.time.localeCompare(b.time);
        });

        store.isLoaded = true;
        return store;
    } catch (error) {
        console.error('Data error:', error);
        throw error;
    }
}

export function t(key) {
    const keys = key.split('.');
    let value = store.i18n[store.lang];
    for (const k of keys) {
        value = value?.[k];
    }
    return value || key;
}

export function td(str) {
    if (store.lang === 'en') return str;
    return store.i18n.data_translations[str] || str;
}

export function setLanguage(lang) {
    store.lang = lang;
    localStorage.setItem('wc_lang', lang);
    document.documentElement.lang = lang;
    document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';
    window.location.reload();
}

export function getMatchSummary(date, team1, team2) {
    return store.summaries.matches.find(
        s => s.date === date && s.team1 === team1 && s.team2 === team2
    )?.summary;
}

export function getTeam(name) {
    return store.teams.find(t => t.name === name || t.name_normalised === name) || { flag_icon: '🏳️' };
}

export function getStadium(city) {
    return store.stadiums.stadiums.find(s => s.city === city) || { name: city };
}

export function formatLocalTime(dateStr, timeStr) {
    const [time, utcOffset] = timeStr.split(' ');
    const offset = utcOffset.replace('UTC', '');
    const formattedOffset = offset.includes(':') ? offset :
        (offset.startsWith('-') || offset.startsWith('+') ?
            offset.slice(0, 1) + offset.slice(1).padStart(2, '0') + ':00' :
            '+' + offset.padStart(2, '0') + ':00');

    const isoString = `${dateStr}T${time}:00${formattedOffset}`;
    const date = new Date(isoString);
    if (isNaN(date.getTime())) return null;

    return new Intl.DateTimeFormat(undefined, {
        weekday: 'short', month: 'short', day: 'numeric',
        hour: 'numeric', minute: 'numeric', timeZoneName: 'short'
    }).format(date);
}

/**
 * Convert DMS string like "49°16'36"N 123°6'43"W" to decimal degrees.
 * Returns { lat, lng } or null if parsing fails.
 */
export function dmsToDecimal(coordStr) {
    if (!coordStr) return null;
    // Match pattern: degrees°minutes'seconds"direction
    const re = /(\d+)°(\d+)'([\d.]+)"([NSEW])/g;
    const parts = [...coordStr.matchAll(re)];
    if (parts.length < 2) return null;

    const toDecimal = (d, m, s, dir) => {
        let val = Number(d) + Number(m) / 60 + Number(s) / 3600;
        if (dir === 'S' || dir === 'W') val = -val;
        return val;
    };

    const [latPart, lngPart] = parts;
    return {
        lat: toDecimal(latPart[1], latPart[2], latPart[3], latPart[4]),
        lng: toDecimal(lngPart[1], lngPart[2], lngPart[3], lngPart[4])
    };
}

