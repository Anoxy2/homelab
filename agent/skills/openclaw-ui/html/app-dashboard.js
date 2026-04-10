// Canvas Dashboard
/* Copyright 2026 */
window.CanvasDashboard = {
  init: ({ ts, showError, setLoading }) => {
    const { cfg, saveCfg, DEFAULTS, sanitizeActions, sanitizeQuickLinks } = window.CanvasConfig;
    const classifyFetchError = window.CanvasNet?.classifyFetchError || (() => "network");
    const fetchWithPolicy = window.CanvasNet?.fetchWithPolicy || fetch;

/* ════════════════ DASHBOARD ════════════════ */
const MAX_TIMELINE = 12;
const MAX_TIMELINE_PERSISTED = 50;
const MAX_ACTION_QUEUE = 40;
const TIMELINE_STORAGE_KEY = "oc.canvas.v2.timeline";
const ACTION_QUEUE_STORAGE_KEY = "oc.canvas.v2.action-queue";
const healthEl = document.getElementById("health-chips");
const logEl    = document.getElementById("log");
const timelineEl = document.getElementById("timeline");
const mBridge  = document.getElementById("m-bridge");
const mLastAction = document.getElementById("m-last-action");
const mLastResult = document.getElementById("m-last-result");
const mLastUpdate = document.getElementById("m-last-update");
const mPiTemp = document.getElementById("m-pi-temp");
const dashUpdated = document.getElementById("dashboard-updated");
const gTemp = document.getElementById("g-temp");
const gHum = document.getElementById("g-hum");
const gCo2 = document.getElementById("g-co2");
const gVpd = document.getElementById("g-vpd");
const gRefresh = document.getElementById("g-refresh");
const gAlarm = document.getElementById("g-alarm");
const dashboardQuickLinksEl = document.getElementById("dashboard-quick-links");
const gTempSpark = document.getElementById("g-temp-spark");
const gHumSpark = document.getElementById("g-hum-spark");
const growboxChips = document.getElementById("growbox-state-chips");
const actionButtonsEl = document.getElementById("action-buttons");
const opsKpiGridEl = document.getElementById("ops-kpi-grid");
const serviceMatrixBody = document.getElementById("service-matrix-body");
const alertFeedEl = document.getElementById("alert-feed");
const btnRefreshAll = document.getElementById("btn-refresh-all");
const btnAutoRefresh = document.getElementById("btn-auto-refresh");
const btnExportSnapshot = document.getElementById("btn-export-snapshot");
const autoRefreshStateEl = document.getElementById("auto-refresh-state");
const dashOpenWorkSnapEl = document.getElementById("dash-open-work-snap");
const dashOpenWorkStatusEl = document.getElementById("dash-open-work-status");
const dashScoutSnapEl = document.getElementById("dash-scout-snap");
const dashScoutStatusEl = document.getElementById("dash-scout-status");
const dashHealthSnapEl = document.getElementById("dash-health-snap");
const dashHealthStatusEl = document.getElementById("dash-health-status");

const hasIOS     = () => !!(window.webkit?.messageHandlers?.openclawCanvasA2UIAction);
const hasAndroid = () => !!(window.openclawCanvasA2UIAction?.postMessage);
const hasHelper  = () => typeof window.openclawSendUserAction === "function";
const isMobileSurface = () => {
  const ua = String(navigator.userAgent || "").toLowerCase();
  return hasIOS() || hasAndroid() || /(android|iphone|ipad|ipod|mobile)/.test(ua);
};

const log = (msg) => { logEl.textContent = "[" + ts() + "] " + String(msg); };

const buildCoreServices = (c) => ([
  { key: "openclaw", name: "OpenClaw", url: c.openclawBaseUrl, open: c.openclawBaseUrl, probePath: "/__openclaw__/canvas/" },
  { key: "homeassistant", name: "Home Assistant", url: c.haBaseUrl, open: c.haBaseUrl },
  { key: "pihole", name: "Pi-hole", url: c.piholeBaseUrl, open: c.piholeBaseUrl },
]);
const MAX_HEALTH_SAMPLES = 20;
let autoRefreshEnabled = true;
const healthHistory = new Map();
const serviceSnapshot = new Map();
let healthSnapshot = { ts: "", services: [], alerts: [], growbox: {} };
let growboxStatus = { ok: true, alarm: false, message: "ok" };

const readJsonArray = (key) => {
  try {
    const parsed = JSON.parse(localStorage.getItem(key) || "[]");
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
};

const timelineEntries = readJsonArray(TIMELINE_STORAGE_KEY)
  .filter((row) => row && typeof row.text === "string")
  .slice(0, MAX_TIMELINE_PERSISTED);

let actionQueue = readJsonArray(ACTION_QUEUE_STORAGE_KEY)
  .filter((row) => row && typeof row.name === "string" && typeof row.sourceComponentId === "string")
  .slice(0, MAX_ACTION_QUEUE);

const persistTimeline = () => {
  localStorage.setItem(TIMELINE_STORAGE_KEY, JSON.stringify(timelineEntries.slice(0, MAX_TIMELINE_PERSISTED)));
};

const persistActionQueue = () => {
  localStorage.setItem(ACTION_QUEUE_STORAGE_KEY, JSON.stringify(actionQueue.slice(0, MAX_ACTION_QUEUE)));
};

const applyTimelineBorder = (li, stateClass) => {
  if (!stateClass) return;
  li.style.borderColor = stateClass === "ok"
    ? "rgba(57, 217, 138, 0.7)"
    : stateClass === "bad" ? "rgba(255, 107, 107, 0.8)" : "rgba(247, 185, 85, 0.8)";
};

const renderTimeline = () => {
  timelineEl.innerHTML = "";
  timelineEntries.slice(0, MAX_TIMELINE).forEach((entry) => {
    const li = document.createElement("li");
    li.textContent = entry.text;
    applyTimelineBorder(li, entry.stateClass || "");
    timelineEl.appendChild(li);
  });
};

const addTimeline = (text, stateClass) => {
  const li = document.createElement("li");
  const line = "[" + ts() + "] " + text;
  li.textContent = line;
  applyTimelineBorder(li, stateClass);
  timelineEl.prepend(li);
  timelineEntries.unshift({ text: line, stateClass: stateClass || "", at: Date.now() });
  while (timelineEntries.length > MAX_TIMELINE_PERSISTED) timelineEntries.pop();
  persistTimeline();
  while (timelineEl.children.length > MAX_TIMELINE) timelineEl.removeChild(timelineEl.lastChild);
};

renderTimeline();

const queuedCount = () => actionQueue.length;

const enqueueAction = (name, sourceComponentId, reason) => {
  actionQueue.push({
    name,
    sourceComponentId,
    queuedAt: Date.now(),
    reason: reason || "bridge unavailable",
  });
  while (actionQueue.length > MAX_ACTION_QUEUE) actionQueue.shift();
  persistActionQueue();
  addTimeline("Action queued: " + name + " (" + reason + ")", "warn");
};

const trySendActionPayload = (payload, maxRetries = 1) => {
  let ok = false;
  let tries = 0;
  while (tries <= maxRetries && !ok) {
    tries += 1;
    ok = !!window.openclawSendUserAction(payload);
  }
  return { ok, tries };
};

const flushQueuedActions = () => {
  if (!hasHelper() || !actionQueue.length) return { sent: 0, left: actionQueue.length };
  let sent = 0;
  while (actionQueue.length) {
    const next = actionQueue[0];
    const payload = {
      name: next.name,
      surfaceId: "main",
      sourceComponentId: next.sourceComponentId,
      context: { t: Date.now(), queuedAt: next.queuedAt, replay: true },
    };
    const attempt = trySendActionPayload(payload, 1);
    if (!attempt.ok) break;
    actionQueue.shift();
    sent += 1;
  }
  persistActionQueue();
  if (sent > 0) addTimeline("Queued actions synced: " + sent, "ok");
  return { sent, left: actionQueue.length };
};

const chip = (label, value, cls) => {
  const el = document.createElement("div");
  el.className = "chip " + cls;
  el.textContent = label + ": " + value;
  return el;
};

const renderQuickLinks = (links) => {
  if (!dashboardQuickLinksEl) return;
  dashboardQuickLinksEl.innerHTML = "";
  sanitizeQuickLinks(links).forEach((row) => {
    const a = document.createElement("a");
    a.href = row.url;
    a.target = "_blank";
    a.rel = "noopener";
    a.style.textDecoration = "none";
    const b = document.createElement("button");
    b.type = "button";
    b.textContent = row.label;
    a.appendChild(b);
    dashboardQuickLinksEl.appendChild(a);
  });
};

const probeWithLatency = async (url) => {
  const start = performance.now();
  try {
    await fetchWithPolicy(url, { method: "GET", mode: "no-cors", cache: "no-store" }, { timeoutMs: 2500, retries: 0 });
    return { ok: true, latencyMs: Math.round(performance.now() - start) };
  } catch {
    return { ok: false, latencyMs: Math.round(performance.now() - start) };
  }
};

const uniqueList = (arr) => Array.from(new Set(arr.filter(Boolean)));

const hostCandidates = (host) => {
  const current = String(host || "").trim();
  if (!current || current === "localhost" || current === "127.0.0.1") {
    return uniqueList(["192.168.2.101"]);
  }
  return uniqueList([current, "192.168.2.101"]);
};

const serviceFallbackUrls = (svc, host) => {
  try {
    const current = new URL(String(svc.url || ""));
    if (!/\.lan$/i.test(current.hostname)) return [];
    return hostCandidates(host).map((h) => {
      const next = new URL(current.toString());
      next.hostname = h;
      return next.toString().replace(/\/$/, "");
    });
  } catch {
    return [];
  }
};

const probeServiceWithFallback = async (svc, host) => {
  const probeTarget = (() => {
    try {
      const u = new URL(String(svc.url || ""));
      if (svc.probePath) u.pathname = svc.probePath;
      return u.toString();
    } catch {
      return svc.url;
    }
  })();
  const primary = await probeWithLatency(probeTarget);
  if (primary.ok) {
    return { ...svc, ok: true, latencyMs: primary.latencyMs };
  }

  const fallbacks = serviceFallbackUrls(svc, host);
  for (const fallbackUrl of fallbacks) {
    const fallbackProbe = await probeWithLatency(fallbackUrl);
    if (fallbackProbe.ok) {
      return {
        ...svc,
        ok: true,
        latencyMs: fallbackProbe.latencyMs,
        url: fallbackUrl,
        open: fallbackUrl,
      };
    }
  }

  return { ...svc, ok: false, latencyMs: primary.latencyMs };
};

const probeMqttWs = (host, port, timeoutMs = 3000) => new Promise((resolve) => {
  const startedAt = performance.now();
  const tryPath = (path, next) => {
    try {
      // Use the MQTT websocket subprotocol like the real connect flow.
      const ws = new WebSocket("ws://" + host + ":" + port + path, ["mqtt"]);
      const t = setTimeout(() => {
        try { ws.close(); } catch {}
        next(false);
      }, timeoutMs);
      ws.onopen = () => {
        clearTimeout(t);
        try { ws.close(); } catch {}
        resolve({ ok: true, path, latencyMs: Math.round(performance.now() - startedAt) });
      };
      ws.onerror = () => {
        clearTimeout(t);
        next(false);
      };
    } catch {
      next(false);
    }
  };

  tryPath("/mqtt", (ok) => {
    if (ok) return;
    tryPath("/", (ok2) => {
      if (ok2) return;
      resolve({ ok: false, path: "", latencyMs: Math.round(performance.now() - startedAt) });
    });
  });
});

const latencyLabel = (ms) => {
  if (!Number.isFinite(ms) || ms <= 0) return "--";
  return ms + " ms";
};

const hEsc = (s) => String(s)
  .replace(/&/g, "&amp;")
  .replace(/</g, "&lt;")
  .replace(/>/g, "&gt;")
  .replace(/\"/g, "&quot;");

const pushHealthSample = (key, ok) => {
  const arr = healthHistory.get(key) || [];
  arr.push(ok ? 1 : 0);
  while (arr.length > MAX_HEALTH_SAMPLES) arr.shift();
  healthHistory.set(key, arr);
};

const uptimePct = (key) => {
  const arr = healthHistory.get(key) || [];
  if (!arr.length) return 0;
  const up = arr.reduce((sum, v) => sum + v, 0);
  return Math.round((up / arr.length) * 100);
};

const uptimeClass = (pct) => {
  if (pct >= 95) return "ok";
  if (pct >= 80) return "warn";
  return "bad";
};

const renderServiceMatrix = (rows) => {
  if (!serviceMatrixBody) return;
  serviceMatrixBody.innerHTML = "";
  rows.forEach((row) => {
    const tr = document.createElement("tr");
    tr.tabIndex = 0;
    tr.setAttribute("role", "button");
    tr.setAttribute("aria-label", row.name + " open service page");
    const statusClass = row.ok ? "ok" : "bad";
    const upPct = uptimePct(row.key);
    tr.innerHTML =
      "<td>" + hEsc(row.name) + "</td>" +
      "<td><span class=\"service-state " + statusClass + "\">" + (row.ok ? "reachable" : "down") + "</span></td>" +
      "<td>" + hEsc(latencyLabel(row.latencyMs)) + "</td>" +
      "<td><span class=\"service-state " + uptimeClass(upPct) + "\">" + upPct + "%</span></td>" +
      "<td>" + hEsc(ts()) + "</td>" +
      "<td><a class=\"service-link\" href=\"" + hEsc(row.open) + "\" target=\"_blank\" rel=\"noopener\">Open</a></td>";

    tr.addEventListener("keydown", (ev) => {
      if (ev.key !== "Enter" && ev.key !== " ") return;
      ev.preventDefault();
      const link = tr.querySelector("a.service-link");
      if (link) link.click();
    });

    tr.addEventListener("dblclick", () => {
      const link = tr.querySelector("a.service-link");
      if (link) link.click();
    });

    serviceMatrixBody.appendChild(tr);
  });
};

const renderAlertFeed = (alerts) => {
  if (!alertFeedEl) return;
  alertFeedEl.innerHTML = "";
  if (!alerts.length) {
    const li = document.createElement("li");
    li.className = "ok";
    li.textContent = "No active alerts.";
    alertFeedEl.appendChild(li);
    return;
  }
  alerts.forEach((a) => {
    const li = document.createElement("li");
    li.className = a.severity;
    li.textContent = "[" + ts() + "] " + a.message;
    alertFeedEl.appendChild(li);
  });
};

const renderKpis = (alerts) => {
  if (!opsKpiGridEl) return;
  const serviceKeys = ["openclaw", "homeassistant", "pihole", "mosquitto"];
  const avgUptime = serviceKeys.length
    ? Math.round(serviceKeys.reduce((sum, key) => sum + uptimePct(key), 0) / serviceKeys.length)
    : 0;
  const scoreClass = avgUptime >= 95 ? "ok" : avgUptime >= 80 ? "warn" : "bad";
  const alertCount = alerts.filter((a) => a.severity !== "ok").length;
  const alertClass = alertCount === 0 ? "ok" : (alertCount <= 2 ? "warn" : "bad");
  const growboxClass = growboxStatus.alarm ? "bad" : (growboxStatus.ok ? "ok" : "warn");

  opsKpiGridEl.innerHTML =
    "<div class=\"kpi\"><div class=\"k\">Ops Score</div><div class=\"v " + scoreClass + "\">" + avgUptime + "%</div></div>" +
    "<div class=\"kpi\"><div class=\"k\">Active Alerts</div><div class=\"v " + alertClass + "\">" + alertCount + "</div></div>" +
    "<div class=\"kpi\"><div class=\"k\">Growbox</div><div class=\"v " + growboxClass + "\">" + (growboxStatus.alarm ? "ALARM" : (growboxStatus.ok ? "OK" : "WARN")) + "</div></div>";
};

const syncAutoRefreshUi = () => {
  if (btnAutoRefresh) btnAutoRefresh.textContent = autoRefreshEnabled ? "Pause Auto Refresh" : "Resume Auto Refresh";
  if (autoRefreshStateEl) autoRefreshStateEl.textContent = "Auto refresh: " + (autoRefreshEnabled ? "on" : "paused");
};

const resolveRagBase = async (host) => {
  const candidates = [
    "http://" + host + ":18789/api/rag",
    "http://" + host + ":18790/rag",
  ];
  for (const base of candidates) {
    try {
      const res = await fetchWithPolicy(base + "/status", { cache: "no-store" }, { timeoutMs: 2500, retries: 0 });
      if (res.ok) return base;
    } catch {}
  }
  return candidates[0];
};

let healthTimer;
let growboxTimer;
let healthInFlight = false;
let growboxInFlight = false;

const setMetricState = (el, valueText, stateClass) => {
  el.textContent = valueText;
  el.classList.remove("ok", "warn", "bad");
  if (stateClass) el.classList.add(stateClass);
};

const classifyRange = (value, min, max) => {
  if (Number.isNaN(value)) return "warn";
  if (value < min || value > max) return "bad";
  const margin = (max - min) * 0.1;
  if (value <= min + margin || value >= max - margin) return "warn";
  return "ok";
};

const classifyMaxOnly = (value, max) => {
  if (Number.isNaN(value)) return "warn";
  if (value > max) return "bad";
  if (value > max * 0.9) return "warn";
  return "ok";
};

const calcVpd = (tempC, relHumPct) => {
  if (Number.isNaN(tempC) || Number.isNaN(relHumPct)) return Number.NaN;
  const svp = 0.6108 * Math.exp((17.27 * tempC) / (tempC + 237.3));
  return svp * (1 - (relHumPct / 100));
};

const classifyAroundTarget = (value, target) => {
  if (Number.isNaN(value)) return "warn";
  const delta = Math.abs(value - target);
  if (delta <= 0.15) return "ok";
  if (delta <= 0.3) return "warn";
  return "bad";
};

const readHaNumericState = async (baseUrl, token, entityId) => {
  const res = await fetchWithPolicy(baseUrl + "/api/states/" + encodeURIComponent(entityId), {
    headers: {
      "Authorization": "Bearer " + token,
      "Content-Type": "application/json",
    },
    cache: "no-store",
  }, { timeoutMs: 5000, retries: 1 });
  if (!res.ok) throw new Error("HTTP " + res.status + " for " + entityId);
  const payload = await res.json();
  return Number.parseFloat(payload.state);
};

const readHaHistorySeries = async (baseUrl, token, entityId) => {
  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const url = baseUrl + "/api/history/period/" + encodeURIComponent(since) +
    "?filter_entity_id=" + encodeURIComponent(entityId) + "&minimal_response=1";
  const res = await fetchWithPolicy(url, {
    headers: {
      "Authorization": "Bearer " + token,
      "Content-Type": "application/json",
    },
    cache: "no-store",
  }, { timeoutMs: 7000, retries: 1 });
  if (!res.ok) throw new Error("HTTP " + res.status + " history " + entityId);
  const payload = await res.json();
  if (!Array.isArray(payload) || !Array.isArray(payload[0])) return [];
  return payload[0]
    .map((row) => Number.parseFloat(String(row.state || "").replace(",", ".")))
    .filter((n) => !Number.isNaN(n));
};

const svgEl = (tag) => document.createElementNS("http://www.w3.org/2000/svg", tag);

const renderChart = (svgEl, points, stroke, unit, opts = {}) => {
  if (!svgEl) return;
  const W = 180, H = 80;
  const padL = 30, padR = 6, padT = 8, padB = 14;
  const chartW = W - padL - padR;
  const chartH = H - padT - padB;
  svgEl.setAttribute("viewBox", "0 0 " + W + " " + H);
  svgEl.innerHTML = "";

  // Defs: gradient fill
  const defsEl = document.createElementNS("http://www.w3.org/2000/svg", "defs");
  const gradId = "cg-" + stroke.replace(/[^a-zA-Z0-9]/g, "") + "-" + (unit || "u");
  const grad = document.createElementNS("http://www.w3.org/2000/svg", "linearGradient");
  grad.setAttribute("id", gradId);
  grad.setAttribute("x1", "0"); grad.setAttribute("y1", "0");
  grad.setAttribute("x2", "0"); grad.setAttribute("y2", "1");
  const stop1 = document.createElementNS("http://www.w3.org/2000/svg", "stop");
  stop1.setAttribute("offset", "0%");
  stop1.setAttribute("stop-color", stroke);
  stop1.setAttribute("stop-opacity", "0.25");
  const stop2 = document.createElementNS("http://www.w3.org/2000/svg", "stop");
  stop2.setAttribute("offset", "100%");
  stop2.setAttribute("stop-color", stroke);
  stop2.setAttribute("stop-opacity", "0.02");
  grad.appendChild(stop1); grad.appendChild(stop2);
  defsEl.appendChild(grad);
  svgEl.appendChild(defsEl);

  // Background
  const bg = document.createElementNS("http://www.w3.org/2000/svg", "rect");
  bg.setAttribute("x", "0"); bg.setAttribute("y", "0");
  bg.setAttribute("width", String(W)); bg.setAttribute("height", String(H));
  bg.setAttribute("fill", "rgba(0,0,0,0.18)"); bg.setAttribute("rx", "6");
  svgEl.appendChild(bg);

  if (!points.length) {
    const empty = document.createElementNS("http://www.w3.org/2000/svg", "text");
    empty.setAttribute("x", String(W / 2)); empty.setAttribute("y", String(H / 2 + 4));
    empty.setAttribute("fill", "#9fb4bb"); empty.setAttribute("font-size", "9");
    empty.setAttribute("text-anchor", "middle");
    empty.textContent = "no data";
    svgEl.appendChild(empty);
    return;
  }

  const min = Math.min(...points);
  const max = Math.max(...points);
  const range = Math.max(max - min, 0.01);
  const cur = points[points.length - 1];

  const px = (i) => padL + (i / Math.max(points.length - 1, 1)) * chartW;
  const py = (v) => padT + chartH - ((v - min) / range) * chartH;

  // Grid line (mid)
  const midVal = (min + max) / 2;
  const midY = py(midVal);
  const grid = document.createElementNS("http://www.w3.org/2000/svg", "line");
  grid.setAttribute("x1", String(padL)); grid.setAttribute("x2", String(W - padR));
  grid.setAttribute("y1", String(midY)); grid.setAttribute("y2", String(midY));
  grid.setAttribute("stroke", "rgba(255,255,255,0.06)"); grid.setAttribute("stroke-dasharray", "2,3");
  svgEl.appendChild(grid);

  // Fill path
  const linePath = points.map((v, i) => (i === 0 ? "M" : "L") + px(i).toFixed(1) + " " + py(v).toFixed(1)).join(" ");
  const fillPath = linePath + " L" + px(points.length - 1).toFixed(1) + " " + (padT + chartH).toFixed(1) +
    " L" + padL.toFixed(1) + " " + (padT + chartH).toFixed(1) + " Z";

  const fill = document.createElementNS("http://www.w3.org/2000/svg", "path");
  fill.setAttribute("d", fillPath);
  fill.setAttribute("fill", "url(#" + gradId + ")");
  svgEl.appendChild(fill);

  // Line
  const line = document.createElementNS("http://www.w3.org/2000/svg", "path");
  line.setAttribute("d", linePath);
  line.setAttribute("fill", "none");
  line.setAttribute("stroke", stroke);
  line.setAttribute("stroke-width", "1.5");
  line.setAttribute("stroke-linejoin", "round");
  svgEl.appendChild(line);

  // Y-axis labels: max, min
  const mkLabel = (val, y, anchor) => {
    const t = document.createElementNS("http://www.w3.org/2000/svg", "text");
    t.setAttribute("x", String(padL - 3));
    t.setAttribute("y", String(y));
    t.setAttribute("fill", "#7a93a6");
    t.setAttribute("font-size", "8");
    t.setAttribute("text-anchor", "end");
    t.setAttribute("dominant-baseline", "middle");
    t.textContent = val.toFixed(opts.decimals != null ? opts.decimals : 1) + (unit ? unit : "");
    svgEl.appendChild(t);
  };
  mkLabel(max, padT + 4);
  mkLabel(min, padT + chartH - 2);

  // Current value dot
  const dotX = px(points.length - 1);
  const dotY = py(cur);
  const dot = document.createElementNS("http://www.w3.org/2000/svg", "circle");
  dot.setAttribute("cx", String(dotX)); dot.setAttribute("cy", String(dotY));
  dot.setAttribute("r", "2.5");
  dot.setAttribute("fill", stroke);
  svgEl.appendChild(dot);

  // Current value label
  const curLabel = document.createElementNS("http://www.w3.org/2000/svg", "text");
  const labelX = Math.min(dotX, W - padR - 24);
  curLabel.setAttribute("x", String(labelX));
  curLabel.setAttribute("y", String(Math.max(dotY - 4, padT + 6)));
  curLabel.setAttribute("fill", stroke);
  curLabel.setAttribute("font-size", "8");
  curLabel.setAttribute("font-weight", "600");
  curLabel.setAttribute("text-anchor", "end");
  curLabel.textContent = cur.toFixed(opts.decimals != null ? opts.decimals : 1) + (unit ? unit : "");
  svgEl.appendChild(curLabel);

  // X-axis: "24h" label on left, "now" on right
  const xLeft = document.createElementNS("http://www.w3.org/2000/svg", "text");
  xLeft.setAttribute("x", String(padL)); xLeft.setAttribute("y", String(H - 2));
  xLeft.setAttribute("fill", "#556677"); xLeft.setAttribute("font-size", "7");
  xLeft.textContent = "24h ago";
  svgEl.appendChild(xLeft);

  const xRight = document.createElementNS("http://www.w3.org/2000/svg", "text");
  xRight.setAttribute("x", String(W - padR)); xRight.setAttribute("y", String(H - 2));
  xRight.setAttribute("fill", "#556677"); xRight.setAttribute("font-size", "7");
  xRight.setAttribute("text-anchor", "end");
  xRight.textContent = "now";
  svgEl.appendChild(xRight);
};

// Keep old name as alias for compatibility
const renderSparkline = (svgEl, points, stroke) => renderChart(svgEl, points, stroke, "", { decimals: 1 });

const refreshGrowbox = async () => {
  if (growboxInFlight) return;
  growboxInFlight = true;
  try {
  const c = cfg();
  const token = String(c.haToken || "").trim();
  const baseUrl = String(c.haBaseUrl || "").replace(/\/$/, "");

  setLoading("growbox-state-chips", true);
  growboxChips.innerHTML = "";
  if (!token || !baseUrl) {
    growboxStatus = { ok: false, alarm: false, message: "token/url missing" };
    setLoading("growbox-state-chips", false);
    setMetricState(gTemp, "token/url missing", "warn");
    setMetricState(gHum, "token/url missing", "warn");
    setMetricState(gCo2, "token/url missing", "warn");
    setMetricState(gVpd, "token/url missing", "warn");
    setMetricState(gAlarm, "config needed", "warn");
    gRefresh.textContent = ts();
    growboxChips.appendChild(chip("Growbox", "configure HA token", "warn"));
  } else {
    try {
      const [temp, hum, co2] = await Promise.all([
        readHaNumericState(baseUrl, token, "sensor.growbox_temperatur"),
        readHaNumericState(baseUrl, token, "sensor.growbox_luftfeuchtigkeit"),
        readHaNumericState(baseUrl, token, c.growboxCo2Entity || "sensor.growbox_co2"),
      ]);
      const [tempHist, humHist] = await Promise.all([
        readHaHistorySeries(baseUrl, token, "sensor.growbox_temperatur"),
        readHaHistorySeries(baseUrl, token, "sensor.growbox_luftfeuchtigkeit"),
      ]);
      const tempClass = classifyRange(temp, c.tempMin, c.tempMax);
      const humClass = classifyRange(hum, c.humMin, c.humMax);
      const co2Class = classifyMaxOnly(co2, c.co2Max);
      const vpd = calcVpd(temp, hum);
      const vpdClass = classifyAroundTarget(vpd, c.vpd);

      const isAlarm = [tempClass, humClass, co2Class, vpdClass].includes("bad");
      const alarmClass = isAlarm ? "bad" : ([tempClass, humClass, co2Class, vpdClass].includes("warn") ? "warn" : "ok");

      setMetricState(gTemp, Number.isNaN(temp) ? "n/a" : temp.toFixed(1) + " °C", tempClass);
      setMetricState(gHum, Number.isNaN(hum) ? "n/a" : hum.toFixed(0) + " %", humClass);
      setMetricState(gCo2, Number.isNaN(co2) ? "n/a" : co2.toFixed(0) + " ppm", co2Class);
      setMetricState(gVpd, Number.isNaN(vpd) ? "n/a" : vpd.toFixed(2) + " kPa", vpdClass);
      setMetricState(gAlarm, isAlarm ? "ALARM" : (alarmClass === "warn" ? "WARN" : "OK"), alarmClass);
      renderChart(gTempSpark, tempHist, "#39d98a", "°C", { decimals: 1 });
      renderChart(gHumSpark, humHist, "#2dd4bf", "%", { decimals: 0 });

      growboxChips.appendChild(chip("Temperature", tempClass, tempClass));
      growboxChips.appendChild(chip("Humidity", humClass, humClass));
      growboxChips.appendChild(chip("CO₂", co2Class, co2Class));
      growboxChips.appendChild(chip("VPD", vpdClass, vpdClass));
      growboxChips.appendChild(chip("Alarm", isAlarm ? "active" : (alarmClass === "warn" ? "watch" : "none"), alarmClass));
      growboxStatus = { ok: true, alarm: isAlarm, message: isAlarm ? "alarm active" : "ok" };
    } catch (err) {
      growboxStatus = { ok: false, alarm: true, message: "HA unreachable" };
      setMetricState(gTemp, "error", "bad");
      setMetricState(gHum, "error", "bad");
      setMetricState(gCo2, "error", "bad");
      setMetricState(gVpd, "error", "bad");
      setMetricState(gAlarm, "ALARM", "bad");
      renderSparkline(gTempSpark, [], "#39d98a");
      renderSparkline(gHumSpark, [], "#2dd4bf");
      growboxChips.appendChild(chip("Growbox", "HA unreachable", "bad"));
      const errType = classifyFetchError(err);
      const errMsg = errType === "auth" ? "HA token invalid/missing" : errType === "timeout" ? "HA request timed out" : "HA unreachable – " + (err.message || "network error");
      showError(errType, "Growbox: " + errMsg);
      log("Growbox refresh failed: " + err.message);
    }
    gRefresh.textContent = ts();
    setLoading("growbox-state-chips", false);
  }

  clearInterval(growboxTimer);
  if (autoRefreshEnabled) {
    growboxTimer = setInterval(refreshGrowbox, (cfg().growboxRefreshInterval || 30) * 1000);
  }
  renderKpis(healthSnapshot.alerts || []);
  } finally {
    growboxInFlight = false;
  }
};

/* ── Dashboard Summary Snapshots ── */
let snapshots = { opsBrief: null, stateBrief: null };
let snapshotCacheTs = 0;
const SNAP_CACHE_MS = 60000;

const renderOpenWorkSnap = (opsBrief) => {
  dashOpenWorkSnapEl.innerHTML = "";
  const ops = opsBrief?.operations || {};
  const openWork = (ops.open_work?.items || []).slice(0, 3);
  if (!openWork.length) {
    dashOpenWorkSnapEl.innerHTML = "<div style=\"color:var(--muted);font-size:12px;text-align:center;padding:12px;\">No open work items.</div>";
    dashOpenWorkStatusEl.textContent = "No open work.";
    return;
  }
  openWork.forEach((item) => {
    const card = document.createElement("div");
    card.style.cssText = "border:1px solid var(--border);border-radius:9px;padding:9px 11px;background:rgba(0,0,0,0.2);font-size:12px;cursor:pointer;transition:background 120ms;";
    card.onmouseover = () => card.style.background = "rgba(45,212,191,0.08)";
    card.onmouseout = () => card.style.background = "rgba(0,0,0,0.2)";
    card.onclick = () => document.querySelector('[data-page=\"operations\"]')?.click();
    const prio = (item.priority && item.priority !== "OPEN") ? '<span style="color:var(--bad);font-weight:700;">P' + item.priority + '</span> ' : '';
    card.innerHTML = prio + (item.text || item.title || '(untitled)');
    dashOpenWorkSnapEl.appendChild(card);
  });
  dashOpenWorkStatusEl.textContent = "Open: " + (ops.open_work?.counts?.total || 0) + " items — View all in Operations tab";
};

const renderScoutSnap = (stateBrief) => {
  dashScoutSnapEl.innerHTML = "";
  const scout = stateBrief?.scout || {};
  const items = [
    { label: "Known", value: scout.known_total ?? 0 },
    { label: "Active", value: scout.active_count ?? 0, cls: scout.active_count > 0 ? "ok" : "" },
    { label: "Canary", value: scout.canary_count ?? 0, cls: scout.canary_count > 0 ? "warn" : "ok" },
    { label: "Pending Review", value: scout.pending_review ?? 0, cls: scout.pending_review > 0 ? "warn" : "" },
  ];
  items.forEach(({ label, value, cls }) => {
    const kpi = document.createElement("div");
    kpi.className = "kpi";
    const k = document.createElement("div");
    k.className = "k";
    k.textContent = label;
    const v = document.createElement("div");
    v.className = "v" + (cls ? " " + cls : "");
    v.textContent = String(value);
    kpi.appendChild(k);
    kpi.appendChild(v);
    dashScoutSnapEl.appendChild(kpi);
  });
  dashScoutStatusEl.textContent = "Last scout: " + (scout.last_scout_ts ? new Date(scout.last_scout_ts.length === 10 ? scout.last_scout_ts * 1000 : scout.last_scout_ts).toLocaleString() : "—");
};

const renderHealthSnap = (stateBrief) => {
  dashHealthSnapEl.innerHTML = "";
  const health = stateBrief?.health || {};
  const freeze = health.freeze || {};
  const items = [
    { label: "Freeze", value: freeze.enabled ? "ACTIVE" : "Off", cls: freeze.enabled ? "bad" : "ok" },
    { label: "Canaries", value: health.canary_total ?? 0 },
    { label: "High Risk", value: health.high_risk_count ?? 0, cls: health.high_risk_count > 0 ? "bad" : "ok" },
    { label: "Pending BL", value: health.pending_blacklist_count ?? 0, cls: health.pending_blacklist_count > 0 ? "bad" : "" },
  ];
  items.forEach(({ label, value, cls }) => {
    const kpi = document.createElement("div");
    kpi.className = "kpi";
    const k = document.createElement("div");
    k.className = "k";
    k.textContent = label;
    const v = document.createElement("div");
    v.className = "v" + (cls ? " " + cls : "");
    v.textContent = String(value);
    kpi.appendChild(k);
    kpi.appendChild(v);
    dashHealthSnapEl.appendChild(kpi);
  });
  dashHealthStatusEl.textContent = "View full analysis in Health and Scout tabs.";
};

const refreshSummarySnapshots = async () => {
  const now = Date.now();
  if (now - snapshotCacheTs < SNAP_CACHE_MS && snapshots.opsBrief && snapshots.stateBrief) return;
  
  try {
    const [obsRes, stateRes] = await Promise.all([
      fetchWithPolicy("/ops-brief.latest.json", { cache: "no-store" }, { timeoutMs: 4000, retries: 0 }).catch(() => null),
      fetchWithPolicy("/state-brief.latest.json", { cache: "no-store" }, { timeoutMs: 4000, retries: 0 }).catch(() => null),
    ]);
    
    if (obsRes?.ok) snapshots.opsBrief = await obsRes.json();
    if (stateRes?.ok) snapshots.stateBrief = await stateRes.json();
    snapshotCacheTs = Date.now();
    
    if (snapshots.opsBrief) renderOpenWorkSnap(snapshots.opsBrief);
    if (snapshots.stateBrief) {
      renderScoutSnap(snapshots.stateBrief);
      renderHealthSnap(snapshots.stateBrief);
    }
  } catch (err) {
    dashOpenWorkStatusEl.textContent = "Feed load error";
    dashScoutStatusEl.textContent = dashHealthStatusEl.textContent = "—";
  }
};

const refreshHealth = async () => {
  if (healthInFlight) return;
  healthInFlight = true;
  try {
  const c = cfg();
  const host = window.location.hostname || "192.168.2.101";
  const bridgeReady = hasHelper();
  const mobileSurface = isMobileSurface();
  const queued = queuedCount();
  const alerts = [];
  if (bridgeReady && queued > 0) flushQueuedActions();
  setLoading("health-chips", true);
  healthEl.innerHTML = "";
  if (mobileSurface) {
    healthEl.appendChild(chip("Bridge",  bridgeReady   ? "ready"  : "missing", bridgeReady   ? "ok" : "warn"));
    healthEl.appendChild(chip("iOS",     hasIOS()      ? "yes"    : "no",      hasIOS()      ? "ok" : ""));
    healthEl.appendChild(chip("Android", hasAndroid()  ? "yes"    : "no",      hasAndroid()  ? "ok" : ""));
    if (!bridgeReady) alerts.push({ severity: "warn", message: "Mobile bridge missing" });
  }
  if (queued > 0) {
    healthEl.appendChild(chip("Action Queue", String(queued), bridgeReady ? "warn" : "bad"));
    alerts.push({ severity: bridgeReady ? "warn" : "bad", message: "Queued mobile actions: " + queued });
  }

  const coreServices = buildCoreServices(c);
  const coreResults = await Promise.all(coreServices.map((svc) => probeServiceWithFallback(svc, host)));

  coreResults.forEach((row) => {
    pushHealthSample(row.key, row.ok);
    serviceSnapshot.set(row.key, row);
    healthEl.appendChild(chip(row.name, row.ok ? "reachable" : "down", row.ok ? "ok" : "bad"));
    if (!row.ok) alerts.push({ severity: "bad", message: row.name + " unreachable" });
  });

  const mqttHosts = (() => {
    const configured = String(c.mqttHost || "").trim();
    if (!/\.lan$/i.test(configured)) return [configured];
    return uniqueList([configured, ...hostCandidates(host)]);
  })();
  let mqttProbe = { ok: false, path: "", latencyMs: 0 };
  let mqttHostUsed = String(c.mqttHost || "");
  for (const mqttHostCandidate of mqttHosts) {
    mqttProbe = await probeMqttWs(mqttHostCandidate, c.mqttPort);
    if (mqttProbe.ok) {
      mqttHostUsed = mqttHostCandidate;
      break;
    }
  }
  healthEl.appendChild(chip("Mosquitto", mqttProbe.ok ? "reachable" : "down", mqttProbe.ok ? "ok" : "bad"));
  pushHealthSample("mosquitto", mqttProbe.ok);
  serviceSnapshot.set("mosquitto", {
    key: "mosquitto",
    name: "Mosquitto",
    ok: mqttProbe.ok,
    latencyMs: mqttProbe.latencyMs,
    open: mqttProbe.ok && mqttHostUsed !== c.mqttHost
      ? String(c.mosquittoOpenUrl || "").replace(String(c.mqttHost || ""), mqttHostUsed)
      : c.mosquittoOpenUrl,
  });
  if (!mqttProbe.ok) alerts.push({ severity: "bad", message: "Mosquitto websocket probe failed" });

  if (c.haToken && c.haBaseUrl) {
    try {
      const piTemp = await readHaNumericState(String(c.haBaseUrl).replace(/\/$/, ""), String(c.haToken), c.piTempEntity || "sensor.raspberry_pi_cpu_temperature");
      const cls = Number.isNaN(piTemp) ? "warn" : (piTemp >= 80 ? "bad" : (piTemp >= 70 ? "warn" : "ok"));
      setMetricState(mPiTemp, Number.isNaN(piTemp) ? "n/a" : piTemp.toFixed(1) + " °C", cls);
      if (cls === "bad") alerts.push({ severity: "bad", message: "Pi temperature critical" });
      else if (cls === "warn") alerts.push({ severity: "warn", message: "Pi temperature elevated" });
    } catch {
      setMetricState(mPiTemp, "n/a", "warn");
      alerts.push({ severity: "warn", message: "Pi temperature sensor unavailable" });
    }
  } else {
    setMetricState(mPiTemp, "token missing", "warn");
  }

  if (!growboxStatus.ok) {
    alerts.push({ severity: growboxStatus.alarm ? "bad" : "warn", message: "Growbox: " + growboxStatus.message });
  } else if (growboxStatus.alarm) {
    alerts.push({ severity: "bad", message: "Growbox alarm active" });
  }

  const rows = [
    ...coreResults,
    {
      key: "mosquitto",
      name: "Mosquitto",
      ok: mqttProbe.ok,
      latencyMs: mqttProbe.latencyMs,
      open: c.mosquittoOpenUrl,
    },
  ];
  renderServiceMatrix(rows);
  renderAlertFeed(alerts);
  renderKpis(alerts);

  mBridge.textContent = mobileSurface ? (bridgeReady ? "ready" : "missing") : "desktop";
  if (queued > 0) mBridge.textContent += " (" + queued + " queued)";
  mLastUpdate.textContent = ts();
  dashUpdated.textContent = "Updated " + ts();

  healthSnapshot = {
    ts: new Date().toISOString(),
    services: rows,
    alerts,
    growbox: { ...growboxStatus },
  };

  clearInterval(healthTimer);
  if (autoRefreshEnabled) {
    healthTimer = setInterval(refreshHealth, (cfg().healthInterval || 30) * 1000);
  }
  } finally {
    setLoading("health-chips", false);
    healthInFlight = false;
  }
};

const sendWithRetry = (name, sourceComponentId, maxRetries = 2) => {
  if (!hasHelper()) {
    log("No action bridge found. Open this page from an OpenClaw mobile node.");
    enqueueAction(name, sourceComponentId, "bridge missing");
    mLastResult.textContent = "queued";
    mLastUpdate.textContent = ts();
    return;
  }
  const payload = { name, surfaceId: "main", sourceComponentId, context: { t: Date.now() } };
  const attempt = trySendActionPayload(payload, maxRetries);
  const ok = attempt.ok;
  const tryCount = attempt.tries;
  mLastAction.textContent = name;
  mLastResult.textContent = ok ? "sent" : "queued";
  mLastUpdate.textContent = ts();
  if (ok) {
    log("Sent action: " + name + " (attempt " + tryCount + ")");
    addTimeline("Action sent: " + name, "ok");
    const flushed = flushQueuedActions();
    if (flushed.sent > 0) mLastResult.textContent = "sent + synced " + flushed.sent;
  } else {
    log("Failed to send live action, queued: " + name);
    enqueueAction(name, sourceComponentId, "send failed");
  }
};

const titleCase = (s) => s.slice(0, 1).toUpperCase() + s.slice(1);
const actionLabel = (name) => {
  const map = { hello: "Hello", time: "Time", photo: "Photo", dalek: "Dalek" };
  return map[name] || titleCase(name.replace(/[_-]+/g, " "));
};

const renderActionButtons = (actions) => {
  if (!actionButtonsEl) return;
  actionButtonsEl.innerHTML = "";
  const usable = sanitizeActions(actions);
  usable.forEach((name) => {
    const btn = document.createElement("button");
    btn.textContent = actionLabel(name);
    btn.setAttribute("aria-label", "Send " + actionLabel(name) + " action");
    btn.addEventListener("click", () => sendWithRetry(name, "ops." + name));
    actionButtonsEl.appendChild(btn);
  });
  const refreshBtn = document.createElement("button");
  refreshBtn.textContent = "Refresh Health";
  refreshBtn.setAttribute("aria-label", "Refresh health checks");
  refreshBtn.addEventListener("click", async () => {
    await refreshHealth();
    await refreshGrowbox();
  });
  actionButtonsEl.appendChild(refreshBtn);
};

const loadDynamicActions = async () => {
  const c = cfg();
  const fallback = c.actions || DEFAULTS.actions;
  try {
    const res = await fetchWithPolicy(
      String(c.openclawBaseUrl || DEFAULTS.openclawBaseUrl).replace(/\/$/, "") + "/api/actions",
      { cache: "no-store" },
      { timeoutMs: 3500, retries: 1 }
    );
    if (!res.ok) throw new Error("HTTP " + res.status);
    const payload = await res.json();
    const listRaw = Array.isArray(payload)
      ? payload
      : Array.isArray(payload.actions)
        ? payload.actions.map((row) => (typeof row === "string" ? row : row?.name))
        : [];
    const nextActions = sanitizeActions(listRaw);
    saveCfg({ ...c, actions: nextActions });
    renderActionButtons(nextActions);
  } catch {
    renderActionButtons(fallback);
  }
};

window.addEventListener("openclaw:a2ui-action-status", (ev) => {
  const d = (ev?.detail) || {};
  const ok = !!d.ok;
  mLastResult.textContent = ok ? "ok" : "failed";
  mLastUpdate.textContent = ts();
  log("Action status: id=" + (d.id||"?") + " ok=" + ok + (d.error ? " error=" + d.error : ""));
  addTimeline("Status id=" + (d.id||"?") + " -> " + (ok ? "ok" : "failed"), ok ? "ok" : "bad");
});

renderActionButtons(cfg().actions || DEFAULTS.actions);
loadDynamicActions();

if (btnRefreshAll) {
  btnRefreshAll.addEventListener("click", async () => {
    await refreshHealth();
    await refreshGrowbox();
  });
}

if (btnAutoRefresh) {
  btnAutoRefresh.addEventListener("click", async () => {
    autoRefreshEnabled = !autoRefreshEnabled;
    syncAutoRefreshUi();
    if (!autoRefreshEnabled) {
      clearInterval(healthTimer);
      clearInterval(growboxTimer);
      addTimeline("Auto refresh paused", "warn");
    } else {
      addTimeline("Auto refresh resumed", "ok");
      await refreshHealth();
      await refreshGrowbox();
    }
  });
}

if (btnExportSnapshot) {
  btnExportSnapshot.addEventListener("click", () => {
    try {
      const payload = JSON.stringify(healthSnapshot, null, 2);
      const blob = new Blob([payload], { type: "application/json" });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = "openclaw-dashboard-snapshot-" + Date.now() + ".json";
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(url);
      addTimeline("Dashboard snapshot exported", "ok");
    } catch (err) {
      addTimeline("Snapshot export failed", "bad");
      log("Snapshot export failed: " + (err.message || err));
    }
  });
}

syncAutoRefreshUi();

setInterval(() => {
  const flushed = flushQueuedActions();
  if (flushed.sent > 0) {
    mLastResult.textContent = "synced " + flushed.sent;
    mLastUpdate.textContent = ts();
  }
}, 12000);

document.addEventListener("visibilitychange", () => {
  if (!document.hidden) flushQueuedActions();
});

window.addEventListener("focus", () => {
  flushQueuedActions();
});

addTimeline("Canvas initialized", "ok");
refreshHealth();
refreshGrowbox();
refreshSummarySnapshots();

setInterval(refreshSummarySnapshots, 120000);

    return { refreshHealth, refreshGrowbox, addTimeline, renderQuickLinks, flushQueuedActions, resolveRagBase };
  }
};
