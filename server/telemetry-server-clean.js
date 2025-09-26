const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;
const DATA_FILE = path.join(__dirname, 'telemetry_data.json');

// Middleware
app.use(cors());
app.use(express.json());

// Initialize data file if it doesn't exist
if (!fs.existsSync(DATA_FILE)) {
    fs.writeFileSync(DATA_FILE, JSON.stringify([]));
}

// Helper function to read data
function readData() {
    try {
        const data = fs.readFileSync(DATA_FILE, 'utf8');
        return JSON.parse(data);
    } catch (err) {
        console.error('Error reading data:', err);
        return [];
    }
}

// Helper function to write data
function writeData(data) {
    try {
        fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2));
        return true;
    } catch (err) {
        console.error('Error writing data:', err);
        return false;
    }
}

// POST /telemetry - Receive telemetry data
app.post('/telemetry', (req, res) => {
    try {
        const telemetryData = req.body;
        console.log('📡 Received telemetry data:', JSON.stringify(telemetryData, null, 2));
        
        const allData = readData();
        
        // Find existing entry for this account
        const existingIndex = allData.findIndex(item => item.account === telemetryData.account);
        
        // Add timestamp
        telemetryData.timestamp = new Date().toISOString();
        telemetryData.online = true;
        
        if (existingIndex !== -1) {
            // Update existing entry
            allData[existingIndex] = { ...allData[existingIndex], ...telemetryData };
        } else {
            // Add new entry
            allData.push(telemetryData);
        }
        
        // Write back to file
        if (writeData(allData)) {
            res.json({ success: true, message: 'Telemetry data received' });
        } else {
            res.status(500).json({ success: false, message: 'Failed to save data' });
        }
        
    } catch (err) {
        console.error('Error processing telemetry:', err);
        res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// GET /api/data - Get all telemetry data
app.get('/api/data', (req, res) => {
    try {
        const data = readData();
        res.json(data);
    } catch (err) {
        console.error('Error getting data:', err);
        res.status(500).json({ error: 'Failed to get data' });
    }
});

// GET /api/stats - Get summary statistics
app.get('/api/stats', (req, res) => {
    try {
        const data = readData();
        const stats = {
            totalAccounts: data.length,
            onlineAccounts: data.filter(d => d.online).length,
            totalEnchantStones: data.reduce((sum, d) => sum + (d.enchant || d.enchantStones || 0), 0),
            lastUpdated: new Date().toISOString()
        };
        res.json(stats);
    } catch (err) {
        console.error('Error getting stats:', err);
        res.status(500).json({ error: 'Failed to get stats' });
    }
});

// GET /api/latest/:account - Get latest data for specific account
app.get('/api/latest/:account', (req, res) => {
    try {
        const data = readData();
        const accountData = data.find(d => d.account === req.params.account);
        
        if (accountData) {
            res.json(accountData);
        } else {
            res.status(404).json({ error: 'Account not found' });
        }
    } catch (err) {
        console.error('Error getting account data:', err);
        res.status(500).json({ error: 'Failed to get account data' });
    }
});

// GET / - Serve dashboard
app.get('/', (req, res) => {
    res.send(`
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>FischIs Telemetry Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        :root {
            --bg: #ffffff;
            --surface: #f8fafc;
            --border: #e2e8f0;
            --text: #1e293b;
            --text-muted: #64748b;
            --primary: #3b82f6;
            --success: #10b981;
            --danger: #ef4444;
        }
        
        .dark {
            --bg: #0f172a;
            --surface: #1e293b;
            --border: #334155;
            --text: #f1f5f9;
            --text-muted: #94a3b8;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: var(--bg);
            color: var(--text);
            line-height: 1.5;
            transition: all 0.2s ease;
        }
        
        .app { max-width: 1200px; margin: 0 auto; padding: 1.5rem; }
        
        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 2rem;
        }
        
        .title { font-size: 1.875rem; font-weight: 700; }
        
        .theme-toggle {
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: 0.75rem;
            width: 2.25rem;
            height: 2.25rem;
            display: flex;
            align-items: center;
            justify-content: center;
            cursor: pointer;
            transition: all 0.2s ease;
        }
        
        .theme-toggle:hover { background: var(--border); }
        
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
            margin-bottom: 2rem;
        }
        
        .stat-card {
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: 0.75rem;
            padding: 1.5rem;
        }
        
        .stat-label { color: var(--text-muted); font-size: 0.875rem; margin-bottom: 0.5rem; }
        .stat-value { font-size: 2rem; font-weight: 700; }
        .stat-online { color: var(--success); }
        
        .controls {
            display: flex;
            gap: 1rem;
            margin-bottom: 1.5rem;
            flex-wrap: wrap;
        }
        
        .search {
            flex: 1;
            min-width: 250px;
            padding: 0.75rem 1rem;
            border: 1px solid var(--border);
            border-radius: 0.5rem;
            background: var(--surface);
            color: var(--text);
            font-size: 0.875rem;
        }
        
        .filters {
            display: flex;
            gap: 0.5rem;
        }
        
        .filter-btn {
            padding: 0.5rem 1rem;
            border: 1px solid var(--border);
            border-radius: 1.5rem;
            background: var(--surface);
            color: var(--text);
            cursor: pointer;
            font-size: 0.875rem;
            transition: all 0.2s ease;
        }
        
        .filter-btn.active {
            background: var(--primary);
            color: white;
            border-color: var(--primary);
        }
        
        .table-container {
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: 0.75rem;
            overflow: hidden;
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
        }
        
        th, td {
            padding: 0.75rem 1rem;
            text-align: left;
            border-bottom: 1px solid var(--border);
        }
        
        th {
            background: var(--bg);
            font-weight: 600;
            color: var(--text-muted);
            font-size: 0.875rem;
        }
        
        tr:hover { background: var(--border); }
        
        .account-cell { font-weight: 600; }
        .online-status { color: var(--success); }
        .offline-status { color: var(--danger); }
        
        .pagination {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 1rem;
            border-top: 1px solid var(--border);
        }
        
        .page-info { color: var(--text-muted); font-size: 0.875rem; }
        
        .page-controls {
            display: flex;
            gap: 0.5rem;
        }
        
        .page-btn {
            padding: 0.5rem;
            border: 1px solid var(--border);
            border-radius: 0.375rem;
            background: var(--surface);
            color: var(--text);
            cursor: pointer;
            transition: all 0.2s ease;
        }
        
        .page-btn:hover:not(:disabled) { background: var(--border); }
        .page-btn:disabled { opacity: 0.5; cursor: not-allowed; }
        
        .loading { text-align: center; padding: 2rem; color: var(--text-muted); }
        .error { text-align: center; padding: 2rem; color: var(--danger); }
        
        @media (max-width: 768px) {
            .app { padding: 1rem; }
            .controls { flex-direction: column; }
            .search { min-width: auto; }
            .stats { grid-template-columns: 1fr; }
            table { font-size: 0.875rem; }
            th, td { padding: 0.5rem; }
        }
    </style>
</head>
<body>
    <div class="app">
        <div class="header">
            <h1 class="title">FischIs Telemetry Dashboard</h1>
            <button class="theme-toggle" id="themeToggle">
                <svg id="sunIcon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <circle cx="12" cy="12" r="5"/>
                    <path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"/>
                </svg>
                <svg id="moonIcon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="display: none;">
                    <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/>
                </svg>
            </button>
        </div>
        
        <div class="stats">
            <div class="stat-card">
                <div class="stat-label">Online Accounts</div>
                <div class="stat-value stat-online" id="onlineCount">0</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Total Accounts</div>
                <div class="stat-value" id="totalCount">0</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Total Enchant Stones</div>
                <div class="stat-value" id="totalEnchant">0</div>
            </div>
        </div>
        
        <div class="controls">
            <input type="text" class="search" id="searchInput" placeholder="Search accounts, rods...">
            <div class="filters">
                <button class="filter-btn active" data-filter="all">All (<span id="allCount">0</span>)</button>
                <button class="filter-btn" data-filter="online">Online (<span id="onlineFilterCount">0</span>)</button>
                <button class="filter-btn" data-filter="offline">Offline (<span id="offlineCount">0</span>)</button>
            </div>
        </div>
        
        <div class="table-container">
            <table>
                <thead>
                    <tr>
                        <th>Account</th>
                        <th>Level</th>
                        <th>Enchant Stones</th>
                        <th>Coins</th>
                        <th>Rod</th>
                        <th>Items</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody id="tableBody">
                    <tr>
                        <td colspan="7" class="loading">Loading...</td>
                    </tr>
                </tbody>
            </table>
            
            <div class="pagination">
                <div class="page-info">
                    <span id="itemCount">0 items</span>
                </div>
                <div class="page-controls">
                    <button class="page-btn" id="prevPage" disabled>←</button>
                    <span class="page-info">Page <span id="currentPage">1</span> of <span id="totalPages">1</span></span>
                    <button class="page-btn" id="nextPage" disabled>→</button>
                </div>
            </div>
        </div>
    </div>
    
    <script>
        // Global state
        let allData = [];
        let filteredData = [];
        let currentPage = 1;
        let currentFilter = 'all';
        const itemsPerPage = 20;
        
        // Theme management
        function initTheme() {
            const saved = localStorage.getItem('theme');
            const isDark = saved === 'dark' || (!saved && window.matchMedia('(prefers-color-scheme: dark)').matches);
            
            if (isDark) {
                document.documentElement.classList.add('dark');
                document.getElementById('sunIcon').style.display = 'none';
                document.getElementById('moonIcon').style.display = 'block';
            }
        }
        
        function toggleTheme() {
            const isDark = document.documentElement.classList.toggle('dark');
            localStorage.setItem('theme', isDark ? 'dark' : 'light');
            
            document.getElementById('sunIcon').style.display = isDark ? 'none' : 'block';
            document.getElementById('moonIcon').style.display = isDark ? 'block' : 'none';
        }
        
        // Data fetching
        async function fetchData() {
            try {
                const [dataRes, statsRes] = await Promise.all([
                    fetch('/api/data'),
                    fetch('/api/stats')
                ]);
                
                allData = await dataRes.json();
                const stats = await statsRes.json();
                
                updateStats(stats);
                filterData();
                
            } catch (err) {
                console.error('Error fetching data:', err);
                document.getElementById('tableBody').innerHTML = 
                    '<tr><td colspan="7" class="error">Error loading data</td></tr>';
            }
        }
        
        // Update statistics
        function updateStats(stats) {
            document.getElementById('onlineCount').textContent = stats.onlineAccounts;
            document.getElementById('totalCount').textContent = stats.totalAccounts;
            document.getElementById('totalEnchant').textContent = stats.totalEnchantStones;
            document.getElementById('allCount').textContent = stats.totalAccounts;
            document.getElementById('onlineFilterCount').textContent = stats.onlineAccounts;
            document.getElementById('offlineCount').textContent = stats.totalAccounts - stats.onlineAccounts;
        }
        
        // Filter data
        function filterData() {
            const searchTerm = document.getElementById('searchInput').value.toLowerCase();
            
            filteredData = allData.filter(row => {
                // Search filter
                const searchMatch = !searchTerm || 
                    (row.account + ' ' + (row.rod || '')).toLowerCase().includes(searchTerm);
                
                // Status filter
                const statusMatch = currentFilter === 'all' || 
                    (currentFilter === 'online' && row.online) ||
                    (currentFilter === 'offline' && !row.online);
                
                return searchMatch && statusMatch;
            });
            
            currentPage = 1;
            updateTable();
            updatePagination();
            document.getElementById('itemCount').textContent = filteredData.length + ' items';
        }
        
        // Update table
        function updateTable() {
            const tbody = document.getElementById('tableBody');
            
            if (filteredData.length === 0) {
                tbody.innerHTML = '<tr><td colspan="7" class="loading">No results found</td></tr>';
                return;
            }
            
            const start = (currentPage - 1) * itemsPerPage;
            const pageData = filteredData.slice(start, start + itemsPerPage);
            
            tbody.innerHTML = pageData.map(row => {
                const nf = new Intl.NumberFormat();
                const statusClass = row.online ? 'online-status' : 'offline-status';
                const statusText = row.online ? 'Online' : 'Offline';
                
                return \`
                    <tr>
                        <td class="account-cell">\${row.account || 'Unknown'}</td>
                        <td>\${row.level || 0}</td>
                        <td>\${row.enchant || row.enchantStones || 0}</td>
                        <td>\${nf.format(row.coins || 0)}</td>
                        <td>\${row.rod || 'N/A'}</td>
                        <td>\${row.items || Object.keys(row.materials || {}).length || 0}</td>
                        <td class="\${statusClass}">\${statusText}</td>
                    </tr>
                \`;
            }).join('');
        }
        
        // Update pagination
        function updatePagination() {
            const totalPages = Math.max(1, Math.ceil(filteredData.length / itemsPerPage));
            
            document.getElementById('currentPage').textContent = currentPage;
            document.getElementById('totalPages').textContent = totalPages;
            
            document.getElementById('prevPage').disabled = currentPage === 1;
            document.getElementById('nextPage').disabled = currentPage === totalPages;
        }
        
        // Event listeners
        document.addEventListener('DOMContentLoaded', function() {
            initTheme();
            fetchData();
            
            // Theme toggle
            document.getElementById('themeToggle').addEventListener('click', toggleTheme);
            
            // Search
            document.getElementById('searchInput').addEventListener('input', filterData);
            
            // Filter buttons
            document.querySelectorAll('.filter-btn').forEach(btn => {
                btn.addEventListener('click', () => {
                    document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
                    btn.classList.add('active');
                    currentFilter = btn.dataset.filter;
                    filterData();
                });
            });
            
            // Pagination
            document.getElementById('prevPage').addEventListener('click', () => {
                if (currentPage > 1) {
                    currentPage--;
                    updateTable();
                    updatePagination();
                }
            });
            
            document.getElementById('nextPage').addEventListener('click', () => {
                const totalPages = Math.max(1, Math.ceil(filteredData.length / itemsPerPage));
                if (currentPage < totalPages) {
                    currentPage++;
                    updateTable();
                    updatePagination();
                }
            });
            
            // Auto-refresh every 10 seconds
            setInterval(fetchData, 10000);
        });
    </script>
</body>
</html>
    `);
});

// Start server
app.listen(PORT, () => {
    console.log('🚀 FischIs Telemetry Server running on http://localhost:' + PORT);
    console.log('📊 Dashboard: http://localhost:' + PORT);
    console.log('📡 Telemetry endpoint: http://localhost:' + PORT + '/telemetry');
    console.log('📈 API endpoints:');
    console.log('   - GET /api/data - All telemetry data');
    console.log('   - GET /api/stats - Summary statistics');
    console.log('   - GET /api/latest/:account - Latest data for account');
    console.log('💾 Data file: ' + DATA_FILE);
});

module.exports = app;
