/* ─── app-rag.js — Canvas RAG ─── */
/* Exposes window.CanvasRag. Lazy-init via .initPage(). */
window.CanvasRag = (() => {
  let _deps = null;
  let ragPageInitialized = false;

  const register = ({ ts, showError, setLoading }) => {
    _deps = { ts, showError, setLoading };
  };

  const initPage = () => {
    if (!_deps) return;
    if (ragPageInitialized) return;
    ragPageInitialized = true;
    _initRagPage(_deps);
  };

  const _initRagPage = ({ ts, showError, setLoading }) => {
    const fetchWithPolicy = window.CanvasNet?.fetchWithPolicy || fetch;
    const escHtml = window.CanvasNet?.escHtml || ((s) => String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;"));
    const _resolveRagBase = window.CanvasDashboard?.resolveRagBase || (async (host) => "http://" + host + ":18789/api/rag");
    let _ragBaseCache = null;
    let _ragBaseCacheTs = 0;
    const RAG_BASE_CACHE_MS = 60000;
    const resolveRagBase = async (host) => {
      const now = Date.now();
      if (_ragBaseCache && now - _ragBaseCacheTs < RAG_BASE_CACHE_MS) return _ragBaseCache;
      _ragBaseCache = await _resolveRagBase(host);
      _ragBaseCacheTs = now;
      return _ragBaseCache;
    };

/* ════════════════ RAG ════════════════ */
const ragResults  = document.getElementById("rag-results");
const ragQuery    = document.getElementById("rag-query");
const ragDocCount = document.getElementById("rag-doc-count");
const ragLastIdx  = document.getElementById("rag-last-indexed");
const ragChip     = document.getElementById("rag-status-chip");
const ragReindexStatus = document.getElementById("rag-reindex-status");

const loadRagStatus = async () => {
  const host = window.location.hostname || "192.168.2.101";
  try {
    const ragBase = await resolveRagBase(host);
    const res = await fetchWithPolicy(ragBase + "/status", { cache: "no-store" }, { timeoutMs: 4500, retries: 1 });
    if (!res.ok) throw new Error("HTTP " + res.status);
    const d = await res.json();
    ragDocCount.textContent = d.doc_count ?? "?";
    if (typeof d.last_indexed === "number") {
      ragLastIdx.textContent = new Date(d.last_indexed * 1000).toLocaleString();
    } else {
      ragLastIdx.textContent  = d.last_indexed ?? "unknown";
    }
    ragChip.textContent     = d.status ?? "ready";
    ragChip.className = "chip " + (d.status === "ready" ? "ok" : "warn");
  } catch {
    ragChip.textContent = "unavailable";
    ragChip.className = "chip bad";
  }
};

loadRagStatus();

const doRagSearch = async () => {
  const query = ragQuery.value.trim();
  if (!query) return;
  ragResults.innerHTML = '<div class="rag-empty">Searching…</div>';
  const host = window.location.hostname || "192.168.2.101";
  try {
    const ragBase = await resolveRagBase(host);
    const res = await fetchWithPolicy(ragBase + "/search", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ query }),
    }, { timeoutMs: 12000, retries: 1 });
    if (!res.ok) throw new Error("HTTP " + res.status);
    const data = await res.json();
    const hits = data.results || data.hits || [];
    if (!hits.length) { ragResults.innerHTML = '<div class="rag-empty">No results found.</div>'; return; }
    ragResults.innerHTML = "";
    hits.forEach(h => {
      const div = document.createElement("div");
      div.className = "rag-result";
      div.innerHTML =
        '<div class="rag-meta">' +
        '<span class="rag-source">' + escHtml(h.source || h.file || "?") + '</span>' +
        (h.score != null ? '<span class="rag-score">score: ' + Number(h.score).toFixed(3) + '</span>' : '') +
        (h.chunk_index != null ? '<span>chunk #' + h.chunk_index + '</span>' : '') +
        '</div>' +
        '<div class="rag-body">' + escHtml(h.text || h.content || "") + '</div>';
      ragResults.appendChild(div);
    });
  } catch (err) {
    ragResults.innerHTML = '<div class="rag-empty" style="color:var(--bad)">Error: ' + escHtml(err.message) + ' — RAG endpoint not yet available.</div>';
    showError("network", "RAG search failed: " + err.message);
  }
};

document.getElementById("btn-rag-search").addEventListener("click", doRagSearch);
ragQuery.addEventListener("keydown", (e) => { if (e.key === "Enter") doRagSearch(); });

// Quick Query Chips
document.querySelectorAll("[data-rag-quick]").forEach((chip) => {
  chip.addEventListener("click", (e) => {
    e.preventDefault();
    ragQuery.value = chip.getAttribute("data-rag-quick");
    ragQuery.focus();
    doRagSearch();
  });
});

document.getElementById("btn-rag-reindex").addEventListener("click", async () => {
  const host = window.location.hostname || "192.168.2.101";
  const btn = document.getElementById("btn-rag-reindex");
  btn.disabled = true; btn.textContent = "Reindexing…";
  if (ragReindexStatus) ragReindexStatus.textContent = "Reindex running…";
  try {
    const ragBase = await resolveRagBase(host);
    const res = await fetchWithPolicy(ragBase + "/reindex", { method: "POST" }, { timeoutMs: 15000, retries: 0 });
    const payload = await res.json().catch(() => ({}));
    await loadRagStatus();
    if (payload?.ok) {
      if (ragReindexStatus) ragReindexStatus.textContent = "Reindex completed at " + ts();
    } else {
      const reason = payload?.error || payload?.stderr || ("code " + (payload?.code ?? "?"));
      if (ragReindexStatus) ragReindexStatus.textContent = "Reindex failed: " + String(reason).slice(0, 180);
      ragChip.textContent = "reindex failed";
      ragChip.className = "chip bad";
    }
  } catch {
    ragChip.textContent = "reindex failed";
    ragChip.className = "chip bad";
    if (ragReindexStatus) ragReindexStatus.textContent = "Reindex failed: network error";
  }
  btn.disabled = false; btn.textContent = "Reindex";
});

  };

  return { register, initPage };
})();
