import { fetchData, store, setLanguage, t } from './data.js';
import { initRouter } from './router.js';

window.changeLang = (l) => setLanguage(l);

document.addEventListener('DOMContentLoaded', async () => {
    document.documentElement.lang = localStorage.getItem('wc_lang') || 'en';
    document.documentElement.dir = document.documentElement.lang === 'ar' ? 'rtl' : 'ltr';

    try {
        await fetchData();

        document.getElementById('loading').innerText = t('loading');
        document.getElementById('global-search').placeholder = t('search_placeholder');
        document.getElementById('label-home').innerText     = t('home');
        document.getElementById('label-schedule').innerText = t('schedule');
        document.getElementById('label-groups').innerText   = t('groups');
        document.getElementById('label-scorers').innerText  = t('scorers');
        document.getElementById('label-teams').innerText    = t('teams');
        document.getElementById('label-stadiums').innerText = t('stadiums');

        initRouter();

        const searchInput = document.getElementById('global-search');
        searchInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                const query = e.target.value.trim();
                if (query) {
                    window.location.hash = `#/search?q=${encodeURIComponent(query)}`;
                }
            }
        });
    } catch (e) {
        document.getElementById('app').innerHTML = t('failed_load');
    }
});

