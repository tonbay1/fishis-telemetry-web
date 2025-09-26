const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const PORT = process.env.PORT || 3001;
const DATA_FILE = path.join(__dirname, 'telemetry_data.json');
const KEYS_FILE = path.join(__dirname, 'keys.json');

// Sample data with the format React expects
const sampleData = [
  {
    "account": "tonbay2542",
    "playerName": "tonbay2542", 
    "money": 2810000,
    "coins": 2810000,
    "level": 275,
    "equippedRod": "Ghostfinn Rod",
    "location": "Fisherman Island",
    "rods": [],
    "baits": [],
    "materials": {},
    "rodsDetailed": [],
    "online": true,
    "timestamp": new Date().toISOString()
  }
];

// Initialize data file
if (!fs.existsSync(DATA_FILE)) {
    fs.writeFileSync(DATA_FILE, JSON.stringify(sampleData, null, 2));
}
if (!fs.existsSync(KEYS_FILE)) {
    fs.writeFileSync(KEYS_FILE, JSON.stringify([], null, 2));
}

function readData() {
    try {
        const data = fs.readFileSync(DATA_FILE, 'utf8');
        return JSON.parse(data);
    } catch (error) {
        console.error('Error reading data:', error);
        return sampleData;
    }
}

function writeData(data) {
    try {
        fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2));
        return true;
    } catch (error) {
        console.error('Error writing data:', error);
        return false;
    }
}

function readKeys() {
    try {
        const data = fs.readFileSync(KEYS_FILE, 'utf8');
        return JSON.parse(data);
    } catch (e) {
        return [];
    }
}

function writeKeys(arr) {
    try {
        fs.writeFileSync(KEYS_FILE, JSON.stringify(arr, null, 2));
        return true;
    } catch (e) {
        console.error('Error writing keys:', e);
        return false;
    }
}

function genKey() {
    if (crypto.randomUUID) return crypto.randomUUID();
    return crypto.randomBytes(16).toString('hex');
}

function isAuthorized(req) {
    const tok = process.env.ADMIN_TOKEN || '';
    if (!tok) return false;
    const h = req.headers['authorization'] || req.headers['Authorization'];
    if (!h || typeof h !== 'string') return false;
    if (h.startsWith('Bearer ')) return h.slice(7) === tok;
    return false;
}

// Preserve existing non-empty fields when incoming payload provides empty values
function sanitizeEntry(newEntry, oldEntry) {
    const entry = { ...newEntry };
    if (!oldEntry) return entry;

    // Arrays: keep existing if incoming is empty
    const arrayFields = ['rods', 'baits', 'rodsDetailed'];
    for (const k of arrayFields) {
        if (Array.isArray(entry[k]) && entry[k].length === 0 && Array.isArray(oldEntry[k]) && oldEntry[k].length > 0) {
            delete entry[k];
        }
    }

    // Objects: e.g., materials map – keep existing if incoming is empty object
    const objectFields = ['materials'];
    for (const k of objectFields) {
        const v = entry[k];
        const ov = oldEntry[k];
        const isEmptyObj = v && typeof v === 'object' && !Array.isArray(v) && Object.keys(v).length === 0;
        const oldNonEmptyObj = ov && typeof ov === 'object' && !Array.isArray(ov) && Object.keys(ov).length > 0;
        if (isEmptyObj && oldNonEmptyObj) {
            delete entry[k];
        }
    }

    // Strings: avoid replacing with empty/Unknown
    const stringFields = ['equippedRod', 'location'];
    for (const k of stringFields) {
        const v = entry[k];
        if ((v === '' || v === undefined || v === null || v === 'Unknown') && typeof oldEntry[k] === 'string' && oldEntry[k] !== '') {
            delete entry[k];
        }
    }

    return entry;
}

const server = http.createServer((req, res) => {
    // CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.setHeader('Access-Control-Max-Age', '86400');
    
    if (req.method === 'OPTIONS') {
        res.writeHead(204);
        res.end();
        return;
    }

    if (req.url.startsWith('/api/data') && req.method === 'GET') {
        const u = new URL(req.url, 'http://localhost');
        const qAccount = (u.searchParams.get('account') || '').trim();
        const qKey = (u.searchParams.get('key') || '').trim();
        let data = readData();
        if (qKey) {
            const keys = readKeys();
            const record = keys.find(k => k.key === qKey);
            if (record && !record.revoked && record.boundAccount) {
                const keyAcc = String(record.boundAccount).toLowerCase();
                data = data.filter(it => (
                    (it.account && String(it.account).toLowerCase() === keyAcc) ||
                    (it.playerName && String(it.playerName).toLowerCase() === keyAcc)
                ));
            } else {
                data = [];
            }
        }
        if (qAccount) {
            const key = qAccount.toLowerCase();
            data = data.filter(it => (
                (it.account && String(it.account).toLowerCase() === key) ||
                (it.playerName && String(it.playerName).toLowerCase() === key)
            ));
        }
        const enriched = data.map(item => {
            // Rods enrichment
            const rods = Array.isArray(item.rods) ? item.rods : [];
            const hasAstral = rods.some(r => typeof r === 'string' && r.toLowerCase().includes('astral rod'));
            const hasGhostfinn = rods.some(r => typeof r === 'string' && r.toLowerCase().includes('ghostfinn rod'));
            const specials = [];
            if (hasAstral) specials.push('Astral Rod');
            if (hasGhostfinn) specials.push('Ghostfinn Rod');
            const hasSpecial = specials.length > 0;
            let rodsDisplay = '';
            let rodsDisplayMode = '';
            let rodsHeadline = '';
            if (hasSpecial) {
                rodsDisplayMode = 'text';
                rodsDisplay = specials.join(' & ');
                rodsHeadline = rodsDisplay;
            } else {
                rodsDisplayMode = 'count';
                rodsDisplay = String(rods.length || 0);
                rodsHeadline = rodsDisplay;
            }

            // Baits enrichment (special: Corrupt Bait)
            const baits = Array.isArray(item.baits) ? item.baits : [];
            const hasCorrupt = baits.some(b => typeof b === 'string' && b.toLowerCase().includes('corrupt bait'));
            let baitsDisplay = '';
            let baitsDisplayMode = '';
            let baitsHeadline = '';
            if (hasCorrupt) {
                baitsDisplayMode = 'text';
                baitsDisplay = 'Corrupt Bait';
                baitsHeadline = baitsDisplay;
            } else {
                baitsDisplayMode = 'count';
                baitsDisplay = String(baits.length || 0);
                baitsHeadline = baitsDisplay;
            }

            return {
                ...item,
                rodsDisplay,
                rodsDisplayMode,
                rodsHasAstral: hasAstral,
                rodsHasGhostfinn: hasGhostfinn,
                rodsHasSpecial: hasSpecial,
                rodsSpecial: specials,
                rodsHeadline,
                baitsDisplay,
                baitsDisplayMode,
                baitsHasCorrupt: hasCorrupt,
                baitsHeadline,
            };
        });
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(enriched));
        console.log('📊 Served API data, entries:', enriched.length);
        return;
    }

    // Return latest single account entry
    if (req.url.startsWith('/api/latest/') && req.method === 'GET') {
        const account = decodeURIComponent(req.url.split('/api/latest/')[1] || '').trim();
        const data = readData();
        const key = account.toLowerCase();
        const entry = data.find(it => (
            (it.account && String(it.account).toLowerCase() === key) ||
            (it.playerName && String(it.playerName).toLowerCase() === key)
        ));
        if (entry) {
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify(entry));
            console.log('📦 Served latest for account:', account);
        } else {
            res.writeHead(404, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Not found' }));
            console.log('❔ Latest not found for account:', account);
        }
        return;
    }

    if (req.url === '/health' && req.method === 'GET') {
        const data = readData();
        const payload = { ok: true, now: new Date().toISOString(), entries: data.length, file: DATA_FILE };
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(payload));
        console.log('❤️  Health check - entries:', data.length);
        return;
    }

    // Issue a new key
    if (req.url === '/keys/new' && req.method === 'POST') {
        if (!isAuthorized(req)) {
            res.writeHead(401, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'unauthorized' }));
            return;
        }
        const arr = readKeys();
        const k = genKey();
        arr.push({ key: k, createdAt: new Date().toISOString(), boundAccount: null });
        writeKeys(arr);
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ key: k }));

        return;
    }

    // Revoke a key (admin only)
    if (req.url.startsWith('/keys/revoke/') && req.method === 'POST') {
        if (!isAuthorized(req)) {
            res.writeHead(401, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'unauthorized' }));
            return;
        }
        const key = decodeURIComponent(req.url.split('/keys/revoke/')[1] || '').trim();
        const arr = readKeys();
        const rec = arr.find(k => k.key === key);
        if (!rec) {
            res.writeHead(404, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'not_found' }));
            return;
        }
        rec.revoked = true;
        rec.revokedAt = new Date().toISOString();
        writeKeys(arr);
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ ok: true }));

        return;
    }

    // Rotate a key (admin only)
    if (req.url.startsWith('/keys/rotate/') && req.method === 'POST') {
        if (!isAuthorized(req)) {
            res.writeHead(401, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'unauthorized' }));
            return;
        }
        const oldKey = decodeURIComponent(req.url.split('/keys/rotate/')[1] || '').trim();
        const arr = readKeys();
        const rec = arr.find(k => k.key === oldKey);
        if (!rec) {
            res.writeHead(404, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'not_found' }));
            return;
        }
        rec.revoked = true; rec.revokedAt = new Date().toISOString();
        const newKey = genKey();
        const newRec = { key: newKey, createdAt: new Date().toISOString(), boundAccount: rec.boundAccount || null };
        arr.push(newRec);
        writeKeys(arr);
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ oldKey, newKey, boundAccount: newRec.boundAccount }));

        return;
    }

    // Serve loader script with embedded key
    if (req.url.startsWith('/script/') && req.method === 'GET') {
        const key = decodeURIComponent(req.url.split('/script/')[1] || '').trim();
        const keys = readKeys();
        const record = keys.find(k => k.key === key);
        const exists = !!record && !record.revoked;
        const proto = (req.headers['x-forwarded-proto'] || '').toString().toLowerCase() === 'https' ? 'https' : 'http';
        const host = req.headers.host || `localhost:${PORT}`;
        const base = process.env.PUBLIC_BASE_URL || `${proto}://${host}`;
        if (!exists) {
            res.writeHead(404, { 'Content-Type': 'text/plain' });
            res.end('// invalid key');
            return;
        }
        const telemetryUrl = process.env.CLIENT_LUA_URL || `${base}/payload/${key}`;
        const code = `-- FishIs loader generated by server\n` +
`getgenv().SHOP888 = {\n  key = "${key}",\n  apiBase = "${base}"\n}\n` +
`local DEBUG = false\n` +
`pcall(function()\n` +
`  local G = getgenv()\n` +
`  if type(G)=='table' and type(G.SHOP888)=='table' and G.SHOP888.debug==true then DEBUG=true end\n` +
`end)\n` +
`local function __fishis_fetch(u)\n` +
`  -- try game:HttpGet (some executors expose this)\n` +
`  local ok1, res1 = pcall(function() return game:HttpGet(u) end)\n` +
`  if ok1 and res1 then return res1 end\n` +
`  -- try executor request() variants\n` +
`  local req = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request\n` +
`  if req then\n` +
`    local ok2, r = pcall(req, { Url = u, Method = 'GET' })\n` +
`    if ok2 and r then\n` +
`      local sc = r.StatusCode or r.status or r.Status or r.code\n` +
`      if sc == 200 or sc == 201 then return r.Body or r.body or '' end\n` +
`    end\n` +
`  end\n` +
`  -- try HttpService:GetAsync as last resort\n` +
`  local ok3, res3 = pcall(function() return game:GetService('HttpService'):GetAsync(u) end)\n` +
`  if ok3 and res3 then return res3 end\n` +
`  return nil\n` +
`end\n` +
`task.spawn(function()\n` +
`  local ok, err = pcall(function()\n` +
`    if DEBUG then pcall(function() print('[FishIs] Loading telemetry from:', '${telemetryUrl}') end) end\n` +
`    local src = __fishis_fetch('${telemetryUrl}')\n` +
`    if not src then error('fetch_failed') end\n` +
`    local f = loadstring(src)\n` +
`    if not f then error('compile_failed') end\n` +
`    f()\n` +
`  end)\n` +
`  if not ok then if DEBUG then pcall(function() warn('[FishIs] Telemetry load error:', tostring(err)) end) end end\n` +
`end)\n`;
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        res.end(code);

        return;
    }

    // Serve per-key payload (Lua) with a small watermark
    if (req.url.startsWith('/payload/') && req.method === 'GET') {
        const key = decodeURIComponent(req.url.split('/payload/')[1] || '').trim();
        const keys = readKeys();
        const record = keys.find(k => k.key === key);
        if (!record || record.revoked) {
            res.writeHead(404, { 'Content-Type': 'text/plain' });
            res.end('-- invalid key');
            return;
        }
        try {
            const p = path.join(__dirname, '..', 'client', 'working_simple_telemetry.lua');
            const content = fs.readFileSync(p, 'utf8');
            const header = `-- FishIs payload for key ${key} at ${new Date().toISOString()}\n`;
            res.writeHead(200, { 'Content-Type': 'text/plain' });
            res.end(header + content);

        } catch (e) {
            res.writeHead(500, { 'Content-Type': 'text/plain' });
            res.end('-- failed to load payload');
        }
        return;
    }



    if (req.url === '/telemetry' && req.method === 'POST') {
        let body = '';
        req.on('data', chunk => {
            body += chunk.toString();
        });
        req.on('end', () => {
            try {
                const newEntry = JSON.parse(body);
                console.log('📡 Telemetry received');
                
                const data = readData();
                // Bind key to account if provided
                const incomingKey = newEntry?.attributes?.key;
                if (incomingKey && typeof incomingKey === 'string') {
                    const keys = readKeys();
                    const rec = keys.find(k => k.key === incomingKey);
                    if (rec) {
                        if (!rec.boundAccount && newEntry.account) {
                            rec.boundAccount = newEntry.account;
                            writeKeys(keys);
                        }
                    } else {
                        // auto-register unknown key
                        keys.push({ key: incomingKey, createdAt: new Date().toISOString(), boundAccount: newEntry.account || null });
                        writeKeys(keys);
                    }
                }
                const existingIndex = data.findIndex(item => 
                    item.account === newEntry.account || 
                    item.playerName === newEntry.account ||
                    item.account === newEntry.playerName
                );

                const now = new Date().toISOString();
                const raw = { ...newEntry, timestamp: now, lastUpdated: now };
                const old = existingIndex >= 0 ? data[existingIndex] : null;
                const entry = sanitizeEntry(raw, old);

                if (existingIndex >= 0) {
                    data[existingIndex] = { ...data[existingIndex], ...entry };
                } else {
                    data.push(entry);
                }

                if (writeData(data)) {
                    res.writeHead(200, { 'Content-Type': 'application/json' });
                    res.end(JSON.stringify({ success: true, message: 'Telemetry saved' }));
                } else {
                    res.writeHead(500, { 'Content-Type': 'application/json' });
                    res.end(JSON.stringify({ success: false, message: 'Failed to save' }));
                }
            } catch (error) {
                res.writeHead(400, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ success: false, message: 'Invalid JSON' }));
            }
        });
        return;
    }

    if (req.url === '/' && req.method === 'GET') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            message: 'FischIs Telemetry Server',
            endpoints: {
                'GET /api/data': 'Get all telemetry data',
                'POST /telemetry': 'Submit telemetry data'
            }
        }));
        return;
    }

    // 404
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Not found' }));
});

server.listen(PORT, () => {
    console.log('🚀 Server running on port ' + PORT);
});

module.exports = server;
