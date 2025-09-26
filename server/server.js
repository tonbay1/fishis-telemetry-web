import React from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import {
  ChevronLeft,
  ChevronRight,
  ChevronsLeft,
  ChevronsRight,
  MoonStar,
  Sun,
  Search,
  FileSpreadsheet,
  FileCode,
  Cookie,
  Wand2,
  Coins as CoinsIcon,
  Fish,
  Package2,
} from "lucide-react";

// --- Types & demo data -------------------------------------------------------
export type Row = {
  account: string;
  level: number;
  enchant: number;
  coins: number;
  rod: string;
  items: number;
  online: boolean;
};

const demoRows: Row[] = [
  { account: "ZentGen-01", level: 12, enchant: 3, coins: 15400, rod: "Steel Rod", items: 5, online: true },
  { account: "SHOP888-A", level: 9, enchant: 1, coins: 7200, rod: "Wood Rod", items: 2, online: false },
  { account: "rexzy-2", level: 17, enchant: 4, coins: 30210, rod: "Crystal Rod", items: 9, online: true },
];

// Helper formatters
const nf = new Intl.NumberFormat();

// --- Component ---------------------------------------------------------------
export default function FischMinimalDashboard({ rows = demoRows }: { rows?: Row[] }) {
  const [query, setQuery] = React.useState("");
  const [status, setStatus] = React.useState<"all" | "online" | "offline">("all");
  const [page, setPage] = React.useState(1);
  const [selected, setSelected] = React.useState<string[]>([]);
  const [dark, setDark] = React.useState(false);

  // --- THEME helpers ---------------------------------------------------------
  const clearInlineThemeVars = () => {
    const el = document.documentElement;
    const style = el.style as any;
    const keys: string[] = [];
    for (let i = 0; i < style.length; i++) {
      const prop = style[i] as string;
      if (prop && prop.startsWith("--")) keys.push(prop);
    }
    keys.forEach((k) => el.style.removeProperty(k));
  };

  const applyTheme = (next: "light" | "dark") => {
    clearInlineThemeVars();
    if (next === "dark") {
      document.documentElement.classList.add("dark");
      document.body.classList.add("dark");
    } else {
      document.documentElement.classList.remove("dark");
      document.body.classList.remove("dark");
    }
    localStorage.setItem("theme", next);
    setDark(next === "dark");
  };
  const pageSize = 20;

  // Theme: read saved preference on mount and apply .dark class
  React.useLayoutEffect(() => {
    const saved = localStorage.getItem("theme");
    const shouldDark = saved ? saved === "dark" : document.documentElement.classList.contains("dark");
    applyTheme(shouldDark ? "dark" : "light");
  }, []);

  const toggleTheme = () => {
    setDark((d) => {
      const next = d ? "light" : "dark";
      applyTheme(next);
      return next === "dark";
    });
  };

  // Filter & derive -----------------------------------------------------------
  const filtered = rows.filter((r) => {
    const matchesQ = `${r.account} ${r.rod}`.toLowerCase().includes(query.toLowerCase());
    const matchesS = status === "all" ? true : status === "online" ? r.online : !r.online;
    return matchesQ && matchesS;
  });

  const pageCount = Math.max(1, Math.ceil(filtered.length / pageSize));
  const totalAccounts = rows.length;
  const onlineCount = rows.filter((r) => r.online).length;
  const offlineCount = totalAccounts - onlineCount;
  const totalEnchant = rows.reduce((sum, r) => sum + (r.enchant || 0), 0);
  const start = (page - 1) * pageSize;
  const pageRows = filtered.slice(start, start + pageSize);

  const allSelected = pageRows.length > 0 && selected.length === pageRows.length;
  const someSelected = selected.length > 0 && selected.length < pageRows.length;

  const toggleAll = () => {
    if (allSelected) setSelected([]);
    else setSelected(pageRows.map((r) => r.account));
  };

  const toggleRow = (id: string) => {
    setSelected((prev) => (prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]));
  };

  return (
    <>
      {/* Light-mode only tweak: make selection boxes clearly visible (black outline/fill). The dark theme remains unchanged.*/}
      <style>{`
        /* layout */
        .app{min-height:100vh;background:hsl(var(--background));color:hsl(var(--foreground));}
        .surface{background:hsl(var(--card));border:1px solid hsl(var(--border));}
        .rounded-xl{border-radius:var(--radius)}

        /* pills */
        .ghost-pill{background:hsl(var(--secondary));color:hsl(var(--secondary-foreground));border:1px solid hsl(var(--border));}

        /* radios */
        .radio-pill{display:inline-flex;align-items:center;gap:.5rem;padding:.25rem .5rem;border-radius:9999px}
        .radio-dot{height:14px;width:14px;border-radius:9999px;border:2px solid hsl(var(--muted-foreground));display:inline-flex;align-items:center;justify-content:center}
        .radio-dot::after{content:"";height:6px;width:6px;border-radius:9999px;background:transparent}
        input[type="radio"]:checked + .radio-dot{border-color:hsl(var(--primary));}
        input[type="radio"]:checked + .radio-dot::after{background:hsl(var(--primary));}

        /* table visuals */
        .table-head{color:hsl(var(--foreground));font-weight:600;font-size:.875rem;padding-top:.75rem;padding-bottom:.5rem;border-bottom:1px solid hsl(var(--border));}
        .th-wrap{display:inline-flex;align-items:center;gap:.35rem}
        .th-icon{width:16px;height:16px;color:hsl(var(--muted-foreground))}
        .table-subtle{border:1px solid hsl(var(--border));background:hsl(var(--card));border-radius:calc(var(--radius) - 2px);} 
        .row-alt{background: rgba(0,0,0,.02);} /* light default */
        .row-hover:hover{background: rgba(0,0,0,.06);} /* light hover */
        .dark .row-alt{background: rgba(255,255,255,.04);} /* dark zebra */
        .dark .row-hover:hover{background: rgba(255,255,255,.08);} /* dark hover */
        .cell{padding-top:.75rem;padding-bottom:.75rem;}
        .table-row td{color:hsl(var(--foreground));}
        .table-row .account-cell{color:#4da6ff;font-weight:600;}

        /* checkboxes – force HIGH contrast */
        .checkbox-btn{height:1rem;width:1rem;border-radius:0.25rem;display:inline-flex;align-items:center;justify-content:center;cursor:pointer;transition:background .15s ease, box-shadow .15s ease}
        /* LIGHT THEME: solid black outline + black check when selected */
        html:not(.dark) .checkbox-btn{border:2px solid #000 !important;color:#000 !important;background:#fff !important}
        html:not(.dark) .checkbox-btn[data-checked="true"]{background:#000 !important;color:#fff !important}
        html:not(.dark) .checkbox-btn:hover{background:rgba(0,0,0,.06) !important}
        html:not(.dark) .checkbox-btn:focus-visible{outline:2px solid #000 !important;outline-offset:2px}
        /* DARK THEME: keep white outline like before */
        .dark .checkbox-btn{border:2px solid #ffffff;color:#ffffff;background:transparent}
        .dark .checkbox-btn[data-checked="true"]{background:#fff;color:#000}
        .checkbox-icon{height:.9rem;width:.9rem;display:block}
        .checkbox-icon path{stroke:currentColor;stroke-width:3;fill:none}
        .checkbox-icon line{stroke:currentColor;stroke-width:3}
      `}</style>

      <div className="app p-4 md:p-6">
        {/* Theme toggle */}
        <div
          className="flex justify-end mb-2"
          onClickCapture={(e) => e.stopPropagation()}
          onMouseDownCapture={(e) => e.stopPropagation()}
          onKeyDownCapture={(e) => e.stopPropagation()}
        >
          <Button
            type="button"
            variant="outline"
            size="icon"
            aria-label="Toggle theme"
            onClick={() => toggleTheme()}
            className="h-9 w-9 rounded-xl relative"
          >
            <Sun
              className={`h-[1.1rem] w-[1.1rem] transition-all ${dark ? "-rotate-90 scale-0" : "rotate-0 scale-100"}`}
            />
            <MoonStar
              className={`absolute h-[1.1rem] w-[1.1rem] transition-all ${dark ? "rotate-0 scale-100" : "rotate-90 scale-0"}`}
            />
            <span className="sr-only">Toggle theme</span>
          </Button>
        </div>

        <div className="grid grid-cols-1 gap-4 md:grid-cols-12">
          {/* Left card: online/total */}
          <Card className="surface md:col-span-7">
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <div className="text-sm text-muted-foreground">Online / Accounts</div>
                  <div className="text-2xl font-semibold mt-1"><span className="text-green-500">{rows.filter(r=>r.online).length}</span>/<span>{rows.length}</span></div>
                </div>
                <div className="relative">
                  <Input value={query} onChange={(e)=>setQuery(e.target.value)} placeholder="Search in everything..." className="w-72 pr-10" />
                  <Search className="absolute right-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                </div>
              </div>

              {/* Radios */}
              <div className="mt-3 flex items-center gap-3">
                <label className="radio-pill cursor-pointer select-none">
                  <input type="radio" name="s" className="sr-only" checked={status==='all'} onChange={()=>{setStatus('all'); setPage(1);}} />
                  <span className="radio-dot"/>
                  <span>All ({rows.length})</span>
                </label>
                <label className="radio-pill cursor-pointer select-none">
                  <input type="radio" name="s" className="sr-only" checked={status==='online'} onChange={()=>{setStatus('online'); setPage(1);}} />
                  <span className="radio-dot"/>
                  <span>Online ({rows.filter(r=>r.online).length})</span>
                </label>
                <label className="radio-pill cursor-pointer select-none">
                  <input type="radio" name="s" className="sr-only" checked={status==='offline'} onChange={()=>{setStatus('offline'); setPage(1);}} />
                  <span className="radio-dot"/>
                  <span>Offline ({rows.length - rows.filter(r=>r.online).length})</span>
                </label>
              </div>
            </CardContent>
          </Card>

          {/* Right card: total enchant */}
          <Card className="surface md:col-span-5">
            <CardContent className="p-4">
              <div className="text-sm text-muted-foreground">Total Enchant</div>
              <div className="text-2xl font-semibold mt-1">{rows.reduce((sum, r) => sum + (r.enchant || 0), 0)}</div>

              <div className="mt-4 flex flex-wrap gap-2">
                <Button variant="secondary" className="ghost-pill"><FileSpreadsheet className="mr-2 h-4 w-4"/>Google Sheets</Button>
                <Button variant="secondary" className="ghost-pill"><FileCode className="mr-2 h-4 w-4"/>Script</Button>
                <Button variant="secondary" className="ghost-pill"><Cookie className="mr-2 h-4 w-4"/>Cookies</Button>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Table */}
        <Card className="surface mt-4">
          <CardContent className="p-0">
            <div className="px-4 pt-3">
              <Badge variant="secondary" className="rounded-full px-3 py-1 text-xs">{filtered.length} items</Badge>
            </div>

            <Table>
              <TableHeader>
                <TableRow className="table-head">
                  <TableHead className="w-10">
                    {/* select all */}
                    <button
                      type="button"
                      aria-label="Select all"
                      className="checkbox-btn"
                      data-checked={allSelected}
                      onClick={toggleAll}
                    >
                      {allSelected ? (
                        <svg viewBox="0 0 24 24" className="checkbox-icon"><path d="M4 12l5 5 11-11"/></svg>
                      ) : someSelected ? (
                        <svg viewBox="0 0 24 24" className="checkbox-icon"><line x1="5" y1="12" x2="19" y2="12"/></svg>
                      ) : null}
                    </button>
                  </TableHead>
                  <TableHead>Account</TableHead>
                  <TableHead>Level</TableHead>
                  <TableHead>
                    <span className="th-wrap"><Wand2 className="th-icon"/> Enchant</span>
                  </TableHead>
                  <TableHead>
                    <span className="th-wrap"><CoinsIcon className="th-icon"/> Coins</span>
                  </TableHead>
                  <TableHead>
                    <span className="th-wrap"><Fish className="th-icon"/> Rod</span>
                  </TableHead>
                  <TableHead>
                    <span className="th-wrap"><Package2 className="th-icon"/> Items</span>
                  </TableHead>
                </TableRow>
              </TableHeader>

              <TableBody>
                {pageRows.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={7} className="text-center py-10 text-sm text-muted-foreground">No results.</TableCell>
                  </TableRow>
                ) : (
                  pageRows.map((r, i) => (
                    <TableRow key={r.account} className={`table-row row-hover ${i % 2 ? 'row-alt' : ''}`}>
                      <TableCell className="w-10">
                        <button
                          type="button"
                          aria-label="Select row"
                          className="checkbox-btn"
                          data-checked={selected.includes(r.account)}
                          onClick={() => toggleRow(r.account)}
                        >
                          {selected.includes(r.account) ? (
                            <svg viewBox="0 0 24 24" className="checkbox-icon"><path d="M4 12l5 5 11-11"/></svg>
                          ) : null}
                        </button>
                      </TableCell>
                      <TableCell className="account-cell">{r.account}</TableCell>
                      <TableCell className="cell">{r.level}</TableCell>
                      <TableCell className="cell">{r.enchant}</TableCell>
                      <TableCell className="cell">{nf.format(r.coins)}</TableCell>
                      <TableCell className="cell">{r.rod}</TableCell>
                      <TableCell className="cell">{r.items}</TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>

            {/* Pagination */}
            <div className="flex items-center justify-end gap-2 p-3">
              <div className="text-sm text-muted-foreground mr-2">1 of {pageCount} pages</div>
              <Button variant="secondary" size="icon" className="ghost-pill" onClick={()=>setPage(1)} disabled={page===1}><ChevronsLeft className="h-4 w-4"/></Button>
              <Button variant="secondary" size="icon" className="ghost-pill" onClick={()=>setPage((p)=>Math.max(1,p-1))} disabled={page===1}><ChevronLeft className="h-4 w-4"/></Button>
              <Button variant="secondary" size="icon" className="ghost-pill" onClick={()=>setPage((p)=>Math.min(pageCount,p+1))} disabled={page===pageCount}><ChevronRight className="h-4 w-4"/></Button>
              <Button variant="secondary" size="icon" className="ghost-pill" onClick={()=>setPage(pageCount)} disabled={page===pageCount}><ChevronsRight className="h-4 w-4"/></Button>
            </div>
          </CardContent>
        </Card>
      </div>
    </>
  );
}
