/* --- app-skill.js - Canvas Scout / Health / Metrics --- */
window.CanvasSkill = (() => {
  let deps = null;
  let pageInitialized = false;
  let cache = null;
  let cacheTs = 0;
  const FEED_URL = "/state-brief.latest.json";
  const FEED_CACHE_MS = 30000;

  const register = ({ ts, showError, setLoading }) => {
    deps = { ts, showError, setLoading };
  };

  const initPage = () => {
    if (!deps || pageInitialized) return;
    pageInitialized = true;
    initSkillPages(deps);
  };

  /* --- tiny helpers ------------------------------------------------- */
  const esc = (s) => String(s == null ? "" : s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");

  const fmtTs = (ts) => {
    if (!ts) return "—";
    const d = new Date(ts.length === 10 ? Number(ts) * 1000 : ts);
    return isNaN(d) ? ts : d.toLocaleString();
  };

  const fmtPct = (v) => (v == null ? "—" : v.toFixed(1) + "%");

  const stateClass = (ok, warn, val) =>
    val >= warn ? "bad" : val >= ok ? "warn" : "ok";

  const renderKpis = (el, items) => {
    el.innerHTML = "";
    items.forEach(({ label, value, cls }) => {
      const card = document.createElement("div");
      card.className = "kpi";
      const k = document.createElement("div");
      k.className = "k";
      k.textContent = label;
      const v = document.createElement("div");
      v.className = "v" + (cls ? " " + cls : "");
      v.textContent = String(value == null ? "—" : value);
      card.appendChild(k);
      card.appendChild(v);
      el.appendChild(card);
    });
  };

  const renderSimpleTable = (el, headers, rows) => {
    el.innerHTML = "";
    if (!rows.length) {
      el.innerHTML = "<tr><td colspan=\"" + headers.length + "\" class=\"skill-empty\">Keine Eintraege verfuegbar.</td></tr>";
      return;
    }
    rows.forEach((cells) => {
      const tr = document.createElement("tr");
      cells.forEach((cell, i) => {
        const td = document.createElement("td");
        if (typeof cell === "object" && cell !== null) {
          const span = document.createElement("span");
          span.className = "st " + (cell.cls || "");
          span.textContent = cell.text;
          td.appendChild(span);
        } else {
          td.textContent = cell == null ? "—" : cell;
        }
        tr.appendChild(td);
      });
      el.appendChild(tr);
    });
  };

  /* --- SVG sparkline ------------------------------------------------ */
  const makeSpark = (svgEl, series, opts = {}) => {
    const {
      color = "rgba(45,212,191,0.8)",
      fillColor = "rgba(45,212,191,0.12)",
      badColor = "rgba(255,107,107,0.8)",
      badThreshold = null,
      label = "",
    } = opts;
    if (!series || !series.length) { svgEl.innerHTML = ""; return; }
    const W = 360, H = 60, pad = 4;
    const max = Math.max(...series, 1);
    const min = 0;
    const range = max - min || 1;
    const pts = series.map((v, i) => {
      const x = pad + i * (W - 2 * pad) / Math.max(series.length - 1, 1);
      const y = H - pad - ((v - min) / range) * (H - 2 * pad);
      return [x, y];
    });

    svgEl.setAttribute("viewBox", "0 0 " + W + " " + H);
    svgEl.setAttribute("preserveAspectRatio", "none");
    svgEl.innerHTML = "";

    // fill
    const fillPath = document.createElementNS("http://www.w3.org/2000/svg", "path");
    const bottom = H - pad;
    let d = "M " + pts[0][0] + " " + bottom + " L " + pts[0][0] + " " + pts[0][1];
    for (let i = 1; i < pts.length; i++) d += " L " + pts[i][0] + " " + pts[i][1];
    d += " L " + pts[pts.length - 1][0] + " " + bottom + " Z";
    fillPath.setAttribute("d", d);
    fillPath.setAttribute("fill", fillColor);
    svgEl.appendChild(fillPath);

    // line
    const linePath = document.createElementNS("http://www.w3.org/2000/svg", "path");
    let ld = "M " + pts[0][0] + " " + pts[0][1];
    for (let i = 1; i < pts.length; i++) ld += " L " + pts[i][0] + " " + pts[i][1];
    linePath.setAttribute("d", ld);
    linePath.setAttribute("fill", "none");
    linePath.setAttribute("stroke", color);
    linePath.setAttribute("stroke-width", "1.5");
    svgEl.appendChild(linePath);

    // last value dot
    const last = pts[pts.length - 1];
    const dot = document.createElementNS("http://www.w3.org/2000/svg", "circle");
    dot.setAttribute("cx", last[0]);
    dot.setAttribute("cy", last[1]);
    dot.setAttribute("r", "3");
    const dotColor = (badThreshold !== null && series[series.length - 1] >= badThreshold) ? badColor : color;
    dot.setAttribute("fill", dotColor);
    svgEl.appendChild(dot);

    // label
    if (label) {
      const txt = document.createElementNS("http://www.w3.org/2000/svg", "text");
      txt.setAttribute("x", "4");
      txt.setAttribute("y", "12");
      txt.setAttribute("font-size", "9");
      txt.setAttribute("fill", "rgba(168,179,198,0.8)");
      txt.textContent = label;
      svgEl.appendChild(txt);
    }
  };

  /* --- status badge ------------------------------------------------- */
  const statusBadge = (status) => {
    const map = {
      canary: "st-canary",
      active: "st-ok",
      "pending-review": "st-warn",
      "pending-blacklist": "st-bad",
      rollback: "st-bad",
      vetted: "st-ok",
      reviewed: "st-ok",
      running: "st-canary",
      promoted: "st-ok",
    };
    return { text: status || "unknown", cls: map[status] || "" };
  };

  /* === SCOUT ========================================================= */
  const renderScout = (payload) => {
    const scout = payload.scout || {};
    const skills = scout.skills || [];
    const sc = scout.status_counts || {};

    renderKpis(document.getElementById("scout-kpis"), [
      { label: "Known", value: scout.known_total ?? 0 },
      { label: "Active", value: scout.active_count ?? 0, cls: "ok" },
      { label: "Canary", value: scout.canary_count ?? 0, cls: scout.canary_count > 0 ? "warn" : "ok" },
      { label: "Pending Review", value: scout.pending_review ?? 0, cls: scout.pending_review > 0 ? "warn" : "ok" },
      { label: "Pending Blacklist", value: scout.pending_blacklist_count ?? 0, cls: scout.pending_blacklist_count > 0 ? "bad" : "ok" },
    ]);

    const tbody = document.getElementById("scout-table-body");
    renderSimpleTable(tbody, [], skills.map((s) => [
      s.slug,
      { text: s.source || "unknown", cls: "" },
      statusBadge(s.status),
      s.version || "—",
      fmtTs(s.last_scout),
      s.scout_score != null ? s.scout_score.toFixed(2) : "—",
    ]));

    const foot = document.getElementById("scout-status");
    if (foot) foot.textContent = "Last scout: " + (scout.last_scout_ts ? fmtTs(scout.last_scout_ts) : "unknown") + " — Feed: " + (payload.updated_at || "");
  };

  /* === HEALTH ======================================================== */
  const renderHealth = (payload) => {
    const health = payload.health || {};
    const freeze = health.freeze || {};
    const canaries = health.canaries || [];
    const highRisk = health.high_risk_skills || [];

    renderKpis(document.getElementById("health-kpis"), [
      {
        label: "Freeze",
        value: freeze.enabled ? "ACTIVE" : "off",
        cls: freeze.enabled ? "bad" : "ok",
      },
      { label: "Canaries", value: health.canary_total ?? 0 },
      { label: "Running", value: health.canary_running ?? 0, cls: (health.canary_running ?? 0) > 0 ? "warn" : "ok" },
      { label: "Promoted", value: health.canary_promoted ?? 0, cls: "ok" },
      { label: "High Risk", value: health.high_risk_count ?? 0, cls: health.high_risk_count > 0 ? "bad" : "ok" },
      { label: "Pending BL", value: health.pending_blacklist_count ?? 0, cls: health.pending_blacklist_count > 0 ? "bad" : "ok" },
    ]);

    // freeze block
    const freezeEl = document.getElementById("health-freeze-info");
    if (freezeEl) {
      if (freeze.enabled) {
        freezeEl.className = "skill-block skill-block-bad";
        freezeEl.textContent = "FREEZE ACTIVE — " + (freeze.reason || "no reason given") + " (since " + fmtTs(freeze.changed_at) + ")";
      } else {
        freezeEl.className = "skill-block skill-block-ok";
        freezeEl.textContent = "No active freeze.";
      }
    }

    // canary table
    const canaryBody = document.getElementById("health-canary-body");
    if (canaryBody) {
      renderSimpleTable(canaryBody, [], canaries.slice(0, 30).map((c) => [
        c.slug,
        statusBadge(c.status),
        fmtTs(c.started_at),
        fmtTs(c.until),
        fmtTs(c.promoted_at),
      ]));
    }

    // risk table
    const riskBody = document.getElementById("health-risk-body");
    if (riskBody) {
      if (!highRisk.length) {
        riskBody.innerHTML = "<tr><td colspan=\"5\" class=\"skill-empty\">No high-risk skills detected.</td></tr>";
      } else {
        renderSimpleTable(riskBody, [], highRisk.map((r) => [
          r.slug,
          { text: r.risk_tier || "—", cls: r.risk_tier === "critical" ? "st-bad" : "st-warn" },
          r.risk_score != null ? r.risk_score.toFixed(2) : "—",
          r.verdict || "—",
          String(r.rollback_count ?? 0),
        ]));
      }
    }

    const foot = document.getElementById("health-status");
    if (foot) foot.textContent = "Risk report: " + (health.risk_report_generated_at || "—") + " — Feed: " + (payload.updated_at || "");
  };

  /* === METRICS ======================================================= */
  const renderMetrics = (payload) => {
    const metrics = payload.metrics || {};
    const weekly = metrics.weekly || {};
    const series = metrics.series || {};
    const recentRuns = metrics.recent_runs || [];

    renderKpis(document.getElementById("metrics-kpis"), [
      { label: "Runs (week)", value: weekly.runs ?? 0 },
      {
        label: "Avg Install",
        value: fmtPct(weekly.avg_install_success_rate),
        cls: stateClass(70, 50, weekly.avg_install_success_rate ?? 0),
      },
      {
        label: "Avg Rollback",
        value: fmtPct(weekly.avg_rollback_rate),
        cls: stateClass(5, 10, weekly.avg_rollback_rate ?? 0),
      },
      {
        label: "Avg FP Rate",
        value: fmtPct(weekly.avg_false_positive_rate),
        cls: stateClass(10, 20, weekly.avg_false_positive_rate ?? 0),
      },
      { label: "Avg t→Decision", value: (weekly.avg_time_to_decision ?? 0) + "s" },
      { label: "Promotion Rate", value: fmtPct(weekly.avg_promotion_rate) },
    ]);

    // sparklines
    const installSvg = document.getElementById("metrics-spark-install");
    const rollbackSvg = document.getElementById("metrics-spark-rollback");
    const knownSvg = document.getElementById("metrics-spark-known");

    if (installSvg) makeSpark(installSvg, series.install_success_pct || [], {
      label: "Install success %",
      color: "rgba(57,217,138,0.9)",
      fillColor: "rgba(57,217,138,0.12)",
    });

    if (rollbackSvg) makeSpark(rollbackSvg, series.rollback_rate_pct || [], {
      label: "Rollback rate %",
      color: "rgba(255,107,107,0.9)",
      fillColor: "rgba(255,107,107,0.12)",
      badColor: "rgba(255,107,107,0.9)",
      badThreshold: 10,
    });

    if (knownSvg) makeSpark(knownSvg, series.known_total || [], {
      label: "Known skills",
      color: "rgba(45,212,191,0.8)",
      fillColor: "rgba(45,212,191,0.10)",
    });

    // recent runs table
    const runsBody = document.getElementById("metrics-runs-body");
    if (runsBody) {
      renderSimpleTable(runsBody, [], recentRuns.map((r) => [
        fmtTs(r.ts).replace(/:\d\d [AP]M|:\d\d$/, ""),
        { text: r.live ? "live" : "dry", cls: r.live ? "st-ok" : "" },
        r.vet_score != null ? r.vet_score.toFixed(0) : "—",
        fmtPct(r.install_success_rate),
        fmtPct(r.rollback_rate),
        String(r.known_total ?? "—"),
        String(r.canary_total ?? "—"),
      ]));
    }

    const foot = document.getElementById("metrics-status");
    if (foot) foot.textContent = "Weekly since " + (weekly.generated_at || "—") + " — " + (metrics.total_runs || 0) + " total runs";
  };

  /* === INIT ========================================================== */
  const initSkillPages = ({ ts, showError, setLoading }) => {
    const fetchWithPolicy = window.CanvasNet?.fetchWithPolicy || fetch;
    const classifyFetchError = window.CanvasNet?.classifyFetchError || (() => "network");

    const setStatuses = (text) => {
      ["scout-status", "health-status", "metrics-status"].forEach((id) => {
        const el = document.getElementById(id);
        if (el) el.textContent = text;
      });
    };

    const loadFeed = async ({ force = false } = {}) => {
      const now = Date.now();
      if (!force && cache && now - cacheTs < FEED_CACHE_MS) {
        renderScout(cache);
        renderHealth(cache);
        renderMetrics(cache);
        return;
      }
      ["scout", "health", "metrics"].forEach((id) => setLoading(id + "-status", true));
      try {
        const res = await fetchWithPolicy(FEED_URL, { cache: "no-store" }, { timeoutMs: 5000, retries: 1 });
        if (!res.ok) throw new Error("HTTP " + res.status);
        cache = await res.json();
        cacheTs = Date.now();
        renderScout(cache);
        renderHealth(cache);
        renderMetrics(cache);
      } catch (err) {
        setStatuses("Feed error: " + (err.message || "unknown"));
        showError(classifyFetchError(err), "State brief feed failed: " + (err.message || "unknown"));
      } finally {
        ["scout", "health", "metrics"].forEach((id) => setLoading(id + "-status", false));
      }
    };

    ["scout", "health", "metrics"].forEach((id) => {
      document.getElementById("btn-" + id + "-refresh")?.addEventListener("click", () => loadFeed({ force: true }));
    });
    loadFeed({ force: true });
  };

  return { register, initPage };
})();
