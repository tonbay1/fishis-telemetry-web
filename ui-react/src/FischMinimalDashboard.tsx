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
  Coins as CoinsIcon,
  Fish,
  Package2,
  Key,
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



// Helper formatters
const nf = new Intl.NumberFormat();

type PlayerDetail = {
  playerName: string;
  money: number;
  level: number;
  equippedRod: string;
  location: string;
  rods: string[];
  baits: string[];
};

// --- Component ---------------------------------------------------------------
type DataRow = Row & Partial<PlayerDetail> & { 
  playerName?: string; 
  materials?: Record<string, number>; 
  rodsDetailed?: Array<{name:string; udid:string}>;
  lastUpdated?: string;
  timestamp?: string;
};

export default function FischMinimalDashboard({ rows = [] }: { rows?: Row[] }) {
  // API base resolves from environment (set VITE_API_BASE_URL in Vercel)
  // Allow override from URL parameter &api= for testing
  const getApiBase = () => {
    try {
      const params = new URLSearchParams(window.location.search);
      const apiParam = params.get('api');
      if (apiParam) return apiParam;
    } catch {}
    return (import.meta as any)?.env?.VITE_API_BASE_URL || 'https://kenny-bicycle-queensland-surname.trycloudflare.com';
  };
  const API_BASE: string = getApiBase();
  const [query, setQuery] = React.useState("");
  const [status, setStatus] = React.useState<"all" | "online" | "offline">("all");
  const [page, setPage] = React.useState(1);
  const [selected, setSelected] = React.useState<string[]>([]);
  const [dark, setDark] = React.useState(false);
  const [data, setData] = React.useState<DataRow[]>(rows as DataRow[]);
  const [selectedAccount, setSelectedAccount] = React.useState<string>((rows as Row[])[0]?.account ?? "");
  const [player, setPlayer] = React.useState<PlayerDetail | null>(null);
  const [usingCache, setUsingCache] = React.useState(false);
  const [cacheTime, setCacheTime] = React.useState<number | null>(null);
  const LS_KEY = 'fishis:data:v1';
  const LS_AUTH_KEY = 'fishis:key:v1';
  const [authKey, setAuthKey] = React.useState<string | null>(null);
  const [scriptOpen, setScriptOpen] = React.useState(false);
  const [creatingKey, setCreatingKey] = React.useState(false);
  const LS_ADMIN_TOKEN = 'fishis:admin:token';
  const [adminToken, setAdminToken] = React.useState<string>(() => localStorage.getItem(LS_ADMIN_TOKEN) || '');
  const [rememberAdmin, setRememberAdmin] = React.useState<boolean>(!!localStorage.getItem(LS_ADMIN_TOKEN));
  const [createdKey, setCreatedKey] = React.useState<string | null>(null);
  
  // User key functionality
  const LS_USER_KEY = 'fishis:user:key:v1';
  const [userKey, setUserKey] = React.useState<string>(() => localStorage.getItem(LS_USER_KEY) || '');
  const [rememberKey, setRememberKey] = React.useState<boolean>(!!localStorage.getItem(LS_USER_KEY));
  const [loadingUserData, setLoadingUserData] = React.useState(false);
  const [userDataError, setUserDataError] = React.useState<string>('');
  const autoLoadAttempted = React.useRef(false);
  const [autoRefresh, setAutoRefresh] = React.useState(true);
  const [lastRefresh, setLastRefresh] = React.useState<number>(0);
  const refreshTimerRef = React.useRef<NodeJS.Timeout | null>(null);
  
  // Delete functionality
  const [selectedForDelete, setSelectedForDelete] = React.useState<string[]>([]);
  const [deleting, setDeleting] = React.useState(false);
  const [deleteConfirmOpen, setDeleteConfirmOpen] = React.useState(false);

  // Smart data merging to prevent flickering
  const mergeDataSmart = (newData: DataRow[], currentData: DataRow[]) => {
    if (!Array.isArray(newData) || newData.length === 0) return currentData;
    if (!Array.isArray(currentData) || currentData.length === 0) return newData;
    
    // Create a map of current data by account for fast lookup
    const currentMap = new Map(currentData.map(item => [item.account, item]));
    
    // Merge new data with current, preserving order and updating existing
    const merged = newData.map(newItem => {
      const existing = currentMap.get(newItem.account);
      if (existing) {
        // Update existing item with new data, but preserve UI state
        return { ...existing, ...newItem, lastUpdated: newItem.lastUpdated || existing.lastUpdated };
      }
      return newItem;
    });
    
    // Add any accounts that exist in current but not in new (in case of temporary API issues)
    currentData.forEach(currentItem => {
      if (!newData.find(newItem => newItem.account === currentItem.account)) {
        merged.push(currentItem);
      }
    });
    
    return merged;
  };

  // Function to load data for a specific key (with smart merging)
  const loadDataForKey = async (k: string, isRefresh = false) => {
    if (!k) {
      setData([]);
      return;
    }
    try {
      if (!isRefresh) setLoadingUserData(true);
      setUserDataError('');
      const res = await fetch(`${API_BASE}/api/data?key=${encodeURIComponent(k)}`);
      if (!res.ok) {
        setUserDataError(`Server error: ${res.status}`);
        if (!isRefresh) setData([]);
        return;
      }
      const userData = await res.json();
      if (Array.isArray(userData) && userData.length > 0) {
        setData(currentData => {
          // Use smart merging for refreshes to prevent flickering
          return isRefresh ? mergeDataSmart(userData as DataRow[], currentData) : userData as DataRow[];
        });
        setUsingCache(false);
        setCacheTime(Date.now());
        setLastRefresh(Date.now());
      } else {
        if (!isRefresh) {
          setUserDataError('No data found for this key. Make sure you have run the telemetry script at least once.');
          setData([]);
        }
      }
    } catch (e) {
      if (!isRefresh) {
        setUserDataError('Network error while loading data. Please check your connection and try again.');
        setData([]);
      }
    } finally {
      if (!isRefresh) setLoadingUserData(false);
    }
  };

  // Auto-refresh timer setup
  React.useEffect(() => {
    if (!autoRefresh || !userKey) {
      if (refreshTimerRef.current) {
        clearInterval(refreshTimerRef.current);
        refreshTimerRef.current = null;
      }
      return;
    }

    // Set up auto-refresh every 30 seconds
    refreshTimerRef.current = setInterval(() => {
      if (userKey && autoRefresh) {
        loadDataForKey(userKey, true); // isRefresh = true
      }
    }, 30000);

    return () => {
      if (refreshTimerRef.current) {
        clearInterval(refreshTimerRef.current);
        refreshTimerRef.current = null;
      }
    };
  }, [autoRefresh, userKey]);

  // Auto-load user data if ?key= is present in URL (single effect)
  React.useEffect(() => {
    // Only run once on mount
    if (autoLoadAttempted.current) return;
    autoLoadAttempted.current = true;
    
    try {
      const params = new URLSearchParams(window.location.search);
      const k = (params.get('key') || '').trim();
      if (k) {
        setUserKey(k);
        setRememberKey(true);
        try { localStorage.setItem(LS_USER_KEY, k); } catch {}
        // Load data immediately
        loadDataForKey(k);
      } else {
        // Try to load from localStorage if no URL key
        try {
          const savedKey = localStorage.getItem(LS_USER_KEY);
          if (savedKey) {
            setUserKey(savedKey);
            setRememberKey(true);
            loadDataForKey(savedKey);
          }
        } catch {}
      }
    } catch {}
  }, []); // Remove API_BASE dependency to prevent re-runs

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

  const createKey = async () => {
    try {
      setCreatingKey(true);
      const res = await fetch(`${API_BASE}/keys/new`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${adminToken}` },
      });
      if (!res.ok) {
        alert('Failed to create key (unauthorized or server error).');
        return;
      }
      const j = await res.json();
      const k = j.key as string;
      setCreatedKey(k);
      if (rememberAdmin && adminToken) localStorage.setItem(LS_ADMIN_TOKEN, adminToken);
      if (!rememberAdmin) localStorage.removeItem(LS_ADMIN_TOKEN);
    } catch (e) {
      alert('Network error while creating key.');
    } finally {
      setCreatingKey(false);
    }
  };

  const loaderUrl = React.useMemo(() => {
    return createdKey ? `${API_BASE.replace(/\/$/, '')}/script/${encodeURIComponent(createdKey)}` : '';
  }, [createdKey, API_BASE]);
  const loaderLine = React.useMemo(() => createdKey ? `loadstring(game:HttpGet("${loaderUrl}"))()` : '', [createdKey, loaderUrl]);
  const viewerUrl = React.useMemo(() => createdKey ? `${window.location.origin}${window.location.pathname}?key=${encodeURIComponent(createdKey)}` : '', [createdKey]);
  const copy = async (text: string) => { try { await navigator.clipboard.writeText(text); } catch {} };

  // User key functions
  const loadUserData = async () => {
    if (!userKey.trim()) return;
    
    try {
      setLoadingUserData(true);
      setUserDataError('');
      
      let res;
      
      // Direct API call to configured API_BASE (must be HTTPS in production)
      res = await fetch(`${API_BASE}/api/data?key=${encodeURIComponent(userKey.trim())}`);
      
      if (!res.ok) {
        if (res.status === 404) {
          setUserDataError('Key not found or no data available for this key.');
        } else {
          setUserDataError(`Server error: ${res.status}`);
        }
        return;
      }
      
      const userData = await res.json();
      if (Array.isArray(userData) && userData.length > 0) {
        setData(userData as DataRow[]);
        setUsingCache(false);
        setCacheTime(Date.now());
        
        // Save key to localStorage if remember is checked
        if (rememberKey) {
          localStorage.setItem(LS_USER_KEY, userKey.trim());
        } else {
          localStorage.removeItem(LS_USER_KEY);
        }
        
        setScriptOpen(false);
      } else {
        setUserDataError('No data found for this key. Make sure you have run the telemetry script at least once.');
      }
    } catch (e) {
      setUserDataError('Network error while loading data. Please check your connection and try again.');
    } finally {
      setLoadingUserData(false);
    }
  };
  
  const clearUserKey = () => {
    setUserKey('');
    setUserDataError('');
    localStorage.removeItem(LS_USER_KEY);
    setRememberKey(false);
  };

  // Delete functionality
  const deleteSelectedAccounts = async () => {
    if (!userKey.trim() || selectedForDelete.length === 0) return;
    
    try {
      setDeleting(true);
      
      const res = await fetch(`${API_BASE}/api/data`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          key: userKey.trim(),
          accounts: selectedForDelete
        })
      });
      
      if (!res.ok) {
        const errorData = await res.json().catch(() => ({ message: 'Unknown error' }));
        alert(`Failed to delete accounts: ${errorData.message}`);
        return;
      }
      
      const result = await res.json();
      
      // Remove deleted accounts from current data
      const updatedData = data.filter(item => {
        const account = item.account || item.playerName || '';
        return !selectedForDelete.includes(account);
      });
      
      setData(updatedData);
      setSelectedForDelete([]);
      setDeleteConfirmOpen(false);
      
      // Update cache
      const cacheKey = `${LS_KEY}:${userKey.trim()}`;
      try {
        localStorage.setItem(cacheKey, JSON.stringify({
          data: updatedData,
          timestamp: Date.now()
        }));
      } catch {}
      
      alert(`Successfully deleted ${result.deletedCount} account(s). ${result.remainingCount} accounts remaining.`);
      
    } catch (error) {
      console.error('Delete error:', error);
      alert('Network error while deleting accounts.');
    } finally {
      setDeleting(false);
    }
  };
  
  const toggleAccountForDelete = (account: string) => {
    setSelectedForDelete(prev => 
      prev.includes(account) 
        ? prev.filter(acc => acc !== account)
        : [...prev, account]
    );
  };
  
  const selectAllForDelete = () => {
    const allAccounts = data.map(item => item.account || item.playerName || '').filter(Boolean);
    setSelectedForDelete(allAccounts);
  };
  
  const clearDeleteSelection = () => {
    setSelectedForDelete([]);
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

  // Read auth key from URL (?key=) or localStorage
  React.useEffect(() => {
    const u = new URL(window.location.href);
    const k = u.searchParams.get('key');
    if (k && k.length > 0) {
      setAuthKey(k);
      localStorage.setItem(LS_AUTH_KEY, k);
    } else {
      const kk = localStorage.getItem(LS_AUTH_KEY);
      if (kk) setAuthKey(kk);
    }
  }, []);
  
  // Removed duplicate useEffect hooks - now handled in single useEffect above

  const toggleTheme = () => {
    setDark((d) => {
      const next = d ? "light" : "dark";
      applyTheme(next);
      return next === "dark";
    });
  };

  // SECURITY: Load cache only for specific user key (prevent data leakage)
  React.useEffect(() => {
    // Only load cache if we have a userKey (user-specific data)
    if (!userKey) {
      console.log('No userKey - skipping cache load for security');
      return;
    }
    
    try {
      // Try to load user-specific cache first
      const userCacheKey = `${LS_KEY}:${userKey}`;
      let raw = localStorage.getItem(userCacheKey);
      
      // Fallback to general cache only if it matches the user key
      if (!raw) {
        const generalRaw = localStorage.getItem(LS_KEY);
        if (generalRaw) {
          const generalObj = JSON.parse(generalRaw);
          // Only use general cache if it's for this specific user
          if (generalObj?.key === userKey) {
            raw = generalRaw;
          }
        }
      }
      
      if (raw) {
        const obj = JSON.parse(raw);
        const arr = Array.isArray(obj?.data) ? obj.data : [];
        
        // Double-check: filter data to ensure it belongs to this user
        const userSpecificData = arr.filter((it: any) => {
          const account = (it.account || it.playerName || '').toLowerCase();
          const keyAccount = userKey.toLowerCase();
          return account.includes(keyAccount) || it.key === userKey;
        });
        
        if (userSpecificData.length) {
          const mapped: DataRow[] = userSpecificData.map((it: any) => ({
            account: it.account || it.playerName || "",
            level: it.level ?? 0,
            enchant: 0,
            coins: it.coins ?? it.money ?? 0,
            rod: it.equippedRod || it.rod || "",
            items: Array.isArray(it.items) ? it.items.length : (typeof it.items === 'number' ? it.items : 0),
            online: it.online !== false,
            playerName: it.playerName,
            money: it.money,
            equippedRod: it.equippedRod,
            location: it.location,
            rods: Array.isArray(it.rods) ? it.rods : [],
            baits: Array.isArray(it.baits) ? it.baits : [],
            materials: (it.materials && typeof it.materials === 'object') ? it.materials : undefined,
            rodsDetailed: Array.isArray(it.rodsDetailed) ? it.rodsDetailed : undefined,
            rodsDisplay: typeof it.rodsDisplay === 'string' ? it.rodsDisplay : undefined,
            rodsDisplayMode: typeof it.rodsDisplayMode === 'string' ? it.rodsDisplayMode : undefined,
          }));
          setData(mapped);
          if (!selectedAccount && mapped.length) setSelectedAccount(mapped[0].account);
          setUsingCache(true);
          if (typeof obj?.ts === 'number') setCacheTime(obj.ts);
          console.log(`Loaded ${mapped.length} cached items for user: ${userKey}`);
        }
      }
    } catch {}
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userKey]); // Depend on userKey to reload cache when user changes

  // Fetch data from API (ADMIN ONLY - requires authKey for security)
  const fetchData = React.useCallback(async () => {
    // SECURITY: Only allow data fetching with valid authKey to prevent unauthorized access
    if (!authKey) {
      console.warn('fetchData: No authKey provided - preventing unauthorized data access');
      return;
    }
    
    try {
      const url = `${API_BASE}/api/data?key=${encodeURIComponent(authKey)}`;
      const res = await fetch(url);
      if (!res.ok) return;
      const arr = await res.json();
      const mapped: DataRow[] = (arr || []).map((it: any) => ({
        account: it.account || it.playerName || "",
        level: it.level ?? 0,
        enchant: 0,
        coins: it.coins ?? it.money ?? 0,
        rod: it.equippedRod || it.rod || "",
        items: Array.isArray(it.items) ? it.items.length : (typeof it.items === 'number' ? it.items : 0),
        online: it.online !== false,
        playerName: it.playerName,
        money: it.money,
        equippedRod: it.equippedRod,
        location: it.location,
        rods: Array.isArray(it.rods) ? it.rods : [],
        baits: Array.isArray(it.baits) ? it.baits : [],
        materials: (it.materials && typeof it.materials === 'object') ? it.materials : undefined,
        rodsDetailed: Array.isArray(it.rodsDetailed) ? it.rodsDetailed : undefined,
        // new display fields from API enrichment
        rodsDisplay: typeof it.rodsDisplay === 'string' ? it.rodsDisplay : undefined,
        rodsDisplayMode: typeof it.rodsDisplayMode === 'string' ? it.rodsDisplayMode : undefined,
      }));
      setData(mapped);
      if (!selectedAccount && mapped.length) setSelectedAccount(mapped[0].account);
      // cache to localStorage with key-specific storage
      try {
        const pack = { ts: Date.now(), data: arr, key: authKey };
        localStorage.setItem(`${LS_KEY}:${authKey}`, JSON.stringify(pack));
        setUsingCache(false);
        setCacheTime(pack.ts);
      } catch {}
    } catch {}
  }, [selectedAccount, API_BASE, authKey]);

  // Removed conflicting auto-refresh - now handled by loadDataForKey for user-specific data
  // fetchData is only used for admin/general data viewing

  // Filter & derive -----------------------------------------------------------
  const filtered = data.filter((r) => {
    const matchesQ = `${r.account} ${r.rod || r.equippedRod || ''}`.toLowerCase().includes(query.toLowerCase());
    const matchesS = status === "all" ? true : status === "online" ? !!r.online : !r.online;
    return matchesQ && matchesS;
  });

  const pageCount = Math.max(1, Math.ceil(filtered.length / pageSize));
  const totalAccounts = data.length;
  const onlineCount = data.filter((r) => r.online).length;
  const offlineCount = totalAccounts - onlineCount;
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

  // Fetch player details from server, fallback to row
  React.useEffect(() => {
    let cancelled = false;
    async function run() {
      try {
        if (!selectedAccount) return;
        const res = await fetch(`${API_BASE}/api/latest/${encodeURIComponent(selectedAccount)}`);
        if (!res.ok) throw new Error("bad");
        const data = await res.json();
        const pd: PlayerDetail = {
          playerName: data.playerName || selectedAccount,
          money: (data.money ?? data.coins) || 0,
          level: data.level ?? 0,
          equippedRod: data.equippedRod ?? data.rod ?? "",
          location: data.location ?? "Unknown",
          rods: Array.isArray(data.rods) ? data.rods : [],
          baits: Array.isArray(data.baits) ? data.baits : [],
        };
        if (!cancelled) setPlayer(pd);
      } catch (e) {
        const row = rows.find((r) => r.account === selectedAccount);
        const pd: PlayerDetail = {
          playerName: selectedAccount,
          money: row?.coins ?? 0,
          level: row?.level ?? 0,
          equippedRod: row?.rod ?? "",
          location: "Unknown",
          rods: [],
          baits: [],
        };
        if (!cancelled) setPlayer(pd);
      }
    }
    run();
    return () => {
      cancelled = true;
    };
  }, [selectedAccount, rows, API_BASE]);

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

      {/* Layout wrapper with sidebar */}
      <div className="group/sidebar-wrapper flex min-h-svh w-full">
        {/* Sidebar (fixed, icon-only width by var) */}
        <div className="fixed inset-y-0 z-10 hidden h-svh w-[calc(var(--sidebar-width-icon)_+_theme(spacing.4)_+2px)] transition-[left,right,width] duration-200 ease-linear md:flex left-0 p-2">
          <div data-sidebar="sidebar" className="flex h-full w-full flex-col bg-sidebar text-sidebar-foreground">
            <div data-sidebar="header" className="flex flex-col gap-2 p-2">
              <ul data-sidebar="menu" className="flex w-full min-w-0 flex-col gap-1">
                <li data-sidebar="menu-item" className="group/menu-item relative">
                  <div className="peer/menu-button flex w-full items-center gap-2 overflow-hidden rounded-md p-2 text-left outline-none ring-sidebar-ring transition-[width,height,padding] focus-visible:ring-2 hover:bg-primary/30 hover:text-primary-foreground h-8 text-sm group-data-[collapsible=icon]:!p-1 cursor-pointer" data-sidebar="menu-button" data-size="default" data-active="false">
                    <img src="https://yummytrackstat.com/items/fisch/logo.webp" className="w-8" alt="logo" />
                    <span className="text-base font-semibold">Yummytrackstats</span>
                  </div>
                </li>
              </ul>
            </div>
            <div data-sidebar="content" className="flex min-h-0 flex-1 flex-col gap-2 overflow-auto group-data-[collapsible=icon]:overflow-hidden">
              <div data-sidebar="group" className="relative flex w-full min-w-0 flex-col p-2">
                <div data-sidebar="group-content" className="w-full text-sm flex flex-col gap-2">
                  <ul data-sidebar="menu" className="flex w-full min-w-0 flex-col gap-1">
                    <li data-sidebar="menu-item" className="group/menu-item relative">
                      <button data-sidebar="menu-button" data-size="default" data-active="true" className="peer/menu-button flex w-full items-center gap-2 overflow-hidden rounded-md p-2 text-left outline-none ring-sidebar-ring transition-[width,height,padding] focus-visible:ring-2 hover:bg-primary/30 hover:text-primary-foreground h-8 text-sm my-0.5 group-data-[collapsible=icon]:!p-1" data-state="closed">
                        <img src="https://yummytrackstat.com/items/fisch/logo.webp" className="object-cover rounded w-6 h-6" alt="fisch" />
                        <span className="capitalize font-medium">fisch</span>
                      </button>
                    </li>
                  </ul>
                </div>
              </div>
            </div>
          </div>
        </div>
        {/* Main */}
        <main className="relative flex w-full flex-1 flex-col bg-background md:m-2 md:rounded-xl md:shadow md:ml-[calc(var(--sidebar-width-icon)_+_theme(spacing.4)_+2px)]">
      {/* Header */}
      <header className="group-has-data-[collapsible=icon]/sidebar-wrapper:h-12 flex h-12 shrink-0 items-center gap-2 border-b transition-[width,height] ease-linear pl-2 pr-6">
        <div className="flex w-full items-center gap-1 px-4 lg:gap-2">
          <button className="inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50 hover:bg-accent hover:text-accent-foreground h-7 w-7 -ml-1" aria-label="Toggle Sidebar">
            <svg width="15" height="15" viewBox="0 0 15 15" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M8 2H13.5C13.7761 2 14 2.22386 14 2.5V12.5C14 12.7761 13.7761 13 13.5 13H8V2ZM7 2H1.5C1.22386 2 1 2.22386 1 2.5V12.5C1 12.7761 1.22386 13 1.5 13H7V2ZM0 2.5C0 1.67157 0.671573 1 1.5 1H13.5C14.3284 1 15 1.67157 15 2.5V12.5C15 13.3284 14.3284 14 13.5 14H1.5C0.671573 14 0 13.3284 0 12.5V2.5Z" fill="currentColor" fillRule="evenodd" clipRule="evenodd"></path></svg>
            <span className="sr-only">Toggle Sidebar</span>
          </button>
          <div role="none" className="shrink-0 bg-border h-full w-[1px] mx-2"></div>
          <h1 className="text-base font-medium capitalize">fisch</h1>
        </div>
        <button
          type="button"
          className="inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50 border border-input bg-background shadow-sm hover:bg-accent hover:text-accent-foreground h-9 w-9 relative"
          aria-label="Toggle theme"
          onMouseDown={(e)=>{e.preventDefault(); e.stopPropagation();}}
          onClick={(e)=>{ e.preventDefault(); e.stopPropagation(); toggleTheme(); }}
        >
          <Sun className={`h-[1.2rem] w-[1.2rem] transition-all ${dark ? "-rotate-90 scale-0" : "rotate-0 scale-100"}`} />
          <MoonStar className={`absolute h-[1.2rem] w-[1.2rem] transition-all ${dark ? "rotate-0 scale-100" : "rotate-90 scale-0"}`} />
          <span className="sr-only">Toggle theme</span>
        </button>
        {/* Auto-refresh controls */}
        <div className="flex items-center gap-2 ml-3">
          <button
            type="button"
            className={`inline-flex items-center gap-1 px-2 py-1 rounded text-xs transition-colors ${
              autoRefresh 
                ? 'bg-green-100 text-green-700 hover:bg-green-200 dark:bg-green-900 dark:text-green-300' 
                : 'bg-gray-100 text-gray-600 hover:bg-gray-200 dark:bg-gray-800 dark:text-gray-400'
            }`}
            onClick={() => setAutoRefresh(!autoRefresh)}
            title={autoRefresh ? 'Auto-refresh ON (30s)' : 'Auto-refresh OFF'}
          >
            <div className={`w-2 h-2 rounded-full ${
              autoRefresh ? 'bg-green-500 animate-pulse' : 'bg-gray-400'
            }`} />
            {autoRefresh ? 'Auto' : 'Manual'}
          </button>
          
          {lastRefresh > 0 && (
            <span className="text-xs text-muted-foreground">
              {new Date(lastRefresh).toLocaleTimeString()}
            </span>
          )}
          
          {userKey && (
            <button
              type="button"
              className="inline-flex items-center gap-1 px-2 py-1 rounded text-xs bg-blue-100 text-blue-700 hover:bg-blue-200 dark:bg-blue-900 dark:text-blue-300 transition-colors"
              onClick={() => loadDataForKey(userKey, true)}
              disabled={loadingUserData}
              title="Refresh data now"
            >
              <svg className={`w-3 h-3 ${loadingUserData ? 'animate-spin' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
              </svg>
              Refresh
            </button>
          )}
          
          {/* Delete Controls */}
          {userKey && data.length > 0 && (
            <div className="flex items-center gap-1 ml-2 pl-2 border-l">
              {selectedForDelete.length > 0 && (
                <>
                  <span className="text-xs text-muted-foreground">
                    {selectedForDelete.length} selected
                  </span>
                  <button
                    type="button"
                    className="inline-flex items-center gap-1 px-2 py-1 rounded text-xs bg-red-100 text-red-700 hover:bg-red-200 dark:bg-red-900 dark:text-red-300 transition-colors"
                    onClick={() => setDeleteConfirmOpen(true)}
                    disabled={deleting}
                    title="Delete selected accounts"
                  >
                    <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                    </svg>
                    Delete ({selectedForDelete.length})
                  </button>
                  <button
                    type="button"
                    className="inline-flex items-center gap-1 px-2 py-1 rounded text-xs bg-gray-100 text-gray-600 hover:bg-gray-200 dark:bg-gray-800 dark:text-gray-400 transition-colors"
                    onClick={clearDeleteSelection}
                    title="Clear selection"
                  >
                    <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                    </svg>
                    Clear
                  </button>
                </>
              )}
              <button
                type="button"
                className="inline-flex items-center gap-1 px-2 py-1 rounded text-xs bg-orange-100 text-orange-700 hover:bg-orange-200 dark:bg-orange-900 dark:text-orange-300 transition-colors"
                onClick={selectAllForDelete}
                title="Select all accounts for deletion"
              >
                <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                Select All
              </button>
            </div>
          )}
        </div>
        
        {usingCache && (
          <span className="ml-3 text-xs text-amber-600">Showing cached data{cacheTime ? ` (${new Date(cacheTime).toLocaleTimeString()})` : ''}</span>
        )}
        {authKey && (
          <span className="ml-3 text-[10px] text-muted-foreground">key • {authKey.slice(0,8)}…</span>
        )}
        <button type="button" className="flex h-9 items-center justify-between whitespace-nowrap rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-sm w-[180px]">
          <span style={{ pointerEvents: 'none' }}>
            <div className="flex item-center space-x-3">
              <div className="rounded-full w-[20px] h-[20px] bg-zinc-700"></div>
              <div className="text-sm">Zinc</div>
            </div>
          </span>
          <svg width="15" height="15" viewBox="0 0 15 15" fill="none" xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 opacity-50" aria-hidden="true"><path d="M4.93179 5.43179C4.75605 5.60753 4.75605 5.89245 4.93179 6.06819C5.10753 6.24392 5.39245 6.24392 5.56819 6.06819L7.49999 4.13638L9.43179 6.06819C9.60753 6.24392 9.89245 6.24392 10.0682 6.06819C10.2439 5.89245 10.2439 5.60753 10.0682 5.43179L7.81819 3.18179C7.73379 3.0974 7.61933 3.04999 7.49999 3.04999C7.38064 3.04999 7.26618 3.0974 7.18179 3.18179L4.93179 5.43179ZM10.0682 9.56819C10.2439 9.39245 10.2439 9.10753 10.0682 8.93179C9.89245 8.75606 9.60753 8.75606 9.43179 8.93179L7.49999 10.8636L5.56819 8.93179C5.39245 8.75606 5.10753 8.75606 4.93179 8.93179C4.75605 9.10753 4.75605 9.39245 4.93179 9.56819L7.18179 11.8182C7.35753 11.9939 7.64245 11.9939 7.81819 11.8182L10.0682 9.56819Z" fill="currentColor" fillRule="evenodd" clipRule="evenodd"></path></svg>
        </button>
      </header>

      <div className="px-6 pt-6 flex flex-col gap-4">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {/* Left card: online/total */}
          <Card className="surface">
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <div className="text-sm text-muted-foreground">Online / Accounts</div>
                  <div className="text-2xl font-semibold mt-1"><span className="text-green-500">{data.filter(r=>r.online).length}</span>/<span>{data.length}</span></div>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Right card: Player Details (no Enchant) */}
          {/* (removed right card; details moved into table columns) */}
        </div>

        {/* Toolbar: Search + Filters + Actions */}
        <div className="w-full flex flex-col items-center md:flex-row gap-4 mt-4 mb-2">
          <div className="relative w-full md:w-auto md:flex-1">
            <Input value={query} onChange={(e)=>{setQuery(e.target.value); setPage(1);}} placeholder="Search in everything..." className="w-full md:w-[28rem] pr-10" />
            <Search className="absolute right-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          </div>
          <div className="flex items-center gap-5">
            <label className="radio-pill cursor-pointer select-none">
              <input type="radio" name="s" className="sr-only" checked={status==='all'} onChange={()=>{setStatus('all'); setPage(1);}} />
              <span className="radio-dot"/>
              <span>All ({data.length})</span>
            </label>
            <label className="radio-pill cursor-pointer select-none">
              <input type="radio" name="s" className="sr-only" checked={status==='online'} onChange={()=>{setStatus('online'); setPage(1);}} />
              <span className="radio-dot"/>
              <span>Online ({data.filter(r=>r.online).length})</span>
            </label>
            <label className="radio-pill cursor-pointer select-none">
              <input type="radio" name="s" className="sr-only" checked={status==='offline'} onChange={()=>{setStatus('offline'); setPage(1);}} />
              <span className="radio-dot"/>
              <span>Offline ({data.length - data.filter(r=>r.online).length})</span>
            </label>
          </div>
          <div className="flex flex-row gap-2">
            <Button variant="secondary" className="ghost-pill"><FileSpreadsheet className="mr-2 h-4 w-4"/>Google Sheets</Button>
            <Button variant="secondary" className="ghost-pill" onClick={()=>{ setScriptOpen(true); setCreatedKey(null); }}><Key className="mr-2 h-4 w-4"/>Enter Key</Button>
            <Button variant="secondary" className="ghost-pill"><Cookie className="mr-2 h-4 w-4"/>Cookies</Button>
          </div>
        </div>

        {/* Table */}
        <Card className="surface mt-2">
          <CardContent className="p-0">
            {/* Top controls: items + pager */}
            <div className="flex flex-col md:flex-row items-center justify-between gap-3 px-4 pt-3 pb-2">
              <Badge variant="secondary" className="rounded-full px-3 py-1 text-xs">{filtered.length} items</Badge>
              <div className="flex items-center gap-2">
                <div className="text-sm text-muted-foreground mr-2">{page} of {pageCount} pages</div>
                <Button variant="secondary" size="icon" className="ghost-pill" onClick={()=>setPage(1)} disabled={page===1}><ChevronsLeft className="h-4 w-4"/></Button>
                <Button variant="secondary" size="icon" className="ghost-pill" onClick={()=>setPage((p)=>Math.max(1,p-1))} disabled={page===1}><ChevronLeft className="h-4 w-4"/></Button>
                <Button variant="secondary" size="icon" className="ghost-pill" onClick={()=>setPage((p)=>Math.min(pageCount,p+1))} disabled={page===pageCount}><ChevronRight className="h-4 w-4"/></Button>
                <Button variant="secondary" size="icon" className="ghost-pill" onClick={()=>setPage(pageCount)} disabled={page===pageCount}><ChevronsRight className="h-4 w-4"/></Button>
              </div>
            </div>

            <Table>
              <TableHeader>
                <TableRow className="table-head">
                  <TableHead className="w-10">
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
                  {userKey && (
                    <TableHead className="w-10">
                      <span className="text-xs text-red-600 font-medium">Delete</span>
                    </TableHead>
                  )}
                  <TableHead>Account</TableHead>
                  <TableHead>
                    <span className="th-wrap"><CoinsIcon className="th-icon"/> Money</span>
                  </TableHead>
                  <TableHead>Level</TableHead>
                  <TableHead>
                    <span className="th-wrap"><Fish className="th-icon"/> Equipped Rod</span>
                  </TableHead>
                  <TableHead>Location</TableHead>
                  <TableHead>Rods</TableHead>
                  <TableHead>Baits</TableHead>
                  <TableHead>Materials</TableHead>
                </TableRow>
              </TableHeader>

              <TableBody>
                {pageRows.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={userKey ? 11 : 10} className="text-center py-10 text-sm text-muted-foreground">No results.</TableCell>
                  </TableRow>
                ) : (
                  pageRows.map((r, i) => (
                    <TableRow key={r.account} className={`table-row row-hover ${i % 2 ? 'row-alt' : ''} cursor-pointer`} onClick={() => setSelectedAccount(r.account)}>
                      <TableCell className="w-10">
                        <button
                          type="button"
                          aria-label="Select row"
                          className="checkbox-btn"
                          data-checked={selected.includes(r.account)}
                          onClick={(e) => { e.stopPropagation(); toggleRow(r.account); }}
                        >
                          {selected.includes(r.account) ? (
                            <svg viewBox="0 0 24 24" className="checkbox-icon"><path d="M4 12l5 5 11-11"/></svg>
                          ) : null}
                        </button>
                      </TableCell>
                      {userKey && (
                        <TableCell className="w-10">
                          <button
                            type="button"
                            aria-label="Mark for deletion"
                            className={`w-5 h-5 rounded border-2 flex items-center justify-center transition-colors ${
                              selectedForDelete.includes(r.account || r.playerName || '')
                                ? 'bg-red-500 border-red-500 text-white'
                                : 'border-red-300 hover:border-red-500 hover:bg-red-50 dark:border-red-600 dark:hover:bg-red-900'
                            }`}
                            onClick={(e) => {
                              e.stopPropagation();
                              toggleAccountForDelete(r.account || r.playerName || '');
                            }}
                          >
                            {selectedForDelete.includes(r.account || r.playerName || '') && (
                              <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                                <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                              </svg>
                            )}
                          </button>
                        </TableCell>
                      )}
                      <TableCell className="account-cell">{r.account}</TableCell>
                      <TableCell className="cell">{nf.format((r as any).coins ?? (r as any).money ?? 0)}</TableCell>
                      <TableCell className="cell">{r.level ?? 0}</TableCell>
                      <TableCell className="cell">{(r as any).equippedRod || r.rod || ''}</TableCell>
                      <TableCell className="cell">{(r as any).location || ''}</TableCell>
                      <TableCell className="cell">
                        {(() => {
                          const anyr = r as any;
                          const mode = anyr.rodsDisplayMode as string | undefined;
                          const disp = anyr.rodsDisplay as string | undefined;
                          const rodsArr: string[] = Array.isArray(anyr.rods) ? anyr.rods : [];
                          const count = String(rodsArr.length);
                          if (mode === 'text' && disp) {
                            return <span className="text-amber-600 font-medium">{disp}</span>;
                          }
                          // client-side fallback
                          const hasAstral = rodsArr.some(s => typeof s === 'string' && s.toLowerCase().includes('astral rod'));
                          const hasGhostfinn = rodsArr.some(s => typeof s === 'string' && s.toLowerCase().includes('ghostfinn rod'));
                          if (hasAstral || hasGhostfinn) {
                            const specials: string[] = [];
                            if (hasAstral) specials.push('Astral Rod');
                            if (hasGhostfinn) specials.push('Ghostfinn Rod');
                            return <span className="text-amber-600 font-medium">{specials.join(' & ')}</span>;
                          }
                          return count;
                        })()}
                      </TableCell>
                      <TableCell className="cell">
                        {(() => {
                          const anyr = r as any;
                          const mode = anyr.baitsDisplayMode as string | undefined;
                          const disp = anyr.baitsDisplay as string | undefined;
                          const baitsArr: string[] = Array.isArray(anyr.baits) ? anyr.baits : [];
                          const count = String(baitsArr.length);
                          if (mode === 'text' && disp) {
                            return <span className="text-violet-600 font-medium">{disp}</span>;
                          }
                          // client-side fallback: Corrupt Bait
                          const hasCorrupt = baitsArr.some(s => typeof s === 'string' && s.toLowerCase().includes('corrupt bait'));
                          if (hasCorrupt) {
                            return <span className="text-violet-600 font-medium">Corrupt Bait</span>;
                          }
                          return count;
                        })()}
                      </TableCell>
                      <TableCell className="cell">
                        {(() => {
                          const mats = (r as any).materials as Record<string, number> | undefined;
                          if (!mats) return 0;
                          const es = mats["Enchant Stone"] || 0;
                          const ses = mats["Super Enchant Stone"] || 0;
                          return es + ses;
                        })()}
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>

            {/* Bottom pagination removed; controls moved to top */}
          </CardContent>
        </Card>
      </div>
      </main>
      </div>

      {scriptOpen && (
        <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4" onClick={()=>setScriptOpen(false)}>
          <div className="surface w-full max-w-lg p-4 rounded-xl" onClick={(e)=>e.stopPropagation()}>
            <div className="flex items-center justify-between mb-3">
              <div className="text-base font-semibold">Enter Your Key</div>
              <button className="text-sm text-muted-foreground" onClick={()=>setScriptOpen(false)}>Close</button>
            </div>
            <div className="space-y-3">
              <div>
                <div className="text-sm mb-1">Your Telemetry Key</div>
                <input 
                  value={userKey} 
                  onChange={e=>setUserKey(e.target.value)} 
                  placeholder="Enter your key (e.g., 3eb40c38-77b5-4b1f-81ac-095c32de9fbc)" 
                  className="w-full border border-input bg-background rounded px-3 py-2 text-sm font-mono" 
                />
                <label className="mt-2 flex items-center gap-2 text-xs text-muted-foreground">
                  <input type="checkbox" checked={rememberKey} onChange={e=>setRememberKey(e.target.checked)} />
                  Remember on this device
                </label>
              </div>
              <div className="flex gap-2">
                <button 
                  disabled={loadingUserData || !userKey.trim()} 
                  onClick={loadUserData} 
                  className="inline-flex items-center justify-center rounded-md bg-primary text-primary-foreground hover:bg-primary/90 h-9 px-3 text-sm flex-1"
                >
                  {loadingUserData ? 'Loading…' : 'Load My Data'}
                </button>
                {userKey.trim() && (
                  <button 
                    onClick={clearUserKey} 
                    className="inline-flex items-center justify-center rounded-md bg-secondary text-secondary-foreground hover:bg-secondary/80 h-9 px-3 text-sm"
                  >
                    Clear
                  </button>
                )}
              </div>
              {userDataError && (
                <div className="text-xs text-red-500 p-2 rounded bg-red-50 dark:bg-red-950/20">
                  {userDataError}
                </div>
              )}
              <div className="text-xs text-muted-foreground">
                Enter the key you received when running the telemetry script. This will load your personal data from the API.
              </div>
            </div>
          </div>
        </div>
      )}
      
      {/* Delete Confirmation Dialog */}
      {deleteConfirmOpen && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-background border rounded-lg shadow-lg max-w-md w-full mx-4">
            <div className="p-6">
              <div className="flex items-center gap-3 mb-4">
                <div className="w-10 h-10 rounded-full bg-red-100 dark:bg-red-900 flex items-center justify-center">
                  <svg className="w-5 h-5 text-red-600 dark:text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 16.5c-.77.833.192 2.5 1.732 2.5z" />
                  </svg>
                </div>
                <div>
                  <h3 className="text-lg font-semibold text-foreground">Delete Accounts</h3>
                  <p className="text-sm text-muted-foreground">This action cannot be undone</p>
                </div>
              </div>
              
              <div className="mb-6">
                <p className="text-sm text-foreground mb-3">
                  Are you sure you want to delete the following {selectedForDelete.length} account(s)?
                </p>
                <div className="max-h-32 overflow-y-auto bg-muted rounded p-3">
                  {selectedForDelete.map((account, index) => (
                    <div key={account} className="text-sm font-mono text-foreground">
                      {index + 1}. {account}
                    </div>
                  ))}
                </div>
                <p className="text-xs text-red-600 dark:text-red-400 mt-3">
                  ⚠️ This will permanently remove all telemetry data for these accounts from your key's data file.
                </p>
              </div>
              
              <div className="flex gap-3 justify-end">
                <button
                  type="button"
                  className="inline-flex items-center justify-center rounded-md bg-secondary text-secondary-foreground hover:bg-secondary/80 h-9 px-4 text-sm"
                  onClick={() => setDeleteConfirmOpen(false)}
                  disabled={deleting}
                >
                  Cancel
                </button>
                <button
                  type="button"
                  className="inline-flex items-center justify-center rounded-md bg-red-600 text-white hover:bg-red-700 h-9 px-4 text-sm"
                  onClick={deleteSelectedAccounts}
                  disabled={deleting}
                >
                  {deleting ? (
                    <>
                      <svg className="w-4 h-4 mr-2 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                      </svg>
                      Deleting...
                    </>
                  ) : (
                    <>
                      <svg className="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                      </svg>
                      Delete {selectedForDelete.length} Account{selectedForDelete.length > 1 ? 's' : ''}
                    </>
                  )}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
