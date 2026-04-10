/* --- app-ops.js - Canvas Operations / Decisions / Runbooks --- */
window.CanvasOps = (() => {
  let deps = null;
  let pageInitialized = false;
  let cache = null;
  let cacheTs = 0;
  const FEED_URL = "/ops-brief.latest.json";
  const FEED_CACHE_MS = 30000;

  const register = ({ ts, showError, setLoading }) => {
    deps = { ts, showError, setLoading };
  };

  const initPage = () => {
    if (!deps || pageInitialized) return;
    pageInitialized = true;
    initOpsPages(deps);
  };

  const initOpsPages = ({ ts, showError, setLoading }) => {
    const fetchWithPolicy = window.CanvasNet?.fetchWithPolicy || fetch;
    const classifyFetchError = window.CanvasNet?.classifyFetchError || (() => "network");

    const operationsKpis = document.getElementById("operations-kpis");
    const operationsList = document.getElementById("operations-open-work");
    const handoverOrder = document.getElementById("operations-handover-order");
    const handoverStart = document.getElementById("operations-handover-start");
    const handoverEnd = document.getElementById("operations-handover-end");
    const operationsSources = document.getElementById("operations-sources");
    const operationsStatus = document.getElementById("operations-status");
    const decisionsKpis = document.getElementById("decisions-kpis");
    const decisionsList = document.getElementById("decisions-list");
    const decisionsStatus = document.getElementById("decisions-status");
    const runbooksKpis = document.getElementById("runbooks-kpis");
    const runbooksList = document.getElementById("runbooks-list");
    const runbooksStatus = document.getElementById("runbooks-status");

    const renderEmptyList = (el, message) => {
      el.innerHTML = "";
      const item = document.createElement("li");
      item.className = "doc-list-empty";
      item.textContent = message;
      el.appendChild(item);
    };

    const renderKpis = (el, items) => {
      el.innerHTML = "";
      items.forEach(({ label, value, stateClass }) => {
        const card = document.createElement("div");
        card.className = "kpi";
        const key = document.createElement("div");
        key.className = "k";
        key.textContent = label;
        const val = document.createElement("div");
        val.className = "v" + (stateClass ? " " + stateClass : "");
        val.textContent = String(value);
        card.appendChild(key);
        card.appendChild(val);
        el.appendChild(card);
      });
    };

    const renderSimpleList = (el, items, emptyMessage = "Keine Eintraege verfuegbar.") => {
      if (!items.length) {
        renderEmptyList(el, emptyMessage);
        return;
      }
      el.innerHTML = "";
      items.forEach((text) => {
        const item = document.createElement("li");
        item.textContent = text;
        el.appendChild(item);
      });
    };

    const makeMeta = (parts) => {
      const meta = document.createElement("div");
      meta.className = "doc-meta";
      parts.filter(Boolean).forEach((text) => {
        const span = document.createElement("span");
        span.textContent = text;
        meta.appendChild(span);
      });
      return meta;
    };

    const renderOperations = (payload) => {
      const operations = payload.operations || {};
      const openWork = operations.open_work || { items: [], counts: {} };
      const handover = operations.handover || { order: [], start_check: [], end_check: [] };
      const kpis = operations.kpis || {};

      renderKpis(operationsKpis, [
        { label: "Open Items", value: kpis.open_total ?? 0 },
        { label: "P0", value: kpis.p0 ?? 0, stateClass: (kpis.p0 ?? 0) > 0 ? "bad" : "ok" },
        { label: "P1", value: kpis.p1 ?? 0, stateClass: (kpis.p1 ?? 0) > 0 ? "warn" : "ok" },
        { label: "Start Checks", value: kpis.start_checks ?? 0 },
        { label: "End Checks", value: kpis.end_checks ?? 0 },
      ]);

      if (!openWork.items?.length) {
        renderEmptyList(operationsList, "Keine offenen Arbeitspunkte im Feed.");
      } else {
        operationsList.innerHTML = "";
        openWork.items.forEach((entry) => {
          const item = document.createElement("li");
          const meta = makeMeta([entry.priority, entry.section]);
          const text = document.createElement("div");
          text.className = "doc-body";
          text.textContent = entry.text;
          item.appendChild(meta);
          item.appendChild(text);
          operationsList.appendChild(item);
        });
      }

      renderSimpleList(handoverOrder, handover.order || []);
      renderSimpleList(handoverStart, handover.start_check || []);
      renderSimpleList(handoverEnd, handover.end_check || []);
      renderSimpleList(operationsSources, operations.source_paths || [], "Keine Quellen verfuegbar.");
    };

    const renderDecisions = (payload) => {
      const decisions = payload.decisions || { items: [] };
      renderKpis(decisionsKpis, [
        { label: "Decisions", value: decisions.count ?? 0 },
        { label: "Review Hints", value: decisions.review_count ?? 0, stateClass: (decisions.review_count ?? 0) > 0 ? "warn" : "ok" },
      ]);

      if (!decisions.items?.length) {
        decisionsList.innerHTML = '<div class="doc-card doc-card-empty">Keine Decisions verfuegbar.</div>';
        return;
      }

      decisionsList.innerHTML = "";
      decisions.items.forEach((entry) => {
        const card = document.createElement("article");
        card.className = "doc-card";
        const title = document.createElement("h3");
        title.textContent = entry.title;
        const meta = makeMeta([
          entry.needs_review ? "review hint" : "stable",
          entry.source_path,
        ]);
        const outcome = document.createElement("p");
        outcome.className = "doc-outcome";
        outcome.textContent = entry.outcome || entry.summary || "Kein Kurzfazit verfuegbar.";
        const summary = document.createElement("p");
        summary.className = "doc-body";
        summary.textContent = entry.summary || "Keine Kurzbeschreibung verfuegbar.";
        card.appendChild(title);
        card.appendChild(meta);
        card.appendChild(outcome);
        if (entry.review_hint) {
          const review = document.createElement("p");
          review.className = "doc-note";
          review.textContent = "Review: " + entry.review_hint;
          card.appendChild(review);
        }
        card.appendChild(summary);
        decisionsList.appendChild(card);
      });
    };

    const renderRunbooks = (payload) => {
      const runbooks = payload.runbooks || { items: [] };
      renderKpis(runbooksKpis, [
        { label: "Runbooks", value: runbooks.count ?? 0 },
      ]);

      if (!runbooks.items?.length) {
        runbooksList.innerHTML = '<div class="doc-card doc-card-empty">Keine Runbooks verfuegbar.</div>';
        return;
      }

      runbooksList.innerHTML = "";
      runbooks.items.forEach((entry) => {
        const card = document.createElement("article");
        card.className = "doc-card";
        const title = document.createElement("h3");
        title.textContent = entry.title;
        const meta = makeMeta([entry.source_path].concat(entry.tags || []));
        const summary = document.createElement("p");
        summary.className = "doc-body";
        summary.textContent = entry.summary || "Keine Kurzbeschreibung verfuegbar.";
        card.appendChild(title);
        card.appendChild(meta);
        card.appendChild(summary);
        if (entry.first_steps?.length) {
          const steps = document.createElement("ul");
          steps.className = "doc-mini-list";
          entry.first_steps.forEach((step) => {
            const item = document.createElement("li");
            item.textContent = step;
            steps.appendChild(item);
          });
          card.appendChild(steps);
        }
        runbooksList.appendChild(card);
      });
    };

    const setStatuses = (text) => {
      operationsStatus.textContent = text;
      decisionsStatus.textContent = text;
      runbooksStatus.textContent = text;
    };

    const renderPayload = (payload) => {
      renderOperations(payload);
      renderDecisions(payload);
      renderRunbooks(payload);
      setStatuses("Feed updated: " + (payload.updated_at || ts()));
    };

    const renderFailure = (message) => {
      renderEmptyList(operationsList, "Feed nicht verfuegbar: " + message);
      renderEmptyList(handoverOrder, "Feed nicht verfuegbar.");
      renderEmptyList(handoverStart, "Feed nicht verfuegbar.");
      renderEmptyList(handoverEnd, "Feed nicht verfuegbar.");
      renderEmptyList(operationsSources, "Quelle: /ops-brief.latest.json");
      decisionsList.innerHTML = '<div class="doc-card doc-card-empty">Feed nicht verfuegbar.</div>';
      runbooksList.innerHTML = '<div class="doc-card doc-card-empty">Feed nicht verfuegbar.</div>';
      setStatuses("Feed error: " + message);
    };

    const loadFeed = async ({ force = false } = {}) => {
      const now = Date.now();
      if (!force && cache && now - cacheTs < FEED_CACHE_MS) {
        renderPayload(cache);
        return;
      }

      setLoading("operations-status", true);
      setLoading("decisions-status", true);
      setLoading("runbooks-status", true);
      try {
        const res = await fetchWithPolicy(FEED_URL, { cache: "no-store" }, { timeoutMs: 4500, retries: 1 });
        if (!res.ok) throw new Error("HTTP " + res.status);
        cache = await res.json();
        cacheTs = Date.now();
        renderPayload(cache);
      } catch (err) {
        renderFailure(err.message || "unknown");
        showError(classifyFetchError(err), "Ops brief feed failed: " + (err.message || "unknown"));
      } finally {
        setLoading("operations-status", false);
        setLoading("decisions-status", false);
        setLoading("runbooks-status", false);
      }
    };

    document.getElementById("btn-operations-refresh")?.addEventListener("click", () => loadFeed({ force: true }));
    document.getElementById("btn-decisions-refresh")?.addEventListener("click", () => loadFeed({ force: true }));
    document.getElementById("btn-runbooks-refresh")?.addEventListener("click", () => loadFeed({ force: true }));

    loadFeed({ force: true });
  };

  return { register, initPage };
})();
