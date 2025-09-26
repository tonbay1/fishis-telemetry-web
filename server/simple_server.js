// Simple test server
const express = require("express");
const app = express();

app.use(express.json({ limit: "2mb" }));

// Simple in-memory storage for testing
let events = [];

app.post("/ingest", (req, res) => {
    console.log("📥 Received POST /ingest");
    console.log("📦 Body:", JSON.stringify(req.body, null, 2));
    
    try {
        const { game, events: newEvents } = req.body || {};
        
        if (!Array.isArray(newEvents)) {
            console.log("❌ Invalid events array");
            return res.status(400).json({ error: "events[] required" });
        }
        
        // Store in memory
        events.push(...newEvents);
        console.log("✅ Stored", newEvents.length, "events. Total:", events.length);
        
        res.json({ ok: true, inserted: newEvents.length });
    } catch (err) {
        console.error("❌ Error:", err);
        res.status(500).json({ error: String(err) });
    }
});

app.get("/table", (req, res) => {
    console.log("📊 GET /table - showing", events.length, "events");
    
    let html = `
    <html><head><meta charset="utf-8"><title>FishIs Telemetry (Simple)</title>
    <style>
    body{background:#0b0b0b;color:#e9e9e9;font-family:Arial,sans-serif;margin:20px}
    table{border-collapse:collapse;width:100%;margin-top:10px}
    th,td{border:1px solid #333;padding:8px}
    th{background:#151515}
    td{background:#0f0f0f}
    </style>
    </head><body>
    <h2>FishIs Telemetry (Simple Test)</h2>
    <p>Total events: ${events.length}</p>
    <table>
      <tr><th>Time</th><th>Player</th><th>Kind</th><th>Level</th><th>Money</th></tr>
    `;
    
    events.slice(-10).forEach(e => {
        html += `<tr>
          <td>${new Date(e.ts * 1000).toISOString()}</td>
          <td>${e.player || 'Unknown'}</td>
          <td>${e.kind || 'unknown'}</td>
          <td>${e.level || 0}</td>
          <td>${e.money || 0}</td>
        </tr>`;
    });
    
    html += `</table></body></html>`;
    res.send(html);
});

app.get("/", (req, res) => {
    res.send("FishIs Telemetry Server is running! Visit /table to see data.");
});

const PORT = 3001;
app.listen(PORT, () => {
    console.log("🚀 Simple telemetry server running on port", PORT);
    console.log("📊 Visit http://localhost:3001/table to see data");
});

// Keep server alive
process.on('SIGINT', () => {
    console.log('\n👋 Server shutting down...');
    process.exit(0);
});
