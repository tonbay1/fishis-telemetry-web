import React, { useEffect, useState } from "react";

// RodsCard
// - Fetches /api/data from telemetry server
// - Shows rods as a count unless Astral/Ghostfinn are owned (then shows special text)
// - Tailwind-like utility classes (compatible with shadcn-style tokens)
export default function RodsCard() {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  async function load() {
    try {
      const res = await fetch("http://localhost:3001/api/data");
      const json = await res.json();
      setItems(Array.isArray(json) ? json : []);
      setError(null);
    } catch (e) {
      setError(e?.message || "Failed to load");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
    const id = setInterval(load, 5000);
    return () => clearInterval(id);
  }, []);

  if (loading) {
    return (
      <div className="rounded-xl border bg-card text-card-foreground p-4 shadow">
        <div className="text-sm text-muted-foreground">Loading rods…</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="rounded-xl border bg-card text-card-foreground p-4 shadow">
        <div className="text-sm text-destructive">{String(error)}</div>
      </div>
    );
  }

  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      {items.map((item, idx) => (
        <AccountRodsCard key={item.account || idx} item={item} />
      ))}
    </div>
  );
}

function AccountRodsCard({ item }) {
  const name = item.displayName || item.playerName || item.account || "Unknown";
  const location = item.location || "Unknown";
  const level = item.level ?? 0;

  const hasDisplay = typeof item.rodsDisplay === "string" && item.rodsDisplay.length > 0;
  const mode = item.rodsDisplayMode || (hasDisplay ? "text" : "count");

  // Fallback if server was old and didn't provide rodsDisplay
  const fallbackCount = Array.isArray(item.rods) ? String(item.rods.length) : "0";
  const display = hasDisplay ? item.rodsDisplay : fallbackCount;

  const isText = mode === "text";

  return (
    <div className="rounded-xl border bg-card text-card-foreground shadow">
      <div className="flex items-center justify-between p-4">
        <div>
          <div className="text-sm text-muted-foreground">{name}</div>
          <div className="text-xs text-muted-foreground mt-0.5">{location} • Lv {level}</div>
        </div>
        <div className="text-right">
          {isText ? (
            <div className="text-base font-medium text-amber-500">{display}</div>
          ) : (
            <div className="text-2xl font-bold">{display}</div>
          )}
          <div className="text-xs text-muted-foreground mt-0.5">Rods</div>
        </div>
      </div>
    </div>
  );
}
