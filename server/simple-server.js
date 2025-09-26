const express = require('express');
const fs = require('fs');
const path = require('path');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;
const DATA_FILE = path.join(__dirname, 'telemetry_data.json');

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Initialize data file if not exists
if (!fs.existsSync(DATA_FILE)) {
    fs.writeFileSync(DATA_FILE, JSON.stringify([], null, 2));
}

// Helper to read data
function readData() {
    try {
        const data = fs.readFileSync(DATA_FILE, 'utf8');
        return JSON.parse(data);
    } catch (error) {
        console.error('Error reading data:', error);
        return [];
    }
}

// Helper to write data
function writeData(data) {
    try {
        fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2));
        return true;
    } catch (error) {
        console.error('Error writing data:', error);
        return false;
    }
}

// POST /telemetry - Receive telemetry data
app.post('/telemetry', (req, res) => {
    try {
        console.log('📡 Received telemetry data:', req.body);
        
        const newEntry = {
            ...req.body,
            timestamp: new Date().toISOString(),
            lastUpdated: new Date().toISOString()
        };

        const data = readData();
        
        // Find existing entry by account
        const existingIndex = data.findIndex(item => 
            item.account === newEntry.account || 
            item.playerName === newEntry.account ||
            item.account === newEntry.playerName
        );

        if (existingIndex >= 0) {
            // Update existing
            data[existingIndex] = { ...data[existingIndex], ...newEntry };
            console.log('📝 Updated existing account:', newEntry.account);
        } else {
            // Add new
            data.push(newEntry);
            console.log('➕ Added new account:', newEntry.account);
        }

        if (writeData(data)) {
            res.json({ success: true, message: 'Telemetry data saved' });
        } else {
            res.status(500).json({ success: false, message: 'Failed to save data' });
        }
    } catch (error) {
        console.error('Error processing telemetry:', error);
        res.status(400).json({ success: false, message: 'Invalid data' });
    }
});

// GET /api/data - Get all telemetry data
app.get('/api/data', (req, res) => {
    try {
        const data = readData();
        res.json(data);
    } catch (error) {
        console.error('Error getting data:', error);
        res.status(500).json({ error: 'Failed to read data' });
    }
});

// GET /api/latest/:account - Get latest data for specific account
app.get('/api/latest/:account', (req, res) => {
    try {
        const { account } = req.params;
        const data = readData();
        
        const entry = data.find(item => 
            item.account === account || 
            item.playerName === account
        );

        if (entry) {
            res.json(entry);
        } else {
            res.status(404).json({ error: 'Account not found' });
        }
    } catch (error) {
        console.error('Error getting account data:', error);
        res.status(500).json({ error: 'Failed to read data' });
    }
});

// GET /api/stats - Get summary statistics
app.get('/api/stats', (req, res) => {
    try {
        const data = readData();
        const stats = {
            totalAccounts: data.length,
            onlineAccounts: data.filter(item => item.online).length,
            lastUpdated: data.length > 0 ? Math.max(...data.map(item => new Date(item.lastUpdated || item.timestamp).getTime())) : null
        };
        res.json(stats);
    } catch (error) {
        console.error('Error getting stats:', error);
        res.status(500).json({ error: 'Failed to get stats' });
    }
});

// Root endpoint
app.get('/', (req, res) => {
    res.json({
        message: 'FischIs Telemetry Server',
        endpoints: {
            'POST /telemetry': 'Submit telemetry data',
            'GET /api/data': 'Get all telemetry data',
            'GET /api/latest/:account': 'Get latest data for account',
            'GET /api/stats': 'Get summary statistics'
        }
    });
});

// Start server
app.listen(PORT, () => {
    console.log('🚀 Simple Telemetry Server running on http://localhost:' + PORT);
    console.log('📡 Telemetry endpoint: http://localhost:' + PORT + '/telemetry');
    console.log('📈 API data: http://localhost:' + PORT + '/api/data');
    console.log('💾 Data file: ' + DATA_FILE);
});

module.exports = app;
