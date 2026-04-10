/* ─── app-config.js — Canvas Config / Storage ─── */
/* Exposes window.CanvasConfig für app-main.js und andere Module. */
(() => {
  const STORAGE_PREFIX = "oc.canvas.v2";
  const STORAGE_KEYS = {
    cfg: STORAGE_PREFIX + ".cfg",
    chat: STORAGE_PREFIX + ".chat-history",
  };

  const DEFAULTS = {
    tempMin: 20, tempMax: 28, humMin: 50, humMax: 75,
    co2Max: 1500, vpd: 0.9, growPhase: "bloom",
    darkMode: true,
    actions: ["hello", "time", "photo", "dalek"],
    healthInterval: 30,
    growboxRefreshInterval: 30,
    openclawBaseUrl: "http://openclaw.lan",
    haBaseUrl: "http://ha.lan",
    piholeBaseUrl: "http://pihole.lan/admin",
    haToken: "",
    growboxCo2Entity: "sensor.growbox_co2",
    piTempEntity: "sensor.raspberry_pi_cpu_temperature",
    mqttHost: "mqtt.lan",
    mqttPort: 80,
    mosquittoOpenUrl: "http://mqtt.lan",
    mqttUsername: "",
    mqttPassword: "",
    quickLinks: [
      { label: "OpenClaw API", url: "http://openclaw.lan" },
      { label: "Home Assistant", url: "http://ha.lan" },
      { label: "Portainer", url: "http://portainer.lan" },
      { label: "Pi-hole", url: "http://pihole.lan/admin" },
      { label: "Uptime Kuma", url: "http://uptime.lan" },
      { label: "Homepage", url: "http://dashboard.lan" },
      { label: "Grafana", url: "http://grafana.lan" },
    ],
  };

  const clampInt = (value, min, max, fallback) => {
    const n = Number.parseInt(value, 10);
    if (Number.isNaN(n)) return fallback;
    return Math.min(max, Math.max(min, n));
  };

  const clampFloat = (value, min, max, fallback) => {
    const n = Number.parseFloat(value);
    if (Number.isNaN(n)) return fallback;
    return Math.min(max, Math.max(min, n));
  };

  const sanitizeHttpUrl = (raw) => {
    const value = String(raw || "").trim();
    if (!value) return "";
    try {
      const u = new URL(value);
      if (u.protocol !== "http:" && u.protocol !== "https:") return "";
      u.search = "";
      u.hash = "";
      u.username = "";
      u.password = "";
      return u.toString().replace(/\/$/, "");
    } catch {
      return "";
    }
  };

  const sanitizeHaUrl = sanitizeHttpUrl;

  const sanitizeMqttHost = (raw) => {
    const value = String(raw || "").trim().toLowerCase();
    if (!value) return "";
    if (value.length > 253) return "";
    if (!/^[a-z0-9.-]+$/.test(value)) return "";
    if (value.startsWith(".") || value.endsWith(".")) return "";
    if (value.includes("..")) return "";
    return value;
  };

  const PHASE_PRESETS = {
    seedling: { tempMin: 22, tempMax: 28, humMin: 70, humMax: 80, co2Max: 1200, vpd: 0.6 },
    veg:      { tempMin: 22, tempMax: 28, humMin: 50, humMax: 70, co2Max: 1500, vpd: 1.0 },
    bloom:    { tempMin: 20, tempMax: 26, humMin: 40, humMax: 55, co2Max: 1500, vpd: 1.25 },
    flush:    { tempMin: 18, tempMax: 24, humMin: 35, humMax: 45, co2Max: 1200, vpd: 1.4 },
  };

  const sanitizeActions = (raw) => {
    if (!Array.isArray(raw)) return [...DEFAULTS.actions];
    const actions = raw
      .map((v) => String(v || "").trim().toLowerCase())
      .filter((v) => /^[a-z0-9_-]{2,24}$/.test(v));
    return actions.length ? Array.from(new Set(actions)).slice(0, 12) : [...DEFAULTS.actions];
  };

  const sanitizeQuickLinks = (raw) => {
    const normalize = (label, url) => {
      const cleanLabel = String(label || "").trim().slice(0, 40);
      if (!cleanLabel) return null;
      try {
        const u = new URL(String(url || "").trim());
        if (u.protocol !== "http:" && u.protocol !== "https:") return null;
        return { label: cleanLabel, url: u.toString() };
      } catch {
        return null;
      }
    };

    let rows = [];
    if (typeof raw === "string") {
      rows = raw.split(/\r?\n/)
        .map((line) => line.trim())
        .filter(Boolean)
        .map((line) => {
          const idx = line.indexOf("|");
          if (idx < 1) return null;
          return normalize(line.slice(0, idx), line.slice(idx + 1));
        })
        .filter(Boolean);
    } else if (Array.isArray(raw)) {
      rows = raw
        .map((row) => normalize(row?.label, row?.url))
        .filter(Boolean);
    }

    return rows.length ? rows.slice(0, 12) : [...DEFAULTS.quickLinks];
  };

  const quickLinksToText = (links) =>
    sanitizeQuickLinks(links)
      .map((row) => row.label + "|" + row.url)
      .join("\n");

  const sanitizeCfg = (raw) => ({
    tempMin: clampFloat(raw.tempMin, 5, 60, DEFAULTS.tempMin),
    tempMax: clampFloat(raw.tempMax, 5, 60, DEFAULTS.tempMax),
    humMin: clampFloat(raw.humMin, 0, 100, DEFAULTS.humMin),
    humMax: clampFloat(raw.humMax, 0, 100, DEFAULTS.humMax),
    co2Max: clampFloat(raw.co2Max, 300, 10000, DEFAULTS.co2Max),
    vpd: clampFloat(raw.vpd, 0, 5, DEFAULTS.vpd),
    growPhase: ["seedling","veg","bloom","flush"].includes(raw.growPhase) ? raw.growPhase : DEFAULTS.growPhase,
    darkMode: typeof raw.darkMode === "boolean" ? raw.darkMode : DEFAULTS.darkMode,
    actions: sanitizeActions(raw.actions),
    healthInterval: clampInt(raw.healthInterval, 5, 300, DEFAULTS.healthInterval),
    growboxRefreshInterval: clampInt(raw.growboxRefreshInterval, 10, 300, DEFAULTS.growboxRefreshInterval),
    openclawBaseUrl: sanitizeHttpUrl(raw.openclawBaseUrl) || DEFAULTS.openclawBaseUrl,
    haBaseUrl: sanitizeHaUrl(raw.haBaseUrl) || DEFAULTS.haBaseUrl,
    piholeBaseUrl: sanitizeHttpUrl(raw.piholeBaseUrl) || DEFAULTS.piholeBaseUrl,
    haToken: String(raw.haToken || "").trim(),
    growboxCo2Entity: String(raw.growboxCo2Entity || DEFAULTS.growboxCo2Entity).trim(),
    piTempEntity: String(raw.piTempEntity || DEFAULTS.piTempEntity).trim(),
    mqttHost: sanitizeMqttHost(raw.mqttHost) || DEFAULTS.mqttHost,
    mqttPort: clampInt(raw.mqttPort, 1, 65535, DEFAULTS.mqttPort),
    mosquittoOpenUrl: sanitizeHttpUrl(raw.mosquittoOpenUrl) || DEFAULTS.mosquittoOpenUrl,
    mqttUsername: String(raw.mqttUsername || "").trim(),
    mqttPassword: String(raw.mqttPassword || ""),
    quickLinks: sanitizeQuickLinks(raw.quickLinks),
  });

  const MIGRATION_FLAG = STORAGE_PREFIX + ".migrated-v2";
  if (!localStorage.getItem(MIGRATION_FLAG)) {
    if (!localStorage.getItem(STORAGE_KEYS.cfg)) {
      const legacyCfg = localStorage.getItem("oc-canvas-cfg");
      if (legacyCfg) localStorage.setItem(STORAGE_KEYS.cfg, legacyCfg);
    }
    if (!localStorage.getItem(STORAGE_KEYS.chat)) {
      const legacyChat = localStorage.getItem("oc-chat-history");
      if (legacyChat) localStorage.setItem(STORAGE_KEYS.chat, legacyChat);
    }
    localStorage.setItem(MIGRATION_FLAG, "1");
  }

  const cfg = () => {
    try { return sanitizeCfg({ ...DEFAULTS, ...JSON.parse(localStorage.getItem(STORAGE_KEYS.cfg) || "{}") }); }
    catch { return { ...DEFAULTS }; }
  };
  const saveCfg = (c) => localStorage.setItem(STORAGE_KEYS.cfg, JSON.stringify(sanitizeCfg(c)));
  const chatHistory = () => {
    try { return JSON.parse(localStorage.getItem(STORAGE_KEYS.chat) || "[]"); }
    catch { return []; }
  };
  const saveChat = (h) => localStorage.setItem(STORAGE_KEYS.chat, JSON.stringify(h.slice(-60)));

  const applyTheme = (isDarkMode) => {
    document.body.classList.toggle("light-mode", !isDarkMode);
  };

  applyTheme(cfg().darkMode);

  window.CanvasConfig = {
    STORAGE_KEYS,
    DEFAULTS,
    PHASE_PRESETS,
    clampInt,
    clampFloat,
    sanitizeHttpUrl,
    sanitizeHaUrl,
    sanitizeMqttHost,
    sanitizeActions,
    sanitizeQuickLinks,
    quickLinksToText,
    sanitizeCfg,
    cfg,
    saveCfg,
    chatHistory,
    saveChat,
    applyTheme,
  };
})();
