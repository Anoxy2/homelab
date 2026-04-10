/* ─── app-settings.js — Canvas Settings ─── */
/* Exposes window.CanvasSettings. Initialisierung via .init(deps). */
window.CanvasSettings = {
  init: ({ ts, getDash }) => {
    const {
      cfg, saveCfg, DEFAULTS, PHASE_PRESETS,
      sanitizeCfg, sanitizeHttpUrl, sanitizeHaUrl, sanitizeMqttHost,
      applyTheme, quickLinksToText, sanitizeQuickLinks,
    } = window.CanvasConfig;

/* ════════════════ SETTINGS ════════════════ */
const settingsStatusEl = document.getElementById("settings-save-status");

const loadSettingsForm = () => {
  const c = cfg();
  document.getElementById("set-grow-phase").value     = c.growPhase;
  document.getElementById("set-dark-mode").checked    = !!c.darkMode;
  document.getElementById("set-temp-min").value       = c.tempMin;
  document.getElementById("set-temp-max").value       = c.tempMax;
  document.getElementById("set-hum-min").value        = c.humMin;
  document.getElementById("set-hum-max").value        = c.humMax;
  document.getElementById("set-co2-max").value        = c.co2Max;
  document.getElementById("set-vpd").value            = c.vpd;
  document.getElementById("set-health-interval").value= c.healthInterval;
  document.getElementById("set-growbox-refresh").value= c.growboxRefreshInterval;
  document.getElementById("set-openclaw-url").value   = c.openclawBaseUrl;
  document.getElementById("set-ha-url").value         = c.haBaseUrl;
  document.getElementById("set-pihole-url").value     = c.piholeBaseUrl;
  document.getElementById("set-ha-token").value       = c.haToken || "";
  document.getElementById("set-mqtt-host").value      = c.mqttHost;
  document.getElementById("set-mqtt-port").value      = c.mqttPort;
  document.getElementById("set-mqtt-open-url").value  = c.mosquittoOpenUrl;
  document.getElementById("set-mqtt-user").value      = c.mqttUsername || "";
  document.getElementById("set-mqtt-pass").value      = c.mqttPassword || "";
  document.getElementById("set-quick-links").value    = quickLinksToText(c.quickLinks);
};

document.getElementById("btn-settings-save").addEventListener("click", () => {
  const current = cfg();
  const rawOpenClawUrl = document.getElementById("set-openclaw-url").value;
  const rawHaUrl = document.getElementById("set-ha-url").value;
  const rawPiholeUrl = document.getElementById("set-pihole-url").value;
  const rawMqttHost = document.getElementById("set-mqtt-host").value;
  const rawMqttOpenUrl = document.getElementById("set-mqtt-open-url").value;
  const cleanOpenClawUrl = sanitizeHttpUrl(rawOpenClawUrl);
  const cleanHaUrl = sanitizeHaUrl(rawHaUrl);
  const cleanPiholeUrl = sanitizeHttpUrl(rawPiholeUrl);
  const cleanMqttHost = sanitizeMqttHost(rawMqttHost);
  const cleanMqttOpenUrl = sanitizeHttpUrl(rawMqttOpenUrl);

  if (String(rawOpenClawUrl || "").trim() && !cleanOpenClawUrl) {
    settingsStatusEl.textContent = "Save blocked: invalid OpenClaw URL (allowed: http/https, no querystring).";
    return;
  }

  if (String(rawHaUrl || "").trim() && !cleanHaUrl) {
    settingsStatusEl.textContent = "Save blocked: invalid Home Assistant URL (allowed: http/https, no querystring).";
    return;
  }
  if (String(rawPiholeUrl || "").trim() && !cleanPiholeUrl) {
    settingsStatusEl.textContent = "Save blocked: invalid Pi-hole URL (allowed: http/https, no querystring).";
    return;
  }
  if (String(rawMqttHost || "").trim() && !cleanMqttHost) {
    settingsStatusEl.textContent = "Save blocked: invalid MQTT host (allowed: letters, digits, dot, dash).";
    return;
  }
  if (String(rawMqttOpenUrl || "").trim() && !cleanMqttOpenUrl) {
    settingsStatusEl.textContent = "Save blocked: invalid Mosquitto UI URL (allowed: http/https, no querystring).";
    return;
  }

  const next = sanitizeCfg({
    ...current,
    growPhase: document.getElementById("set-grow-phase").value,
    darkMode: document.getElementById("set-dark-mode").checked,
    tempMin: document.getElementById("set-temp-min").value,
    tempMax: document.getElementById("set-temp-max").value,
    humMin: document.getElementById("set-hum-min").value,
    humMax: document.getElementById("set-hum-max").value,
    co2Max: document.getElementById("set-co2-max").value,
    vpd: document.getElementById("set-vpd").value,
    healthInterval: document.getElementById("set-health-interval").value,
    growboxRefreshInterval: document.getElementById("set-growbox-refresh").value,
    openclawBaseUrl: cleanOpenClawUrl || current.openclawBaseUrl,
    haBaseUrl: cleanHaUrl || current.haBaseUrl,
    piholeBaseUrl: cleanPiholeUrl || current.piholeBaseUrl,
    haToken: document.getElementById("set-ha-token").value,
    mqttHost: cleanMqttHost || current.mqttHost,
    mqttPort: document.getElementById("set-mqtt-port").value,
    mosquittoOpenUrl: cleanMqttOpenUrl || current.mosquittoOpenUrl,
    mqttUsername: document.getElementById("set-mqtt-user").value,
    mqttPassword: document.getElementById("set-mqtt-pass").value,
    quickLinks: document.getElementById("set-quick-links").value,
  });

  saveCfg(next);
applyTheme(next.darkMode);
  getDash()?.renderQuickLinks(next.quickLinks);
  loadSettingsForm();
  settingsStatusEl.textContent = "Saved at " + ts();

  getDash()?.refreshHealth();
  getDash()?.refreshGrowbox();
});

document.getElementById("btn-settings-reset").addEventListener("click", () => {
  const next = { ...cfg(), haToken: "", mqttUsername: "", mqttPassword: "" };
  saveCfg(next);
  loadSettingsForm();
  settingsStatusEl.textContent = "Local credentials cleared at " + ts();
});

document.getElementById("btn-load-phase").addEventListener("click", () => {
  const phase = document.getElementById("set-grow-phase").value;
  const preset = PHASE_PRESETS[phase];
  if (!preset) return;
  document.getElementById("set-temp-min").value = preset.tempMin;
  document.getElementById("set-temp-max").value = preset.tempMax;
  document.getElementById("set-hum-min").value  = preset.humMin;
  document.getElementById("set-hum-max").value  = preset.humMax;
  document.getElementById("set-co2-max").value  = preset.co2Max;
  document.getElementById("set-vpd").value      = preset.vpd;
  settingsStatusEl.textContent = "Loaded " + phase + " presets — click Save to apply.";
});

document.getElementById("btn-quick-links-defaults").addEventListener("click", () => {
  document.getElementById("set-quick-links").value = quickLinksToText(DEFAULTS.quickLinks);
  settingsStatusEl.textContent = "Default quick links loaded — click Save to apply.";
});


    window.CanvasSettings.loadSettingsForm = loadSettingsForm;
    return { loadSettingsForm };
  }
};
