const https = require('https');
const http  = require('http');

// ── HTTP helper with redirect support ─────────────────────────────────────
function fetchUrl(urlStr, customHeaders = {}) {
  return new Promise((resolve, reject) => {
    const client = urlStr.startsWith('https') ? https : http;
    const defaultHeaders = {
      'User-Agent': 'FeedFlow/1.0 (personal RSS reader)',
      'Accept': 'application/json, application/rss+xml, application/xml, text/xml, */*',
    };
    const options = { headers: { ...defaultHeaders, ...customHeaders } };

    const req = client.get(urlStr, options, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        const next = res.headers.location.startsWith('http')
          ? res.headers.location
          : new URL(res.headers.location, urlStr).href;
        return fetchUrl(next, customHeaders).then(resolve).catch(reject);
      }
      if (res.statusCode !== 200) {
        return reject(new Error(`HTTP ${res.statusCode} for ${urlStr}`));
      }
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve(data));
    });
    req.on('error', reject);
    req.setTimeout(12000, () => { req.destroy(); reject(new Error('Request timeout')); });
  });
}

// ── HTTP POST helper (for OAuth token request) ────────────────────────────
function postUrl(urlStr, body, customHeaders = {}) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(urlStr);
    const options = {
      hostname: urlObj.hostname,
      path: urlObj.pathname + urlObj.search,
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(body),
        ...customHeaders,
      },
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode !== 200) {
          return reject(new Error(`HTTP ${res.statusCode}: ${data}`));
        }
        resolve(data);
      });
    });
    req.on('error', reject);
    req.setTimeout(10000, () => { req.destroy(); reject(new Error('Timeout')); });
    req.write(body);
    req.end();
  });
}

// ── Reddit OAuth: get app-only access token ───────────────────────────────
// Uses client_credentials grant — no user login needed, free tier, 60 req/min
async function getRedditToken() {
  const clientId     = process.env.REDDIT_CLIENT_ID;
  const clientSecret = process.env.REDDIT_CLIENT_SECRET;

  if (!clientId || !clientSecret) {
    throw new Error('REDDIT_CLIENT_ID / REDDIT_CLIENT_SECRET env vars not set');
  }

  const credentials = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');
  const body = 'grant_type=client_credentials';

  const raw = await postUrl('https://www.reddit.com/api/v1/access_token', body, {
    'Authorization': `Basic ${credentials}`,
    'User-Agent': 'FeedFlow/1.0 (by /u/feedflow_app)',
  });

  const data = JSON.parse(raw);
  if (!data.access_token) throw new Error(`Token error: ${JSON.stringify(data)}`);
  return data.access_token;
}

// ── Fetch subreddit via authenticated OAuth API ───────────────────────────
async function fetchRedditOAuth(urlParam) {
  const token = await getRedditToken();

  // Convert reddit.com URL → oauth.reddit.com URL
  // e.g. https://www.reddit.com/r/SaaS/.rss → https://oauth.reddit.com/r/SaaS.json
  const subMatch = urlParam.match(/\/r\/([^/?#]+)/);
  if (!subMatch) throw new Error('Could not extract subreddit from URL');
  const subreddit = subMatch[1];

  const apiUrl = `https://oauth.reddit.com/r/${subreddit}/hot.json?limit=25`;
  console.log(`Reddit OAuth: fetching ${apiUrl}`);

  const raw = await fetchUrl(apiUrl, {
    'Authorization': `Bearer ${token}`,
    'User-Agent': 'FeedFlow/1.0 (by /u/feedflow_app)',
    'Accept': 'application/json',
  });

  return { raw, subreddit };
}

// ── Parse Reddit OAuth JSON response ─────────────────────────────────────
function parseRedditJson(raw, subreddit) {
  const data = JSON.parse(raw);
  const posts = data?.data?.children || [];
  const channel = { title: `r/${subreddit}` };

  const items = posts
    .filter(({ data: p }) => p && (p.title || p.url))
    .map(({ data: p }) => {
      let thumbnail = '';
      if (p.preview?.images?.[0]?.source?.url) {
        thumbnail = p.preview.images[0].source.url.replace(/&amp;/g, '&');
      } else if (p.thumbnail && p.thumbnail.startsWith('http')) {
        thumbnail = p.thumbnail;
      }

      const description = (p.selftext || p.url_overridden_by_dest || '')
        .replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 300);

      return {
        title:       p.title        || '',
        link:        `https://reddit.com${p.permalink}`,
        description,
        pubDate:     new Date(p.created_utc * 1000).toISOString(),
        author:      p.author       || '',
        thumbnail,
        guid:        p.id           || p.name,
        category:    p.link_flair_text || '',
        score:       p.score        || 0,
        numComments: p.num_comments || 0,
      };
    });

  return { channel, items };
}

// ── Atom feed parser ──────────────────────────────────────────────────────
function parseAtom(xml) {
  const get = (block, tag) => {
    const r = new RegExp(`<${tag}[^>]*>(?:<!\\[CDATA\\[)?([\\s\\S]*?)(?:\\]\\]>)?<\\/${tag}>`, 'i');
    return (block.match(r)?.[1] || '').trim();
  };
  const getAttr = (block, tag, attr) => {
    const r = new RegExp(`<${tag}[^>]*${attr}=["']([^"']+)["'][^>]*\\/?>`, 'i');
    return block.match(r)?.[1] || '';
  };

  const titleMatch = xml.match(/<title[^>]*>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?<\/title>/i);
  const channel = { title: (titleMatch?.[1] || 'Feed').trim() };

  const items = [];
  const entryRegex = /<entry>([\s\S]*?)<\/entry>/g;
  let m;
  while ((m = entryRegex.exec(xml)) !== null) {
    const block = m[1];
    const rawDesc = get(block, 'content') || get(block, 'summary');
    const description = rawDesc.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 300);

    let thumbnail = '';
    const imgSrc = rawDesc.match(/<img[^>]+src=["']([^"']+)["']/i);
    if (imgSrc) thumbnail = imgSrc[1];

    const link  = getAttr(block, 'link', 'href') || get(block, 'link');
    const title = get(block, 'title');
    if (!title && !link) continue;

    items.push({
      title,
      link,
      description,
      pubDate:  new Date(get(block, 'updated') || get(block, 'published') || Date.now()).toISOString(),
      author:   (get(block, 'name') || get(block, 'author')).replace(/<[^>]+>/g, '').trim(),
      thumbnail,
      guid:     get(block, 'id') || link,
      category: getAttr(block, 'category', 'term') || get(block, 'category'),
    });
  }
  return { channel, items };
}

// ── RSS 2.0 parser ────────────────────────────────────────────────────────
function parseRss(xml) {
  const get = (block, tag) => {
    const r = new RegExp(`<${tag}[^>]*>(?:<!\\[CDATA\\[)?([\\s\\S]*?)(?:\\]\\]>)?<\\/${tag}>`, 'i');
    return (block.match(r)?.[1] || '').trim();
  };
  const getAttr = (block, tag, attr) => {
    const r = new RegExp(`<${tag}[^>]*${attr}=["']([^"']+)["'][^>]*>`, 'i');
    return block.match(r)?.[1] || '';
  };

  const titleMatch = xml.match(/<channel[^>]*>[\s\S]*?<title[^>]*>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?<\/title>/i);
  const channel = { title: (titleMatch?.[1] || 'RSS Feed').trim() };

  const items = [];
  const itemRegex = /<item>([\s\S]*?)<\/item>/g;
  let m;
  while ((m = itemRegex.exec(xml)) !== null) {
    const block = m[1];
    const rawDesc = get(block, 'description');
    const description = rawDesc.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 300);

    let thumbnail = getAttr(block, 'media:thumbnail', 'url')
      || getAttr(block, 'media:content', 'url')
      || getAttr(block, 'enclosure', 'url')
      || '';
    if (!thumbnail) {
      const imgSrc = rawDesc.match(/<img[^>]+src=["']([^"']+)["']/i);
      if (imgSrc) thumbnail = imgSrc[1];
    }

    const link  = get(block, 'link') || getAttr(block, 'link', 'href');
    const title = get(block, 'title');
    if (!title && !link) continue;

    const rawDate = get(block, 'pubDate') || get(block, 'dc:date') || get(block, 'published');

    items.push({
      title,
      link,
      description,
      pubDate:  rawDate ? new Date(rawDate).toISOString() : new Date().toISOString(),
      author:   (get(block, 'author') || get(block, 'dc:creator')).replace(/<[^>]+>/g, '').trim(),
      thumbnail,
      guid:     get(block, 'guid') || get(block, 'id') || link,
      category: get(block, 'category'),
    });
  }
  return { channel, items };
}

// ── Netlify handler ───────────────────────────────────────────────────────
exports.handler = async function (event) {
  const headers = {
    'Access-Control-Allow-Origin':  '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Content-Type': 'application/json',
  };

  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers, body: '' };
  }

  // ── PROXY PATH: forward any URL and return raw response ────────────────
  // Used for APIs that block CORS (e.g. feedsearch.dev)
  const proxyParam = event.queryStringParameters?.proxy;
  if (proxyParam) {
    try {
      console.log(`Proxy fetching: ${proxyParam}`);
      const raw = await fetchUrl(proxyParam, { 'Accept': 'application/json' });
      return { statusCode: 200, headers, body: raw };
    } catch (err) {
      console.error('Proxy error:', err.message);
      return { statusCode: 500, headers, body: JSON.stringify({ error: err.message }) };
    }
  }

  const urlParam = event.queryStringParameters?.url;
  if (!urlParam) {
    return { statusCode: 400, headers, body: JSON.stringify({ error: 'Missing url parameter' }) };
  }

  try {
    const isReddit = urlParam.includes('reddit.com');

    // ── REDDIT PATH: proper OAuth ─────────────────────────────────────────
    if (isReddit) {
      const { raw, subreddit } = await fetchRedditOAuth(urlParam);
      const { channel, items } = parseRedditJson(raw, subreddit);
      console.log(`Reddit OAuth → ${items.length} items from r/${subreddit}`);

      return {
        statusCode: 200,
        headers,
        body: JSON.stringify({ channel, items, fetchedAt: new Date().toISOString() }),
      };
    }

    // ── GENERIC RSS / ATOM PATH ───────────────────────────────────────────
    const raw = await fetchUrl(urlParam);

    let result;
    if (raw.includes('<feed') || raw.includes('xmlns="http://www.w3.org/2005/Atom"')) {
      result = parseAtom(raw);
      console.log(`Atom → ${result.items.length} items`);
    } else {
      result = parseRss(raw);
      console.log(`RSS → ${result.items.length} items`);
    }

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({ ...result, fetchedAt: new Date().toISOString() }),
    };

  } catch (err) {
    console.error('rss function error:', err.message);
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({ error: err.message }),
    };
  }
};

