(() => {
  if ("serviceWorker" in navigator) {
    window.addEventListener("load", () => {
      navigator.serviceWorker.register("/sw.js").catch(() => {
        // Keep UI functional even when SW is not available (e.g. insecure context)
      });
    });
  }

  /* ─── Global Error Banner ─── */
  const bannerEl = document.getElementById("global-error-banner");
  let bannerTimer = null;

  const hideBanner = () => {
    bannerEl.className = "";
    bannerEl.innerHTML = "";
    document.body.classList.remove("has-global-banner");
    if (bannerTimer) { clearTimeout(bannerTimer); bannerTimer = null; }
  };

  /* ─── Config-Imports aus app-config.js ─── */
  /* Config is accessed via window.CanvasConfig by each sub-module. */

  let dash = null; /* CanvasDashboard instance */

  /* ─── Error Queue System ─── */
  let errorQueue = [];
  let errorTimers = [];
  const MAX_ERROR_QUEUE = 3;
  const ERROR_AUTO_DISMISS_MS = 15000;

  const getErrorHintText = (type) => {
    const hints = {
      "network": "❌ Connection error",
      "auth": "🔐 Authentication failed",
      "timeout": "⏱️ Request timeout",
      "schema": "⚠️ Invalid response",
    };
    return hints[type] || "❌ Error";
  };

  const flushErrorQueue = () => {
    if (errorQueue.length === 0) {
      hideBanner();
      return;
    }
    const { type, message } = errorQueue[0];
    const hintText = getErrorHintText(type);
    const displayMsg = hintText + " — " + message;
    bannerEl.className = "visible type-" + type;
    const msg = document.createElement("span");
    msg.textContent = displayMsg;
    const dismiss = document.createElement("button");
    dismiss.className = "banner-dismiss";
    dismiss.title = "Dismiss";
    dismiss.textContent = "✕";
    dismiss.addEventListener("click", () => clearCurrentError());
    bannerEl.innerHTML = "";
    bannerEl.appendChild(msg);
    bannerEl.appendChild(dismiss);
    document.body.classList.add("has-global-banner");

    if (errorTimers[0]) clearTimeout(errorTimers[0]);
    errorTimers[0] = setTimeout(() => clearCurrentError(), ERROR_AUTO_DISMISS_MS);
  };

  const clearCurrentError = () => {
    if (errorQueue.length > 0) {
      if (errorTimers[0]) clearTimeout(errorTimers[0]);
      errorTimers.shift();
      errorQueue.shift();
    }
    flushErrorQueue();
  };

  const showError = (typeOrMsg, messageOrUndef) => {
    let type, message;
    if (typeof typeOrMsg === "string" && (messageOrUndef === undefined || typeof messageOrUndef !== "string")) {
      type = "network";
      message = typeOrMsg;
    } else {
      type = typeOrMsg || "network";
      message = messageOrUndef || "";
    }
    
    if (!message) message = "Unknown error";
    if (errorQueue.length < MAX_ERROR_QUEUE) {
      errorQueue.push({ type, message });
      if (errorQueue.length === 1) {
        flushErrorQueue();
      }
    } else {
      console.warn("[Canvas] Error queue full, dropping error:", message);
    }
  };

  /* ─── Loading States & Spinners ─── */
  const makeSpinner = () => {
    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svg.setAttribute("viewBox", "0 0 50 50");
    svg.setAttribute("width", "20");
    svg.setAttribute("height", "20");
    svg.style.display = "inline-block";
    svg.style.marginRight = "6px";
    svg.style.verticalAlign = "middle";
    svg.style.animation = "spin 1s linear infinite";

    const circle = document.createElementNS("http://www.w3.org/2000/svg", "circle");
    circle.setAttribute("cx", "25");
    circle.setAttribute("cy", "25");
    circle.setAttribute("r", "20");
    circle.setAttribute("fill", "none");
    circle.setAttribute("stroke", "currentColor");
    circle.setAttribute("stroke-width", "4");
    circle.setAttribute("stroke-dasharray", "31.4 125.6");
    svg.appendChild(circle);
    return svg;
  };

  const setLoading = (componentId, isLoading) => {
    const el = document.getElementById(componentId);
    if (!el) return;

    if (isLoading) {
      if (!document.getElementById(componentId + "-spinner")) {
        const spinner = makeSpinner();
        spinner.id = componentId + "-spinner";
        el.insertBefore(spinner, el.firstChild);
      }
      el.style.opacity = "0.6";
    } else {
      const spinner = document.getElementById(componentId + "-spinner");
      if (spinner) spinner.remove();
      el.style.opacity = "1";
    }
  };

  /* ─── Router ─── */
  const pages = document.querySelectorAll(".page");
  const navLinks = document.querySelectorAll(".nav-link");
  const pageOrder = ["dashboard", "chat", "mqtt", "rag", "settings"];
  const showPage = (id) => {
    pages.forEach(p => p.classList.toggle("active", p.id === "page-" + id));
    navLinks.forEach(l => {
      const active = l.dataset.page === id;
      l.classList.toggle("active", active);
      l.setAttribute("aria-current", active ? "page" : "false");
    });
    history.replaceState(null, "", "#" + id);
    if (id === "settings") window.CanvasSettings?.loadSettingsForm();
    if (id === "mqtt") window.CanvasMqtt?.initPage();
    if (id === "rag") window.CanvasRag?.initPage();
    if (id === "operations" || id === "decisions" || id === "runbooks") window.CanvasOps?.initPage();
    if (id === "scout" || id === "health" || id === "metrics" || id === "skills") window.CanvasSkill?.initPage();
  };
  navLinks.forEach(l => l.addEventListener("click", () => showPage(l.dataset.page)));
  const hash = location.hash.replace("#", "");
  if (hash.startsWith("skills:")) {
    showPage("skills");
    const slug = hash.split(":", 2)[1] || "";
    window.dispatchEvent(new CustomEvent("canvas-skill-select", { detail: { slug } }));
  } else if (hash && document.getElementById("page-" + hash)) {
    showPage(hash);
  }

  const isTypingContext = (target) => {
    const tag = (target?.tagName || "").toLowerCase();
    if (tag === "input" || tag === "textarea" || tag === "select") return true;
    return !!target?.isContentEditable;
  };

  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") {
      const shortcutsModal = document.getElementById("shortcuts-modal");
      if (shortcutsModal.style.display === "flex") {
        shortcutsModal.style.display = "none";
        shortcutsModal.setAttribute("aria-hidden", "true");
        return;
      }
      const openDialog = document.querySelector("dialog[open]");
      if (openDialog && typeof openDialog.close === "function") {
        openDialog.close();
        return;
      }
      const modal = document.querySelector('[aria-modal="true"], .modal.open, .modal[open]');
      if (modal) {
        modal.classList.remove("open");
        if (modal.hasAttribute("open")) modal.removeAttribute("open");
        if (modal.getAttribute("aria-hidden") === "false") modal.setAttribute("aria-hidden", "true");
        return;
      }
      if (document.activeElement && document.activeElement !== document.body) {
        document.activeElement.blur();
      }
      return;
    }

    if (isTypingContext(e.target)) return;

    if (e.key === "?") {
      e.preventDefault();
      const shortcutsModal = document.getElementById("shortcuts-modal");
      shortcutsModal.style.display = "flex";
      shortcutsModal.setAttribute("aria-hidden", "false");
      return;
    }

    if (e.key >= "1" && e.key <= "5") {
      const idx = Number(e.key) - 1;
      const pageId = pageOrder[idx];
      if (pageId) {
        e.preventDefault();
        showPage(pageId);
      }
      return;
    }

    if (e.key.toLowerCase() === "r") {
      e.preventDefault();
      dash?.refreshHealth();
    }
  });

  /* ─── Clock ─── */
  const clockEl = document.getElementById("clock");
  const ts = () => new Date().toLocaleTimeString();
  setInterval(() => { clockEl.textContent = ts(); }, 1000);
  clockEl.textContent = ts();

  /* ─── Dashboard-Modul in app-dashboard.js ─── */
  /* ─── Chat/MQTT/RAG-Module: app-chat.js / app-mqtt.js / app-rag.js ─── */
  /* ─── Settings-Modul: app-settings.js ─── */
  /* ── Shortcuts Modal ── */
  const shortcutsModal = document.getElementById("shortcuts-modal");
  const shortcutsClose = document.getElementById("shortcuts-close");
  shortcutsClose.addEventListener("click", () => {
    shortcutsModal.style.display = "none";
    shortcutsModal.setAttribute("aria-hidden", "true");
  });
  shortcutsModal.addEventListener("click", (e) => {
    if (e.target === shortcutsModal) {
      shortcutsModal.style.display = "none";
      shortcutsModal.setAttribute("aria-hidden", "true");
    }
  });

  /* ── init ── */
  dash = window.CanvasDashboard.init({ ts, showError, setLoading });
  dash.renderQuickLinks(window.CanvasConfig.cfg().quickLinks);
  window.CanvasSettings?.init({ ts, getDash: () => dash });
  window.CanvasChat?.init({ ts, showError });
  window.CanvasMqtt?.register({ ts, showError, setLoading });
  window.CanvasRag?.register({ ts, showError, setLoading });
  window.CanvasOps?.register({ ts, showError, setLoading });
  window.CanvasSkill?.register({ ts, showError, setLoading });
  if (document.getElementById("page-rag").classList.contains("active")) window.CanvasRag?.initPage();
  if (document.getElementById("page-mqtt").classList.contains("active")) window.CanvasMqtt?.initPage();
  if (
    document.getElementById("page-operations")?.classList.contains("active") ||
    document.getElementById("page-decisions")?.classList.contains("active") ||
    document.getElementById("page-runbooks")?.classList.contains("active")
  ) window.CanvasOps?.initPage();
  if (
    document.getElementById("page-scout")?.classList.contains("active") ||
    document.getElementById("page-health")?.classList.contains("active") ||
    document.getElementById("page-metrics")?.classList.contains("active") ||
    document.getElementById("page-skills")?.classList.contains("active")
  ) window.CanvasSkill?.initPage();

})();
