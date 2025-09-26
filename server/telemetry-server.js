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
        
        /* Exact Fisch Tracker Layout */
        .fisch-app {
            display: flex;
            height: 100vh;
            background: rgb(9, 9, 11);
            color: rgb(250, 250, 250);
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        }
        
        /* Fisch Sidebar */
        .fisch-sidebar {
            width: 64px;
            background: rgb(24, 24, 27);
            border-right: 1px solid rgb(39, 39, 42);
            display: flex;
            flex-direction: column;
            position: relative;
        }
        
        .sidebar-logo {
            height: 64px;
            display: flex;
            align-items: center;
            justify-content: center;
            border-bottom: 1px solid rgb(39, 39, 42);
        }
        
        .logo-text {
            font-size: 16px;
            font-weight: 600;
            color: rgb(250, 250, 250);
        }
        
        .game-list {
            flex: 1;
            padding: 8px 0;
            overflow-y: auto;
        }
        
        .game-item {
            width: 48px;
            height: 48px;
            margin: 4px 8px;
            border-radius: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
            cursor: pointer;
            transition: all 0.2s ease;
            background: transparent;
        }
        
        .game-item:hover {
            background: rgb(39, 39, 42);
        }
        
        .game-item.active {
            background: rgb(244, 244, 245);
        }
        
        .game-icon {
            width: 24px;
            height: 24px;
            border-radius: 6px;
            background-size: cover;
            background-position: center;
        }
        
        /* Game Icons */
        .adopt-me { background: linear-gradient(45deg, #ff6b6b, #feca57); }
        .blox-fruits { background: linear-gradient(45deg, #48dbfb, #0abde3); }
        .king-legacy { background: linear-gradient(45deg, #ffd32a, #ff9ff3); }
        .pet-sim { background: linear-gradient(45deg, #ff9ff3, #54a0ff); }
        .pets-go { background: linear-gradient(45deg, #5f27cd, #00d2d3); }
        .fisch { background: linear-gradient(45deg, #00d2d3, #ff9ff3); }
        .yba { background: linear-gradient(45deg, #ff6348, #ffdd59); }
        .pls-donate { background: linear-gradient(45deg, #2ed573, #7bed9f); }
        .bubble-gum { background: linear-gradient(45deg, #ff6b9d, #c44569); }
        .garden { background: linear-gradient(45deg, #2ed573, #7bed9f); }
        .brainrot { background: linear-gradient(45deg, #5352ed, #3742fa); }
        .nights { background: linear-gradient(45deg, #2f3542, #57606f); }
        .mm2 { background: linear-gradient(45deg, #ff4757, #ff3838); }
        .yummy { background: linear-gradient(45deg, #ffa502, #ff6348); }
        .shop { background: linear-gradient(45deg, #1e90ff, #00bfff); }
        .scripts { background: linear-gradient(45deg, #32cd32, #00ff00); }
        .dashboard { background: linear-gradient(45deg, #ff69b4, #ff1493); }
        
        .sidebar-bottom {
            border-top: 1px solid rgb(39, 39, 42);
            padding: 8px 0;
        }
        
        .user-profile {
            margin: 8px;
        }
        
        .profile-avatar {
            width: 48px;
            height: 48px;
            border-radius: 12px;
            background: rgb(39, 39, 42);
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: 600;
            font-size: 16px;
        }
        
        /* Main Content Area */
        .main-content {
            flex: 1;
            display: flex;
            flex-direction: column;
            background: rgb(9, 9, 11);
        }
        
        .top-header {
            height: 64px;
            background: rgb(9, 9, 11);
            border-bottom: 1px solid rgb(39, 39, 42);
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 0 24px;
        }
        
        .header-left {
            display: flex;
            align-items: center;
            gap: 16px;
        }
        
        .sidebar-toggle {
            background: transparent;
            border: none;
            color: rgb(250, 250, 250);
            cursor: pointer;
            padding: 8px;
            border-radius: 4px;
        }
        
        .page-title {
            font-size: 18px;
            font-weight: 600;
            color: rgb(250, 250, 250);
        }
        
        .header-right {
            display: flex;
            align-items: center;
            gap: 16px;
        }
        
        .user-menu {
            display: flex;
            align-items: center;
            gap: 8px;
            padding: 8px 12px;
            background: rgb(39, 39, 42);
            border-radius: 6px;
            cursor: pointer;
            color: rgb(250, 250, 250);
        }
        
        /* Content Wrapper */
        .content-wrapper {
            flex: 1;
            padding: 24px;
            overflow-y: auto;
        }
        
        /* Stats Cards */
        .stats-cards {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }
        
        .stat-card {
            background: rgb(24, 24, 27);
            border: 1px solid rgb(39, 39, 42);
            border-radius: 8px;
            padding: 16px;
            display: flex;
            align-items: center;
            gap: 12px;
        }
        
        .stat-icon {
            font-size: 24px;
            width: 40px;
            height: 40px;
            display: flex;
            align-items: center;
            justify-content: center;
            background: rgb(39, 39, 42);
            border-radius: 8px;
        }
        
        .stat-content {
            flex: 1;
        }
        
        .stat-label {
            font-size: 12px;
            color: rgb(161, 161, 170);
            margin-bottom: 4px;
        }
        
        .stat-value {
            font-size: 20px;
            font-weight: 600;
            color: rgb(250, 250, 250);
        }
        
        /* Search Bar */
        .search-bar {
            margin-bottom: 16px;
        }
        
        .search-bar .search-input {
            width: 100%;
            padding: 12px 16px;
            background: rgb(24, 24, 27);
            border: 1px solid rgb(39, 39, 42);
            border-radius: 8px;
            color: rgb(250, 250, 250);
            font-size: 14px;
        }
        
        .search-bar .search-input:focus {
            outline: none;
            border-color: rgb(59, 130, 246);
        }
        
        /* Filter Tabs */
        .filter-tabs {
            display: flex;
            gap: 4px;
            margin-bottom: 16px;
        }
        
        .filter-tab {
            padding: 8px 16px;
            background: rgb(24, 24, 27);
            border: 1px solid rgb(39, 39, 42);
            border-radius: 6px;
            cursor: pointer;
            color: rgb(161, 161, 170);
            font-size: 14px;
            transition: all 0.2s ease;
        }
        
        .filter-tab input[type="radio"] {
            display: none;
        }
        
        .filter-tab input[type="radio"]:checked + .tab-text {
            color: rgb(250, 250, 250);
        }
        
        .filter-tab:has(input[type="radio"]:checked) {
            background: rgb(39, 39, 42);
            color: rgb(250, 250, 250);
        }
        
        /* Action Bar */
        .action-bar {
            display: flex;
            gap: 8px;
            margin-bottom: 16px;
        }
        
        .action-btn {
            display: flex;
            align-items: center;
            gap: 8px;
            padding: 8px 12px;
            background: rgb(39, 39, 42);
            border: 1px solid rgb(75, 85, 99);
            border-radius: 6px;
            color: rgb(250, 250, 250);
            font-size: 14px;
            cursor: pointer;
            transition: all 0.2s ease;
        }
        
        .action-btn:hover {
            background: rgb(55, 65, 81);
        }
        
        /* Table Info Bar */
        .table-info {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 12px 0;
            border-bottom: 1px solid rgb(39, 39, 42);
            margin-bottom: 16px;
        }
        
        .items-count {
            color: rgb(161, 161, 170);
            font-size: 14px;
        }
        
        .pagination {
            display: flex;
            align-items: center;
            gap: 8px;
        }
        
        .page-size {
            background: rgb(39, 39, 42);
            border: 1px solid rgb(75, 85, 99);
            border-radius: 6px;
            color: rgb(250, 250, 250);
            padding: 6px 8px;
            font-size: 14px;
        }
        
        /* Search Controls */
        .search-controls {
            margin-bottom: 16px;
        }
        
        .search-input-wrapper {
            position: relative;
            margin-bottom: 16px;
        }
        
        .search-icon {
            position: absolute;
            left: 12px;
            top: 50%;
            transform: translateY(-50%);
            color: rgb(161, 161, 170);
        }
        
        .search-input {
            width: 100%;
            padding: 12px 12px 12px 40px;
            background: rgb(24, 24, 27);
            border: 1px solid rgb(39, 39, 42);
            border-radius: 8px;
            color: rgb(250, 250, 250);
            font-size: 14px;
        }
        
        .search-input:focus {
            outline: none;
            border-color: rgb(59, 130, 246);
        }
        
        .filter-section {
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 16px;
        }
        
        .status-filters {
            display: flex;
            gap: 24px;
        }
        
        .filter-option {
            display: flex;
            align-items: center;
            gap: 8px;
            cursor: pointer;
            color: rgb(161, 161, 170);
            font-size: 14px;
        }
        
        .filter-option input[type="radio"] {
            display: none;
        }
        
        .filter-dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background: rgb(75, 85, 99);
            transition: all 0.2s ease;
        }
        
        .filter-option input[type="radio"]:checked + .filter-dot {
            background: rgb(59, 130, 246);
        }
        
        .filter-option input[type="radio"]:checked ~ span {
            color: rgb(250, 250, 250);
        }
        
        .action-buttons {
            display: flex;
            gap: 8px;
        }
        
        .action-button {
            display: flex;
            align-items: center;
            gap: 8px;
            padding: 8px 12px;
            background: rgb(39, 39, 42);
            border: 1px solid rgb(75, 85, 99);
            border-radius: 6px;
            color: rgb(250, 250, 250);
            font-size: 14px;
            cursor: pointer;
            transition: all 0.2s ease;
        }
        
        .action-button:hover {
            background: rgb(55, 65, 81);
        }
        
        /* Stats and Pagination */
        .stats-pagination {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 12px 0;
            border-bottom: 1px solid rgb(39, 39, 42);
            margin-bottom: 16px;
        }
        
        .stats-info {
            display: flex;
            align-items: center;
            gap: 16px;
        }
        
        .online-count {
            color: rgb(34, 197, 94);
            font-weight: 500;
        }
        
        .items-info {
            color: rgb(161, 161, 170);
            font-size: 14px;
        }
        
        .pagination-info {
            display: flex;
            align-items: center;
            gap: 12px;
        }
        
        .items-per-page {
            background: rgb(39, 39, 42);
            border: 1px solid rgb(75, 85, 99);
            border-radius: 6px;
            color: rgb(250, 250, 250);
            padding: 6px 8px;
            font-size: 14px;
        }
        
        .page-controls {
            display: flex;
            gap: 4px;
        }
        
        .page-btn {
            padding: 6px 10px;
            background: rgb(39, 39, 42);
            border: 1px solid rgb(75, 85, 99);
            border-radius: 4px;
            color: rgb(250, 250, 250);
            cursor: pointer;
            font-size: 14px;
        }
        
        .page-btn:disabled {
            opacity: 0.5;
            cursor: not-allowed;
        }
        
        .page-btn:not(:disabled):hover {
            background: rgb(55, 65, 81);
        }
        
        /* Main Content Styles */
        .main-content {
            flex: 1;
            display: flex;
            flex-direction: column;
        }
        
        .top-header {
            height: 64px;
            background: rgb(9, 9, 11);
            border-bottom: 1px solid rgb(39, 39, 42);
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 0 24px;
        }
        
        .header-left {
            display: flex;
            align-items: center;
            gap: 16px;
        }
        
        .sidebar-toggle {
            background: transparent;
            border: none;
            color: rgb(250, 250, 250);
            cursor: pointer;
            padding: 8px;
            border-radius: 4px;
            transition: background 0.2s ease;
        }
        
        .sidebar-toggle:hover {
            background: rgb(39, 39, 42);
        }
        
        .page-title {
            font-size: 18px;
            font-weight: 600;
        }
        
        .header-right {
            display: flex;
            align-items: center;
            gap: 16px;
        }
        
        .user-menu {
            display: flex;
            align-items: center;
            gap: 8px;
            padding: 8px 12px;
            background: rgb(39, 39, 42);
            border-radius: 6px;
            cursor: pointer;
            transition: background 0.2s ease;
        }
        
        .user-menu:hover {
            background: rgb(63, 63, 70);
        }
        
        /* Data Table */
        .data-table {
            width: 100%;
            border-collapse: collapse;
            background: rgb(24, 24, 27);
            border-radius: 8px;
            overflow: hidden;
        }
        
        .data-table th {
            background: rgb(39, 39, 42);
            padding: 12px 16px;
            text-align: left;
            font-weight: 500;
            font-size: 14px;
            color: rgb(161, 161, 170);
            border-bottom: 1px solid rgb(63, 63, 70);
        }
        
        .data-table td {
            padding: 12px 16px;
            border-bottom: 1px solid rgb(39, 39, 42);
            font-size: 14px;
            color: rgb(250, 250, 250);
        }
        
        .data-table tr:hover {
            background: rgb(39, 39, 42);
        }
        
        .data-table tr:last-child td {
            border-bottom: none;
        }
        
        .checkbox-cell {
            width: 40px;
            text-align: center;
        }
        
        .checkbox-cell input[type="checkbox"] {
            width: 16px;
            height: 16px;
            accent-color: rgb(59, 130, 246);
        }
        
        .status-online {
            color: rgb(34, 197, 94);
            font-weight: 500;
        }
        
        .status-offline {
            color: rgb(239, 68, 68);
            font-weight: 500;
        }
        
        .coins-value {
            font-family: 'Courier New', monospace;
            color: rgb(250, 204, 21);
        }
        
        .level-badge {
            background: rgb(59, 130, 246);
            color: white;
            padding: 2px 8px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: 500;
        }
        
        .enchant-count {
            color: rgb(168, 85, 247);
            font-weight: 500;
        }
        
        .rods-count {
            color: rgb(34, 197, 94);
            font-weight: 500;
        }
        
        /* Remove duplicate search styles - using new ones above */
        
        .filter-controls {
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-wrap: wrap;
            gap: 16px;
        }
        
        .status-filters {
            display: flex;
            gap: 24px;
        }
        
        .filter-radio {
            display: flex;
            align-items: center;
            gap: 8px;
            cursor: pointer;
            font-size: 14px;
        }
        
        .filter-radio input {
            display: none;
        }
        
        .radio-dot {
            width: 16px;
            height: 16px;
            border: 1px solid rgb(161, 161, 170);
            border-radius: 50%;
            position: relative;
            transition: all 0.2s ease;
        }
        
        .filter-radio input:checked + .radio-dot {
            border-color: rgb(250, 250, 250);
        }
        
        .filter-radio input:checked + .radio-dot::after {
            content: '';
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            width: 8px;
            height: 8px;
            background: rgb(250, 250, 250);
            border-radius: 50%;
        }
        
        .action-buttons {
            display: flex;
            gap: 12px;
        }
        
        .action-btn {
            display: flex;
            align-items: center;
            gap: 8px;
            padding: 8px 16px;
            background: rgb(39, 39, 42);
            border: 1px solid rgb(63, 63, 70);
            border-radius: 6px;
            color: rgb(250, 250, 250);
            font-size: 14px;
            cursor: pointer;
            transition: all 0.2s ease;
        }
        
        .action-btn:hover {
            background: rgb(63, 63, 70);
        }
        
        /* Stats Bar */
        .stats-bar {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 16px;
            padding: 12px 0;
            border-bottom: 1px solid rgb(39, 39, 42);
        }
        
        .stat-item {
            font-size: 14px;
            color: rgb(161, 161, 170);
        }
        
        .item-count {
            font-size: 14px;
            color: rgb(161, 161, 170);
        }
        
        .pagination-controls {
            display: flex;
            align-items: center;
            gap: 12px;
        }
        
        .page-size {
            padding: 6px 12px;
            background: rgb(24, 24, 27);
            border: 1px solid rgb(39, 39, 42);
            border-radius: 4px;
            color: rgb(250, 250, 250);
            font-size: 14px;
        }
        
        .pagination-buttons {
            display: flex;
            gap: 4px;
        }
        
        .page-btn {
            width: 32px;
            height: 32px;
            background: rgb(24, 24, 27);
            border: 1px solid rgb(39, 39, 42);
            border-radius: 4px;
            color: rgb(250, 250, 250);
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            transition: all 0.2s ease;
        }
        
        .page-btn:hover:not(:disabled) {
            background: rgb(39, 39, 42);
        }
        
        .page-btn:disabled {
            opacity: 0.5;
            cursor: not-allowed;
        }
        
        /* Data Table Styles */
        .data-table {
            background: rgb(24, 24, 27);
            border: 1px solid rgb(39, 39, 42);
            border-radius: 8px;
            overflow: hidden;
        }
        
        .fisch-table {
            width: 100%;
            border-collapse: collapse;
        }
        
        .fisch-table thead {
            background: rgb(39, 39, 42);
        }
        
        .fisch-table th {
            padding: 12px 16px;
            text-align: left;
            font-size: 14px;
            font-weight: 500;
            color: rgb(161, 161, 170);
            border-bottom: 1px solid rgb(63, 63, 70);
        }
        
        .fisch-table td {
            padding: 12px 16px;
            font-size: 14px;
            color: rgb(250, 250, 250);
            border-bottom: 1px solid rgb(39, 39, 42);
        }
        
        .fisch-table tbody tr:hover {
            background: rgb(39, 39, 42);
        }
        
        .checkbox-col {
            width: 40px;
        }
        
        .table-checkbox {
            width: 16px;
            height: 16px;
            accent-color: rgb(250, 250, 250);
        }
        
        .status-online {
            color: rgb(34, 197, 94);
            font-weight: 500;
        }
        
        .status-offline {
            color: rgb(239, 68, 68);
            font-weight: 500;
        }
        
        .theme-toggle {
            background: rgb(39, 39, 42);
            border: 1px solid rgb(63, 63, 70);
            border-radius: 6px;
            color: rgb(250, 250, 250);
            cursor: pointer;
            padding: 8px;
            transition: all 0.2s ease;
        }
        
        .theme-toggle:hover {
            background: rgb(63, 63, 70);
        }
        
        :root {
            --background: 0 0% 100%;
            --foreground: 240 10% 3.9%;
            --card: 0 0% 100%;
            --card-foreground: 240 10% 3.9%;
            --popover: 0 0% 100%;
            --popover-foreground: 240 10% 3.9%;
            --primary: 240 5.9% 10%;
            --primary-foreground: 0 0% 98%;
            --secondary: 240 4.8% 95.9%;
            --secondary-foreground: 240 5.9% 10%;
            --muted: 240 4.8% 95.9%;
            --muted-foreground: 240 3.8% 46.1%;
            --accent: 240 4.8% 95.9%;
            --accent-foreground: 240 5.9% 10%;
            --destructive: 0 84.2% 60.2%;
            --destructive-foreground: 0 0% 98%;
            --border: 240 5.9% 90%;
            --input: 240 5.9% 90%;
            --ring: 240 5.9% 10%;
            --radius: 0.75rem;
        }
        
        .dark {
            --background: 240 10% 3.9%;
            --foreground: 0 0% 98%;
            --card: 240 10% 3.9%;
            --card-foreground: 0 0% 98%;
            --popover: 240 10% 3.9%;
            --popover-foreground: 0 0% 98%;
            --primary: 0 0% 98%;
            --primary-foreground: 240 5.9% 10%;
            --secondary: 240 3.7% 15.9%;
            --secondary-foreground: 0 0% 98%;
            --muted: 240 3.7% 15.9%;
            --muted-foreground: 240 5% 64.9%;
            --accent: 240 3.7% 15.9%;
            --accent-foreground: 0 0% 98%;
            --destructive: 0 62.8% 30.6%;
            --destructive-foreground: 0 0% 98%;
            --border: 240 3.7% 15.9%;
            --input: 240 3.7% 15.9%;
            --ring: 240 4.9% 83.9%;
        }
        
        body {
            font-family: Geist, sans-serif;
            background-color: hsl(var(--background));
            color: hsl(var(--foreground));
            line-height: 1.5;
            transition: all 0.2s ease;
        }
        
        .app { max-width: 1200px; margin: 0 auto; padding: 1.5rem; }
        
        /* Grid layout */
        .grid { display: grid; }
        .grid-cols-1 { grid-template-columns: repeat(1, minmax(0, 1fr)); }
        .gap-4 { gap: 1rem; }
        .md\:grid-cols-12 { grid-template-columns: repeat(12, minmax(0, 1fr)); }
        .md\:col-span-7 { grid-column: span 7 / span 7; }
        .md\:col-span-5 { grid-column: span 5 / span 5; }
        
        /* Surface and layout */
        .surface { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); }
        .rounded-xl { border-radius: 0.75rem; }
        .p-4 { padding: 1rem; }
        .mt-1 { margin-top: 0.25rem; }
        .mt-3 { margin-top: 0.75rem; }
        .mt-4 { margin-top: 1rem; }
        .mr-2 { margin-right: 0.5rem; }
        .w-72 { width: 18rem; }
        .w-full { width: 100%; }
        .pr-10 { padding-right: 2.5rem; }
        .mb-2 { margin-bottom: 0.5rem; }
        .mb-4 { margin-bottom: 1rem; }
        .h-4 { height: 1rem; }
        .w-4 { width: 1rem; }
        
        /* Flexbox */
        .flex { display: flex; }
        .items-center { align-items: center; }
        .justify-between { justify-content: space-between; }
        .flex-wrap { flex-wrap: wrap; }
        
        /* Text */
        .text-sm { font-size: 0.875rem; }
        .text-2xl { font-size: 1.5rem; }
        .font-semibold { font-weight: 600; }
        .text-muted-foreground { color: hsl(var(--muted-foreground)); }
        .text-green-500 { color: #10b981; }
        
        /* Position */
        .relative { position: relative; }
        .absolute { position: absolute; }
        .right-3 { right: 0.75rem; }
        .top-1\/2 { top: 50%; }
        .-translate-y-1\/2 { transform: translateY(-50%); }
        
        /* Screen reader only */
        .sr-only { position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0; }
        
        /* Cursor */
        .cursor-pointer { cursor: pointer; }
        .select-none { user-select: none; }
        
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
            margin-top: 0;
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
        
        /* Radio pills */
        .radio-pill {
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
            padding: 0.375rem 0.75rem;
            border: 1px solid var(--border);
            border-radius: 1rem;
            background: var(--surface);
            color: var(--text);
            font-size: 0.875rem;
            transition: all 0.2s ease;
        }
        
        .radio-pill:hover { background: var(--border); }
        
        .radio-pill:has(input:checked) {
            background: var(--primary);
            color: white;
            border-color: var(--primary);
        }
        
        .radio-dot {
            width: 0.5rem;
            height: 0.5rem;
            border-radius: 50%;
            border: 1px solid currentColor;
            background: transparent;
            transition: all 0.2s ease;
        }
        
        .radio-pill:has(input:checked) .radio-dot {
            background: currentColor;
        
/* Input styling */
.input {
    padding: 0.5rem 0.75rem;
    border: 1px solid hsl(var(--border));
    border-radius: 0.375rem;
    background: hsl(var(--background));
    color: hsl(var(--foreground));
    font-size: 0.875rem;
}
        
.input:focus {
    outline: none;
    border-color: hsl(var(--ring));
    box-shadow: 0 0 0 2px hsl(var(--ring) / 0.2);
}
        
        /* Button styling */
        .btn {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            padding: 0.5rem 1rem;
            border: 1px solid hsl(var(--border));
            border-radius: 0.375rem;
            background: hsl(var(--background));
            color: hsl(var(--foreground));
            font-size: 0.875rem;
            font-weight: 500;
            cursor: pointer;
            transition: all 0.2s ease;
            text-decoration: none;
        }
        
        .btn:hover { background: hsl(var(--accent)); }
        
        .btn-secondary { background: hsl(var(--secondary)); color: hsl(var(--secondary-foreground)); }
        .btn-icon { width: 2rem; height: 2rem; padding: 0; }
        .ghost-pill { border-radius: 1rem; }
        
        /* Table styling */
        .table-head th {
            background: hsl(var(--muted) / 0.5);
            font-weight: 600;
            color: hsl(var(--muted-foreground));
            font-size: 0.875rem;
            border-bottom: 1px solid hsl(var(--border));
        }
        
        .th-wrap {
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }
        
        .th-icon {
            width: 1rem;
            height: 1rem;
            stroke-width: 2;
        }
        
        .w-10 { width: 2.5rem; }
        
        /* Checkbox styling */
        .checkbox-btn {
            width: 1rem;
            height: 1rem;
            border: 1px solid hsl(var(--border));
            border-radius: 0.25rem;
            background: hsl(var(--background));
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            transition: all 0.2s ease;
        }
        
        .checkbox-btn:hover {
            border-color: hsl(var(--ring));
        }
        
        .checkbox-btn[data-checked="true"] {
            background: hsl(var(--primary));
            border-color: hsl(var(--primary));
        }
        
        .checkbox-icon {
            width: 0.75rem;
            height: 0.75rem;
            stroke: white;
            stroke-width: 2;
            fill: none;
        }
        
        /* Table row styling */
        .table-row:hover { background: hsl(var(--muted) / 0.5); }
        .row-alt { background: hsl(var(--muted) / 0.3); }
        .account-cell { font-weight: 600; }
        
        .loading { text-align: center; padding: 2rem; color: hsl(var(--muted-foreground)); }
        .error { text-align: center; padding: 2rem; color: hsl(var(--destructive)); }
        
        @media (max-width: 768px) {
            .app { padding: 1rem; }
            .controls { flex-direction: column; }
            .search { min-width: auto; }
            .stats { grid-template-columns: 1fr; }
            table { font-size: 0.875rem; }
            th, td { padding: 0.5rem; }
        }
    </style>
        /* === CSS Styles === */
        <style>

/* 🎨 CSS Variables จาก Fisch Tracker UI Analysis */
:root {
  --bg-primary: rgb(9, 9, 11);
  --bg-secondary: rgb(24, 24, 27);
  --bg-light: rgb(244, 244, 245);
  --text-primary: rgb(244, 244, 245);
  --text-secondary: rgb(250, 250, 250);
  --text-dark: rgb(0, 0, 0);
  --border-primary: rgb(39, 39, 42);
  --btn-bg: rgba(0, 0, 0, 0);
  --btn-color: rgb(244, 244, 245);
  --btn-border-radius: 10px;
  --btn-padding: 4px;
  --btn-font-size: 14px;
  --btn-font-family: Geist, sans-serif;
  /* 🎨 Layout Tweaks to match original Fisch Tracker */
  --sidebar-width: 48px;   /* icon-only sidebar */
  --header-height: 48px;   /* h-12 (Tailwind) */
  --content-padding: 20px;
  /* === HSL Design Tokens from provided spec === */
  --card-foreground: 0 0% 98%;
  --popover-foreground: 0 0% 98%;
  --primary-foreground: 240 5.9% 10%;
  --secondary-foreground: 0 0% 98%;
  --muted-foreground: 240 5% 64.9%;
  --accent-foreground: 0 0% 98%;
  --destructive-foreground: 0 0% 98%;
  --chart-1: 220 70% 50%;
  --chart-2: 160 60% 45%;
  --chart-3: 30 80% 55%;
  --chart-4: 280 65% 60%;
  --chart-5: 340 75% 55%;
  --sidebar-background: 240 5.9% 10%;
  --sidebar-foreground: 240 4.8% 95.9%;
  --sidebar-primary: 224.3 76.3% 48%;
  --sidebar-primary-foreground: 0 0% 100%;
  --sidebar-accent: 240 3.7% 15.9%;
  --sidebar-accent-foreground: 240 4.8% 95.9%;
  --sidebar-border: 240 3.7% 15.9%;
  --sidebar-ring: 217.2 91.2% 59.8%;
  --background: 240 10% 3.9%;
  --foreground: 0 0% 98%;
  --card: 240 10% 3.9%;
  --cardForeground: 0 0% 98%;
  --popover: 240 10% 3.9%;
  --popoverForeground: 0 0% 98%;
  --primary: 0 0% 98%;
  --primaryForeground: 240 5.9% 10%;
  --secondary: 240 3.7% 15.9%;
  --secondaryForeground: 0 0% 98%;
  --muted: 240 3.7% 15.9%;
  --mutedForeground: 240 5% 64.9%;
  --accent: 240 3.7% 15.9%;
  --accentForeground: 0 0% 98%;
  --destructive: 0 62.8% 30.6%;
  --destructiveForeground: 0 0% 98%;
  --border: 240 3.7% 15.9%;
  --input: 240 3.7% 15.9%;
  --ring: 240 4.9% 83.9%;
  --radius: 0.75rem;
  --chart1: 220 70% 50%;
  --chart2: 160 60% 45%;
  --chart3: 30 80% 55%;
  --chart4: 280 65% 60%;
  --chart5: 340 75% 55%;

  /* Bridge old variables to new HSL tokens */
  --bg-primary: hsl(var(--background));
  --bg-secondary: hsl(var(--secondary));
  --text-primary: hsl(var(--foreground));
  --text-secondary: hsl(var(--foreground));
  --border-primary: hsl(var(--border));
}

/* 🌙 Dark Theme Support */
.dark {
  --bg-primary: rgb(9, 9, 11);
  --bg-secondary: rgb(24, 24, 27);
  --text-primary: rgb(244, 244, 245);
  --text-secondary: rgb(250, 250, 250);
}

/* 📱 Base Styles */
body {
  background-color: var(--bg-primary);
  color: var(--text-primary);
  font-family: var(--btn-font-family);
  min-height: 100vh;
}

/* 🔘 Button Styles */
.btn, button {
  background-color: transparent;
  color: var(--text-primary);
  border-radius: 6px;
  padding: 4px 8px;
  font-size: 14px;
  font-family: var(--btn-font-family);
  border: 1px solid var(--border-primary);
  cursor: pointer;
  transition: all 0.2s ease;
}

.btn:hover, button:hover {
  background-color: var(--bg-secondary);
  transform: translateY(-1px);
}

/* 📊 Table Styles */
.table {
  background-color: var(--bg-secondary);
  border: 1px solid var(--border-primary);
  border-radius: var(--btn-border-radius);
  color: var(--text-primary);
}

.table th {
  background-color: var(--bg-primary);
  color: var(--text-secondary);
  border-bottom: 1px solid var(--border-primary);
}

.table td {
  border-bottom: 1px solid var(--border-primary);
}

/* 🎛️ Form Controls */
.form-control, input, select {
  background-color: var(--bg-secondary);
  color: var(--text-primary);
  border: 1px solid var(--border-primary);
  border-radius: var(--btn-border-radius);
  padding: var(--btn-padding);
}

/* 📑 Card Styles */
.card {
  background-color: var(--bg-secondary);
  border: 1px solid var(--border-primary);
  border-radius: var(--btn-border-radius);
  color: var(--text-primary);
}
 
/* === Top Header Styles (Fisch) === */
.top-header {
  height: var(--header-height);
  display: flex;
  align-items: center;
  gap: 8px;
  border-bottom: 1px solid var(--border-primary);
  padding-left: 8px; /* pl-2 */
  padding-right: 24px; /* pr-6 */
  transition: width .15s linear, height .15s linear;
}
.header-left {
  display: flex;
  align-items: center;
  gap: 8px; /* gap-2 */
  padding: 0 16px; /* px-4 */
  flex: 1;
}
.sidebar-toggle {
  height: 28px; /* h-7 */
  width: 28px;  /* w-7 */
  margin-left: -4px; /* -ml-1 */
  border: none;
  background: transparent;
  color: var(--text-primary);
}
.divider-vert {
  width: 1px;
  height: calc(var(--header-height) - 8px);
  background: var(--border-primary);
  margin: 0 8px;
}
.page-title {
  font-size: 16px; /* text-base */
  font-weight: 500; /* font-medium */
  text-transform: capitalize;
}
.header-right { display: flex; align-items: center; gap: 8px; }
.avatar-dot { width: 20px; height: 20px; border-radius: 50%; background: #52525b; }

/* === Utility classes (subset to mimic Tailwind) === */
.grid { display: grid; }
.grid-cols-2 { grid-template-columns: repeat(2, minmax(0, 1fr)); }
.gap-4 { gap: 1rem; }
.rounded-xl { border-radius: .75rem; }
.border { border: 1px solid var(--border-primary); }
.bg-card { background-color: var(--bg-secondary); }
.text-card-foreground { color: var(--text-primary); }
.shadow { box-shadow: 0 1px 3px rgba(0,0,0,0.1), 0 1px 2px rgba(0,0,0,0.06); }
.p-4 { padding: 1rem; }
.flex { display: flex; }
.flex-row { flex-direction: row; }
.justify-between { justify-content: space-between; }
.items-center { align-items: center; }
.pb-2 { padding-bottom: .5rem; }
.pt-0 { padding-top: 0; }
.font-bold { font-weight: 700; }
.text-2xl { font-size: 1.5rem; line-height: 2rem; }
.text-lg { font-size: 1.125rem; line-height: 1.75rem; }
.text-sm { font-size: .875rem; line-height: 1.25rem; }
.text-xs { font-size: .75rem; line-height: 1rem; }
.capitalize { text-transform: capitalize; }
.gap-2 { gap: .5rem; }
.h-5 { height: 1.25rem; }
.h-8 { height: 2rem; }
.rounded-md { border-radius: .375rem; }
.px-3 { padding-left: .75rem; padding-right: .75rem; }
.text-green-600 { color: #16a34a; }
.text-red-600 { color: #dc2626; }
.bg-border { background-color: var(--border-primary); }
/* Header utilities used by provided markup */
.h-12 { height: 3rem; }
.w-9 { width: 2.25rem; }
.h-7 { height: 1.75rem; }
.w-7 { width: 1.75rem; }
.h-full { height: 100%; }
.w-\[1px\] { width: 1px; }
.w-\[180px\] { width: 180px; }
.px-4 { padding-left: 1rem; padding-right: 1rem; }
.pl-2 { padding-left: .5rem; }
.pr-6 { padding-right: 1.5rem; }
.mx-2 { margin-left: .5rem; margin-right: .5rem; }
.gap-1 { gap: .25rem; }
.shrink-0 { flex-shrink: 0; }
.sr-only { position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0; }
.transition-\[width,height\] { transition-property: width, height; }
.ease-linear { transition-timing-function: linear; }
.bg-background { background-color: hsl(var(--background)); }
.hover\:bg-accent:hover { background-color: hsl(var(--accent)); }
.hover\:text-accent-foreground:hover { color: hsl(var(--accentForeground)); }
.transition-colors { transition-property: color, background-color, border-color, text-decoration-color, fill, stroke; transition-duration: .15s; }
.focus-visible\:outline-none:focus-visible { outline: none; }
.focus-visible\:ring-1:focus-visible { box-shadow: 0 0 0 1px hsl(var(--ring)); }
.focus-visible\:ring-ring:focus-visible { box-shadow: 0 0 0 1px hsl(var(--ring)); }
.disabled\:pointer-events-none:disabled { pointer-events: none; }
.disabled\:opacity-50:disabled { opacity: .5; }
.w-\[20px\] { width: 20px; }
.h-\[20px\] { height: 20px; }
.bg-zinc-700 { background-color: #3f3f46; }
.space-x-3 > * + * { margin-left: .75rem; }
.item-center { align-items: center; }
.ring-offset-transparent { box-shadow: none; }
@media (min-width: 1024px) { .lg\:gap-2 { gap: .5rem; } }
/* Extra utilities */
.tracking-tight { letter-spacing: -0.015em; }
.text-base { font-size: 1rem; line-height: 1.5rem; }
.font-medium { font-weight: 500; }
.border-b { border-bottom: 1px solid var(--border-primary); }
.-ml-1 { margin-left: -0.25rem; }
.opacity-50 { opacity: .5; }
.absolute { position: absolute; }
.transition-all { transition: all .15s ease; }
.h-\[1\.2rem\] { height: 1.2rem; }
.w-\[1\.2rem\] { width: 1.2rem; }
/* More utilities required by provided markup */
.px-6 { padding-left: 1.5rem; padding-right: 1.5rem; }
.mt-1 { margin-top: .25rem; }
.hidden { display: none; }
.inline-flex { display: inline-flex; }
.justify-center { justify-content: center; }
.relative { position: relative; }
.overflow-auto { overflow: auto; }
.bg-primary { background-color: hsl(var(--primary)); }
.text-primary-foreground { color: hsl(var(--primaryForeground)); }
.text-muted-foreground { color: hsl(var(--muted-foreground)); }
.w-\[80px\] { width: 80px; }
@media (min-width: 1024px) {
  .lg\:flex { display: flex; }
  .lg\:hidden { display: none; }
  .lg\:w-fit { width: fit-content; }
  .lg\:justify-end { justify-content: flex-end; }
  .lg\:mt-0 { margin-top: 0; }
}
/* Additional utilities to match header/toolbar markup */
.w-full { width: 100%; }
.flex-col { flex-direction: column; }
.mb-2 { margin-bottom: .5rem; }
.gap-5 { gap: 1.25rem; }
.flex-row { flex-direction: row; }
.h-9 { height: 2.25rem; }
.h-4 { height: 1rem; }
.w-4 { width: 1rem; }
.rounded-full { border-radius: 9999px; }
.py-1 { padding-top: .25rem; padding-bottom: .25rem; }
.shadow-sm { box-shadow: 0 1px 2px rgba(0,0,0,0.1); }
.bg-secondary { background-color: var(--bg-secondary); }
.text-secondary-foreground { color: var(--text-primary); }
.border-input { border-color: var(--border-primary); }
.border-primary { border-color: var(--border-primary); }
.text-primary { color: var(--text-primary); }
.space-x-2 > * + * { margin-left: .5rem; }
.me-2 { margin-inline-end: .5rem; }
.mr-2 { margin-right: .5rem; }
.aspect-square { aspect-ratio: 1 / 1; }
.placeholder\:text-muted-foreground::placeholder { color: rgb(161,161,170); }
@media (min-width: 1024px) {
  .lg\:flex-row { flex-direction: row; }
}

/* 🧭 Navigation */
.nav {
  background-color: var(--bg-secondary);
  border-bottom: 1px solid var(--border-primary);
}

.nav-link {
  color: var(--text-primary);
  border-radius: var(--btn-border-radius);
  transition: all 0.2s ease;
}

.nav-link:hover {
  background-color: var(--bg-primary);
  color: var(--text-secondary);
}

/* 📊 Statistics Cards */
.stat-card {
  background: linear-gradient(135deg, var(--bg-secondary) 0%, var(--bg-primary) 100%);
  border: 1px solid var(--border-primary);
  border-radius: var(--btn-border-radius);
  padding: var(--content-padding);
  color: var(--text-primary);
}

/* 🔍 Search Box */
.search-box {
  background-color: var(--bg-secondary);
  border: 1px solid var(--border-primary);
  border-radius: var(--btn-border-radius);
  color: var(--text-primary);
  padding: var(--btn-padding);
}

/* 📄 Pagination */
.pagination .page-link {
  background-color: var(--bg-secondary);
  border: 1px solid var(--border-primary);
  color: var(--text-primary);
}

.pagination .page-link:hover {
  background-color: var(--bg-primary);
  color: var(--text-secondary);
}

/* ✅ Checkbox Styles */
.checkbox {
  accent-color: var(--text-primary);
}

/* 🎨 Theme Toggle */
.theme-toggle {
  background-color: var(--bg-secondary);
  border: 1px solid var(--border-primary);
  border-radius: 50%;
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.2s ease;
}

.theme-toggle:hover {
  background-color: var(--bg-primary);
  transform: scale(1.1);
}

/* 📱 Responsive */
@media (max-width: 768px) {
  :root {
    --content-padding: 10px;
    --btn-padding: 6px;
  }
}

        </style>
        /* === End CSS === */
</head>
<body>
    <!-- Exact Fisch Tracker Layout -->
    <div class="fisch-app">
        <!-- Sidebar -->
        <div class="fisch-sidebar">
            <!-- Logo Section -->
            <div class="sidebar-logo">
                <span class="logo-text">Fisch</span>
            </div>
            
            <!-- Single Game Item -->
            <div class="game-list">
                <div class="game-item active">
                    <div class="game-icon fisch"></div>
                </div>
            </div>
            
            <!-- Bottom Section -->
            <div class="sidebar-bottom">
                <div class="user-profile">
                    <div class="profile-avatar">Z</div>
                </div>
            </div>
        </div>
        
        <!-- Main Content -->
        <div class="main-content">
            <!-- Top Header (exact layout) -->
            <header class="group-has-data-[collapsible=icon]/sidebar-wrapper:h-12 flex h-12 shrink-0 items-center gap-2 border-b transition-[width,height] ease-linear pl-2 pr-6">
              <div class="flex w-full items-center gap-1 px-4 lg:gap-2">
                <button class="inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50 hover:bg-accent hover:text-accent-foreground h-7 w-7 -ml-1" data-sidebar="trigger" aria-label="Toggle Sidebar">
                  <svg width="15" height="15" viewBox="0 0 15 15" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M8 2H13.5C13.7761 2 14 2.22386 14 2.5V12.5C14 12.7761 13.7761 13 13.5 13H8V2ZM7 2H1.5C1.22386 2 1 2.22386 1 2.5V12.5C1 12.7761 1.22386 13 1.5 13H7V2ZM0 2.5C0 1.67157 0.671573 1 1.5 1H13.5C14.3284 1 15 1.67157 15 2.5V12.5C15 13.3284 14.3284 14 13.5 14H1.5C0.671573 14 0 13.3284 0 12.5V2.5Z" fill="currentColor" fill-rule="evenodd" clip-rule="evenodd"></path></svg>
                  <span class="sr-only">Toggle Sidebar</span>
                </button>
                <div data-orientation="vertical" role="none" class="shrink-0 bg-border h-full w-[1px] mx-2 data-[orientation=vertical]:h-4"></div>
                <h1 class="text-base font-medium capitalize">fisch</h1>
              </div>
              <button class="inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50 border border-input bg-background shadow-sm hover:bg-accent hover:text-accent-foreground h-9 w-9" type="button" id="themeToggle" aria-haspopup="menu" aria-expanded="false" data-state="closed">
                <svg id="sunIcon" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-sun h-[1.2rem] w-[1.2rem] rotate-0 scale-100 transition-all dark:-rotate-90 dark:scale-0"><circle cx="12" cy="12" r="4"></circle><path d="M12 2v2"></path><path d="M12 20v2"></path><path d="m4.93 4.93 1.41 1.41"></path><path d="m17.66 17.66 1.41 1.41"></path><path d="M2 12h2"></path><path d="M20 12h2"></path><path d="m6.34 17.66-1.41 1.41"></path><path d="m19.07 4.93-1.41 1.41"></path></svg>
                <svg id="moonIcon" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-moon absolute h-[1.2rem] w-[1.2rem] rotate-90 scale-0 transition-all dark:rotate-0 dark:scale-100"><path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"></path></svg>
                <span class="sr-only">Toggle theme</span>
              </button>
              <button type="button" role="combobox" aria-expanded="false" aria-autocomplete="none" dir="ltr" data-state="closed" class="flex h-9 items-center justify-between whitespace-nowrap rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-sm ring-offset-transparent placeholder:text-muted-foreground focus:outline-none focus:ring-1 focus:ring-ring disabled:cursor-not-allowed disabled:opacity-50 [&>span]:line-clamp-1 w-[180px]">
                <span style="pointer-events: none;">
                  <div class="flex item-center space-x-3">
                    <div class="rounded-full w-[20px] h-[20px] bg-zinc-700"></div>
                    <div class="text-sm">Zinc</div>
                  </div>
                </span>
                <svg width="15" height="15" viewBox="0 0 15 15" fill="none" xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 opacity-50" aria-hidden="true"><path d="M4.93179 5.43179C4.75605 5.60753 4.75605 5.89245 4.93179 6.06819C5.10753 6.24392 5.39245 6.24392 5.56819 6.06819L7.49999 4.13638L9.43179 6.06819C9.60753 6.24392 9.89245 6.24392 10.0682 6.06819C10.2439 5.89245 10.2439 5.60753 10.0682 5.43179L7.81819 3.18179C7.73379 3.0974 7.61933 3.04999 7.49999 3.04999C7.38064 3.04999 7.26618 3.0974 7.18179 3.18179L4.93179 5.43179ZM10.0682 9.56819C10.2439 9.39245 10.2439 9.10753 10.0682 8.93179C9.89245 8.75606 9.60753 8.75606 9.43179 8.93179L7.49999 10.8636L5.56819 8.93179C5.39245 8.75606 5.10753 8.75606 4.93179 8.93179C4.75605 9.10753 4.75605 9.39245 4.93179 9.56819L7.18179 11.8182C7.35753 11.9939 7.64245 11.9939 7.81819 11.8182L10.0682 9.56819Z" fill="currentColor" fill-rule="evenodd" clip-rule="evenodd"></path></svg>
              </button>
            </header>
            
            <!-- Content Area -->
            <div class="@container/main pt-6 flex flex-col gap-4 px-6">
                <!-- Stats Cards (exact 2 cards) -->
                <div class="grid grid-cols-2 lg:grid-cols-2 gap-4">
                    <div class="rounded-xl border bg-card text-card-foreground shadow flex-1">
                        <div class="p-4 flex flex-row justify-between pb-2">
                            <h3 class="tracking-tight text-sm font-normal"><span class="text-green-600">Online</span> / <span>Accounts</span></h3>
                        </div>
                        <div class="p-4 pt-0 flex justify-between">
                            <div class="font-bold"><span class="text-2xl font-bold"><span class="text-green-600" id="statOnline">0</span>/<span id="statAccounts">0</span></span></div>
                            <button class="h-8 rounded-md px-3 text-xs" title="Delete all accounts">
                                <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-user-round-x text-red-600">
                                    <path d="M2 21a8 8 0 0 1 11.873-7"></path>
                                    <circle cx="10" cy="8" r="5"></circle>
                                    <path d="m17 17 5 5"></path>
                                    <path d="m22 17-5 5"></path>
                                </svg>
                            </button>
                        </div>
                    </div>
                    <div class="rounded-xl border bg-card text-card-foreground shadow flex-1">
                        <div class="p-4 flex flex-row items-center justify-between pb-2">
                            <h3 class="tracking-tight text-sm font-normal flex items-center gap-2 capitalize"><img src="/items/fisch/enchant.webp" class="h-5" alt="Enchant">Total Enchant</h3>
                        </div>
                        <div class="p-4 pt-0 flex items-center">
                            <p class="text-lg font-bold" id="statTotalEnchant">0</p>
                        </div>
                    </div>
                </div>
                
                <!-- Toolbar: Search + Filter + Actions -->
                <div class="w-full flex flex-col items-center lg:flex-row gap-4 mb-2">
                  <input id="searchInput" class="flex h-9 w-full rounded-md border border-input bg-transparent px-3 py-1 text-sm shadow-sm placeholder:text-muted-foreground" placeholder="Search in everything..." value="" />
                  <div>
                    <div id="statusRadios" role="radiogroup" aria-required="false" dir="ltr" class="flex gap-5" tabindex="0" style="outline: none;">
                      <div class="flex items-center space-x-2">
                        <button type="button" role="radio" aria-checked="true" data-state="checked" value="all" class="aspect-square h-4 w-4 rounded-full border border-primary text-primary shadow-sm" id="r1" tabindex="-1">
                          <span data-state="checked" class="flex items-center justify-center">
                            <svg width="15" height="15" viewBox="0 0 15 15" fill="none" xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5 fill-primary"><path d="M11.4669 3.72684C11.7558 3.91574 11.8369 4.30308 11.648 4.59198L7.39799 11.092C7.29783 11.2452 7.13556 11.3467 6.95402 11.3699C6.77247 11.3931 6.58989 11.3355 6.45446 11.2124L3.70446 8.71241C3.44905 8.48022 3.43023 8.08494 3.66242 7.82953C3.89461 7.57412 4.28989 7.55529 4.5453 7.78749L6.75292 9.79441L10.6018 3.90792C10.7907 3.61902 11.178 3.53795 11.4669 3.72684Z" fill="currentColor" fill-rule="evenodd" clip-rule="evenodd"></path></svg>
                          </span>
                        </button>
                        <label class="text-sm font-medium leading-none" for="r1">All</label>
                      </div>
                      <div class="flex items-center space-x-2">
                        <button type="button" role="radio" aria-checked="false" data-state="unchecked" value="online" class="aspect-square h-4 w-4 rounded-full border border-primary text-primary shadow-sm" id="r2" tabindex="-1"></button>
                        <label class="text-sm font-medium leading-none" for="r2">Online</label>
                      </div>
                      <div class="flex items-center space-x-2">
                        <button type="button" role="radio" aria-checked="false" data-state="unchecked" value="offline" class="aspect-square h-4 w-4 rounded-full border border-primary text-primary shadow-sm" id="r3" tabindex="-1"></button>
                        <label class="text-sm font-medium leading-none" for="r3">Offline</label>
                      </div>
                    </div>
                  </div>
                  <div class="flex flex-row gap-2">
                    <button class="inline-flex items-center justify-center whitespace-nowrap font-medium bg-secondary text-secondary-foreground shadow-sm h-8 rounded-md px-3 text-xs" title="Google Sheets">
                      <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-file-spreadsheet me-2"><path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"></path><path d="M14 2v4a2 2 0 0 0 2 2h4"></path><path d="M8 13h2"></path><path d="M14 13h2"></path><path d="M8 17h2"></path><path d="M14 17h2"></path></svg>
                      Google Sheets
                    </button>
                    <button class="inline-flex items-center justify-center whitespace-nowrap font-medium bg-secondary text-secondary-foreground shadow-sm h-8 rounded-md px-3 text-xs" title="Copy Scripts">
                      <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-copy me-2"><rect width="14" height="14" x="8" y="8" rx="2" ry="2"></rect><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"></path></svg>
                      Script
                    </button>
                    <button class="flex items-center justify-center whitespace-nowrap font-medium bg-secondary text-secondary-foreground shadow-sm h-8 rounded-md px-3 text-xs" title="Import Cookies" type="button">
                      <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-upload mr-2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="17 8 12 3 7 8"></polyline><line x1="12" x2="12" y1="3" y2="15"></line></svg>
                      Cookies
                    </button>
                  </div>
                </div>
                
                <!-- Table toolbar (items + page size + pager) and table -->
                <div class="flex flex-col lg:flex-row gap-2 mt-1 lg:mt-0 items-center justify-between">
                  <div class="w-full lg:hidden"></div>
                  <div class="w-full lg:w-fit flex justify-between items-center gap-2">
                    <div class="inline-flex items-center rounded-md border px-2.5 py-0.5 font-semibold border-transparent bg-primary text-primary-foreground shadow text-sm"><span id="itemCount">0</span> items</div>
                    <div class="hidden lg:flex"></div>
                    <button type="button" role="combobox" aria-expanded="false" class="flex h-9 items-center justify-between whitespace-nowrap rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-sm w-\[80px\] lg:hidden"><span style="pointer-events: none;">20</span>
                      <svg width="15" height="15" viewBox="0 0 15 15" fill="none" xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 opacity-50" aria-hidden="true"><path d="M4.93179 5.43179C4.75605 5.60753 4.75605 5.89245 4.93179 6.06819C5.10753 6.24392 5.39245 6.24392 5.56819 6.06819L7.49999 4.13638L9.43179 6.06819C9.60753 6.24392 9.89245 6.24392 10.0682 6.06819C10.2439 5.89245 10.2439 5.60753 10.0682 5.43179L7.81819 3.18179C7.73379 3.0974 7.61933 3.04999 7.49999 3.04999C7.38064 3.04999 7.26618 3.0974 7.18179 3.18179L4.93179 5.43179ZM10.0682 9.56819C10.2439 9.39245 10.2439 9.10753 10.0682 8.93179C9.89245 8.75606 9.60753 8.75606 9.43179 8.93179L7.49999 10.8636L5.56819 8.93179C5.39245 8.75606 5.10753 8.75606 4.93179 8.93179C4.75605 9.10753 4.75605 9.39245 4.93179 9.56819L7.18179 11.8182C7.35753 11.9939 7.64245 11.9939 7.81819 11.8182L10.0682 9.56819Z" fill="currentColor" fill-rule="evenodd" clip-rule="evenodd"></path></svg>
                    </button>
                  </div>
                  <div class="flex items-center gap-4 justify-between lg:justify-end w-full lg:w-auto">
                    <button type="button" class="h-9 items-center justify-between whitespace-nowrap rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-sm w-\[80px\] hidden lg:flex"><span style="pointer-events: none;">20</span>
                      <svg width="15" height="15" viewBox="0 0 15 15" fill="none" xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 opacity-50" aria-hidden="true"><path d="M4.93179 5.43179C4.75605 5.60753 4.75605 5.89245 4.93179 6.06819C5.10753 6.24392 5.39245 6.24392 5.56819 6.06819L7.49999 4.13638L9.43179 6.06819C9.60753 6.24392 9.89245 6.24392 10.0682 6.06819C10.2439 5.89245 10.2439 5.60753 10.0682 5.43179L7.81819 3.18179C7.73379 3.0974 7.61933 3.04999 7.49999 3.04999C7.38064 3.04999 7.26618 3.0974 7.18179 3.18179L4.93179 5.43179ZM10.0682 9.56819C10.2439 9.39245 10.2439 9.10753 10.0682 8.93179C9.89245 8.75606 9.60753 8.75606 9.43179 8.93179L7.49999 10.8636L5.56819 8.93179C5.39245 8.75606 5.10753 8.75606 4.93179 8.93179C4.75605 9.10753 4.75605 9.39245 4.93179 9.56819L7.18179 11.8182C7.35753 11.9939 7.64245 11.9939 7.81819 11.8182L10.0682 9.56819Z" fill="currentColor" fill-rule="evenodd" clip-rule="evenodd"></path></svg>
                    </button>
                    <p class="text-sm"><span id="currentPageDisplay">1</span> of <span id="pageCount">0</span> pages</p>
                    <div class="space-x-2">
                      <button id="firstPage" class="inline-flex items-center justify-center whitespace-nowrap font-medium border border-input bg-background shadow-sm h-8 rounded-md px-3 text-xs" disabled>
                        <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-chevrons-left"><path d="m11 17-5-5 5-5"></path><path d="m18 17-5-5 5-5"></path></svg>
                      </button>
                      <button id="prevPage" class="inline-flex items-center justify-center whitespace-nowrap font-medium border border-input bg-background shadow-sm h-8 rounded-md px-3 text-xs" disabled>
                        <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-chevron-left"><path d="m15 18-6-6 6-6"></path></svg>
                      </button>
                      <button id="nextPage" class="inline-flex items-center justify-center whitespace-nowrap font-medium border border-input bg-background shadow-sm h-8 rounded-md px-3 text-xs" disabled>
                        <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-chevron-right"><path d="m9 18 6-6-6-6"></path></svg>
                      </button>
                      <button id="lastPage" class="inline-flex items-center justify-center whitespace-nowrap font-medium border border-input bg-background shadow-sm h-8 rounded-md px-3 text-xs" disabled>
                        <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-chevrons-right"><path d="m6 17 5-5-5-5"></path><path d="m13 17 5-5-5-5"></path></svg>
                      </button>
                    </div>
                  </div>
                </div>
                <div class="rounded-md border">
                  <div class="relative w-full overflow-auto">
                    <table class="w-full caption-bottom text-sm">
                      <thead class="[&_tr]:border-b">
                        <tr class="border-b transition-colors hover:bg-muted/50 data-[state=selected]:bg-muted">
                          <th class="h-12 px-4 text-left align-middle font-medium text-muted-foreground [&:has([role=checkbox])]:pr-0 capitalize">
                            <button id="selectAllBtn" type="button" role="checkbox" aria-checked="false" data-state="unchecked" value="on" class="peer h-4 w-4 shrink-0 rounded-sm border border-primary shadow-sm" aria-label="Select all"></button>
                          </th>
                          <th class="h-12 px-4 text-left align-middle font-medium text-muted-foreground [&:has([role=checkbox])]:pr-0 capitalize">account</th>
                          <th class="h-12 px-4 text-left align-middle font-medium text-muted-foreground [&:has([role=checkbox])]:pr-0 capitalize"><div class="flex justify-center items-center"><p>level</p></div></th>
                          <th class="h-12 px-4 text-left align-middle font-medium text-muted-foreground [&:has([role=checkbox])]:pr-0 capitalize"><div class="flex justify-center items-center gap-2"><img src="/items/fisch/enchant.webp" class="h-5"><p>enchant</p></div></th>
                          <th class="h-12 px-4 text-left align-middle font-medium text-muted-foreground [&:has([role=checkbox])]:pr-0 capitalize"><div class="flex justify-center items-center gap-2"><img src="/items/fisch/coins.webp" class="h-5"><p>coins</p></div></th>
                          <th class="h-12 px-4 text-left align-middle font-medium text-muted-foreground [&:has([role=checkbox])]:pr-0 capitalize"><div class="flex justify-center items-center gap-2"><img src="/items/fisch/rod.webp" class="h-5"><p>rod</p></div></th>
                          <th class="h-12 px-4 text-left align-middle font-medium text-muted-foreground [&:has([role=checkbox])]:pr-0 capitalize"><div class="flex justify-center items-center gap-2"><p>Items</p></div></th>
                        </tr>
                      </thead>
                      <tbody class="[&_tr:last-child]:border-0" id="dataTableBody">
                        <!-- Data rows injected by JS -->
                      </tbody>
                    </table>
                  </div>
                </div>
        </div>
    </div>

    
    <script>
        // Global state
        let allData = [];
        let filteredData = [];
        let selectedItems = new Set();
        let currentPage = 1;
        const itemsPerPage = 20;
        
        // Theme management
        function initTheme() {
            const saved = localStorage.getItem('theme');
            const isDark = saved === 'dark' || (!saved && window.matchMedia('(prefers-color-scheme: dark)').matches);
            if (isDark) {
                document.documentElement.classList.add('dark');
            }
            const sun = document.getElementById('sunIcon');
            const moon = document.getElementById('moonIcon');
            if (sun && moon) {
                sun.style.display = isDark ? 'none' : 'block';
                moon.style.display = isDark ? 'block' : 'none';
            }
        }
        
        function toggleTheme() {
            const isDark = document.documentElement.classList.toggle('dark');
            localStorage.setItem('theme', isDark ? 'dark' : 'light');
            const sun = document.getElementById('sunIcon');
            const moon = document.getElementById('moonIcon');
            if (sun && moon) {
                sun.style.display = isDark ? 'none' : 'block';
                moon.style.display = isDark ? 'block' : 'none';
            }
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
                const tb = document.getElementById('dataTableBody');
                if (tb) tb.innerHTML = 
                    '<tr><td colspan="7" class="error">Error loading data</td></tr>';
            }
        }
        
        // Update statistics
        function updateStats(stats) {
            // Compute from allData as fallback
            const totalAccounts = (stats && (stats.totalAccounts || stats.total || stats.accounts)) || (Array.isArray(allData) ? allData.length : 0);
            const onlineAccounts = (stats && (stats.onlineAccounts || stats.online)) || (Array.isArray(allData) ? allData.filter(r => r.online).length : 0);
            const totalEnchant = (stats && (stats.totalEnchant || stats.enchantTotal)) || (Array.isArray(allData) ? allData.reduce((s, r) => s + (r.enchant || r.enchantStones || 0), 0) : 0);
            // Update new header counters
            const elOnline = document.getElementById('statOnline');
            const elAccounts = document.getElementById('statAccounts');
            const elEnchant = document.getElementById('statTotalEnchant');
            if (elOnline) elOnline.textContent = onlineAccounts;
            if (elAccounts) elAccounts.textContent = totalAccounts;
            if (elEnchant) elEnchant.textContent = totalEnchant;
            // Legacy stat label if exists
            const statLabel = document.querySelector('.stat-label');
            if (statLabel) statLabel.textContent = onlineAccounts + '/' + totalAccounts;
        }
        
        // Filter data
        function filterData() {
            const searchInput = document.getElementById('searchInput');
            const searchTerm = (searchInput ? searchInput.value : '').toLowerCase();
            let statusFilter = 'all';
            const radioGroup = document.querySelector('[role="radiogroup"]');
            if (radioGroup) {
                const selectedBtn = radioGroup.querySelector('[role="radio"][aria-checked="true"]');
                if (selectedBtn) statusFilter = selectedBtn.getAttribute('value') || 'all';
            } else {
                const legacy = document.querySelector('input[name="s"]:checked');
                if (legacy) statusFilter = legacy.value;
            }
            
            filteredData = allData.filter(row => {
                // Search filter - match account and rod like React component
                const searchMatch = !searchTerm || 
                    (row.account + ' ' + (row.rod || '')).toLowerCase().includes(searchTerm);
                
                // Status filter
                const statusMatch = statusFilter === 'all' || 
                    (statusFilter === 'online' && row.online) ||
                    (statusFilter === 'offline' && !row.online);
                
                return searchMatch && statusMatch;
            });
            
            currentPage = 1;
            updateTable();
            updatePagination();
            const ic = document.getElementById('itemCount');
            if (ic) ic.textContent = filteredData.length.toString();
        }
        
        // Toggle row selection
        function toggleRowSelection(account) {
            if (selectedItems.has(account)) {
                selectedItems.delete(account);
            } else {
                selectedItems.add(account);
            }
            updateTable();
            updateSelectAllButton();
        }
        
        // Toggle select all
        function toggleSelectAll() {
            const pageSize = 20;
            const start = (currentPage - 1) * pageSize;
            const pageRows = filteredData.slice(start, start + pageSize);
            const allSelected = pageRows.length > 0 && pageRows.every(row => selectedItems.has(row.account));
            
            if (allSelected) {
                // Deselect all items on current page
                pageRows.forEach(row => selectedItems.delete(row.account));
            } else {
                // Select all items on current page
                pageRows.forEach(row => selectedItems.add(row.account));
            }
            
            updateTable();
            updateSelectAllButton();
        }
        
        // Update select all button state
        function updateSelectAllButton() {
            const btn = document.getElementById('selectAllBtn');
            const pageSize = 20;
            const start = (currentPage - 1) * pageSize;
            const pageRows = filteredData.slice(start, start + pageSize);
            const allSelected = pageRows.length > 0 && pageRows.every(row => selectedItems.has(row.account));
            const someSelected = pageRows.some(row => selectedItems.has(row.account)) && !allSelected;
            
            btn.setAttribute('data-checked', allSelected.toString());
            
            if (allSelected) {
                btn.innerHTML = '<svg viewBox="0 0 24 24" class="checkbox-icon"><path d="M4 12l5 5 11-11"/></svg>';
            } else if (someSelected) {
                btn.innerHTML = '<svg viewBox="0 0 24 24" class="checkbox-icon"><line x1="5" y1="12" x2="19" y2="12"/></svg>';
            } else {
                btn.innerHTML = '';
            }
        }
        
        // Update table
        function updateTable() {
            const tbody = document.getElementById('dataTableBody');
            
            if (filteredData.length === 0) {
                tbody.innerHTML = '<tr><td colspan="8" style="text-align: center; padding: 20px; color: rgb(161, 161, 170);">No results found</td></tr>';
                return;
            }
            
            const start = (currentPage - 1) * itemsPerPage;
            const pageData = filteredData.slice(start, start + itemsPerPage);
            
            tbody.innerHTML = pageData.map((row, index) => {
                const isSelected = selectedItems.has(row.account);
                const nf = new Intl.NumberFormat();
                const itemsCount = (row && (row.itemsCount != null ? row.itemsCount : (Array.isArray(row.items) ? row.items.length : 0))) || 0;
                
                return '<tr>' +
                    '<td class="checkbox-cell"><input type="checkbox" ' + (isSelected ? 'checked' : '') + ' onclick="toggleRowSelection(\'' + (row.account || '') + '\')" /></td>' +
                    '<td>' + (row.account || 'Unknown') + '</td>' +
                    '<td><div class="flex justify-center items-center"><p>' + (row.level || 0) + '</p></div></td>' +
                    '<td><div class="flex justify-center items-center gap-2"><img src="/items/fisch/enchant.webp" class="h-5"><p>' + (row.enchant || row.enchantStones || 0) + '</p></div></td>' +
                    '<td><div class="flex justify-center items-center gap-2"><img src="/items/fisch/coins.webp" class="h-5"><p>' + nf.format(row.coins || 0) + '</p></div></td>' +
                    '<td><div class="flex justify-center items-center gap-2"><img src="/items/fisch/rod.webp" class="h-5"><p>' + (row.rod || 'N/A') + '</p></div></td>' +
                    '<td><div class="flex justify-center items-center gap-2"><p>' + itemsCount + '</p></div></td>' +
                    '</tr>';
            }).join('');
        }
        
        // Update pagination display and controls
        function updatePagination() {
            const pageSize = 20;
            const pageCount = Math.max(1, Math.ceil(filteredData.length / pageSize));
            
            // Update current page and page count display
            const cur = document.getElementById('currentPageDisplay');
            const cnt = document.getElementById('pageCount');
            if (cur) cur.textContent = currentPage;
            if (cnt) cnt.textContent = pageCount;
            
            // Update button states
            const firstBtn = document.getElementById('firstPage');
            const prevBtn = document.getElementById('prevPage');
            const nextBtn = document.getElementById('nextPage');
            const lastBtn = document.getElementById('lastPage');
            if (firstBtn) firstBtn.disabled = currentPage === 1;
            if (prevBtn) prevBtn.disabled = currentPage === 1;
            if (nextBtn) nextBtn.disabled = currentPage === pageCount;
            if (lastBtn) lastBtn.disabled = currentPage === pageCount;
        }
        
        // Event listeners
        document.addEventListener('DOMContentLoaded', function() {
            initTheme();
            fetchData();
            
            // Theme toggle
            document.getElementById('themeToggle').addEventListener('click', toggleTheme);
            
            // Search
            document.getElementById('searchInput').addEventListener('input', filterData);
            
            // Radiogroup behavior
            const rg = document.querySelector('[role="radiogroup"]');
            if (rg) {
                rg.querySelectorAll('[role="radio"]').forEach(btn => {
                    btn.addEventListener('click', () => {
                        rg.querySelectorAll('[role="radio"]').forEach(b => { b.setAttribute('aria-checked','false'); b.setAttribute('data-state','unchecked'); });
                        btn.setAttribute('aria-checked','true');
                        btn.setAttribute('data-state','checked');
                        currentPage = 1;
                        filterData();
                    });
                });
            }
            
            // Pagination event listeners
            const fp = document.getElementById('firstPage'); if (fp) fp.addEventListener('click', () => {
                currentPage = 1;
                updateTable();
                updatePagination();
                updateSelectAllButton();
            });
            
            const pp = document.getElementById('prevPage'); if (pp) pp.addEventListener('click', () => {
                if (currentPage > 1) {
                    currentPage--;
                    updateTable();
                    updatePagination();
                    updateSelectAllButton();
                }
            });
            
            const np = document.getElementById('nextPage'); if (np) np.addEventListener('click', () => {
                const pageSize = 20;
                const pageCount = Math.max(1, Math.ceil(filteredData.length / pageSize));
                if (currentPage < pageCount) {
                    currentPage++;
                    updateTable();
                    updatePagination();
                    updateSelectAllButton();
                }
            });
            
            const lp = document.getElementById('lastPage'); if (lp) lp.addEventListener('click', () => {
                const pageSize = 20;
                const pageCount = Math.max(1, Math.ceil(filteredData.length / pageSize));
                currentPage = pageCount;
                updateTable();
                updatePagination();
                updateSelectAllButton();
            });
            
            // Select all button
            const sab = document.getElementById('selectAllBtn'); if (sab) sab.addEventListener('click', toggleSelectAll);
            
            // Auto-refresh every 10 seconds
            setInterval(fetchData, 10000);
        });
        
        // Make functions global for onclick handlers
        window.toggleRowSelection = toggleRowSelection;
        window.toggleSelectAll = toggleSelectAll;
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
