// check_db.js - Check database contents
const Database = require("better-sqlite3");

const db = new Database("telemetry.db");

console.log("📊 Checking telemetry database...");

// Check if table exists
const tables = db.prepare("SELECT name FROM sqlite_master WHERE type='table'").all();
console.log("📋 Tables:", tables.map(t => t.name));

// Check events count
const count = db.prepare("SELECT COUNT(*) as count FROM events").get();
console.log("📈 Total events:", count.count);

// Show recent events
if (count.count > 0) {
    console.log("\n🔍 Recent events:");
    const events = db.prepare("SELECT * FROM events ORDER BY ts DESC LIMIT 5").all();
    events.forEach((event, i) => {
        console.log(`${i+1}. Player: ${event.player}, Time: ${new Date(event.ts*1000).toISOString()}, Kind: ${event.kind}`);
    });
} else {
    console.log("❌ No events found in database");
}

db.close();
