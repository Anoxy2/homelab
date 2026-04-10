(() => {
  const classifyFetchError = (err) => {
    if (!err) return "network";
    const msg = String(err.message || "").toLowerCase();
    if (msg.includes("401") || msg.includes("403") || msg.includes("unauthorized") || msg.includes("forbidden")) return "auth";
    if (msg.includes("timeout") || msg.includes("abort")) return "timeout";
    if (msg.includes("json") || msg.includes("parse") || msg.includes("syntax")) return "schema";
    return "network";
  };

  const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

  const fetchWithPolicy = async (url, options = {}, policy = {}) => {
    const timeoutMs = Number(policy.timeoutMs ?? 4500);
    const retries = Number(policy.retries ?? 1);
    const retryBackoffMs = Number(policy.retryBackoffMs ?? 350);
    const retryOnHttp = Array.isArray(policy.retryOnHttp)
      ? policy.retryOnHttp
      : [429, 500, 502, 503, 504];

    let lastErr = null;
    for (let attempt = 0; attempt <= retries; attempt++) {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), timeoutMs);
      try {
        const res = await fetch(url, { ...options, signal: controller.signal });
        clearTimeout(timer);
        if (!res.ok && retryOnHttp.includes(res.status) && attempt < retries) {
          const jitter = Math.floor(Math.random() * 120);
          await sleep(retryBackoffMs * Math.pow(2, attempt) + jitter);
          continue;
        }
        return res;
      } catch (err) {
        clearTimeout(timer);
        const timedOut = err?.name === "AbortError";
        lastErr = timedOut
          ? new Error("Timeout after " + timeoutMs + "ms")
          : err;
        if (attempt >= retries) break;
        const jitter = Math.floor(Math.random() * 120);
        await sleep(retryBackoffMs * Math.pow(2, attempt) + jitter);
      }
    }
    throw lastErr || new Error("Network request failed");
  };

  const escHtml = (s) => String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");

  window.CanvasNet = {
    classifyFetchError,
    fetchWithPolicy,
    escHtml,
  };
})();
