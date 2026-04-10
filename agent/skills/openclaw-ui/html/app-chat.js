/* ─── app-chat.js — Canvas Chat ─── */
/* Exposes window.CanvasChat. Initialisierung via .init(deps). */
window.CanvasChat = {
  init: ({ ts, showError }) => {
    const { cfg, DEFAULTS, chatHistory, saveChat } = window.CanvasConfig;
    const fetchWithPolicy = window.CanvasNet?.fetchWithPolicy || fetch;

/* ════════════════ CHAT ════════════════ */
const chatHistoryEl = document.getElementById("chat-history");
const chatInput     = document.getElementById("chat-input");
const chatStatus    = document.getElementById("chat-status");
let chatBusy = false;

const renderMessages = () => {
  const msgs = chatHistory();
  chatHistoryEl.innerHTML = "";
  msgs.forEach(m => appendBubble(m.role, m.text, false));
  chatHistoryEl.scrollTop = chatHistoryEl.scrollHeight;
};

const appendBubble = (role, text, scroll = true) => {
  const div = document.createElement("div");
  div.className = "chat-msg " + role;
  div.textContent = text;
  chatHistoryEl.appendChild(div);
  if (scroll) chatHistoryEl.scrollTop = chatHistoryEl.scrollHeight;
  return div;
};

const sendChat = async () => {
  const text = chatInput.value.trim();
  if (!text || chatBusy) return;
  chatBusy = true;
  chatInput.disabled = true;
  document.getElementById("btn-chat-send").disabled = true;
  chatStatus.textContent = "Sending…";

  const history = chatHistory();
  history.push({ role: "user", text });
  saveChat(history);
  appendBubble("user", text);
  chatInput.value = "";

  const c = cfg();
  const openclawBase = String(c.openclawBaseUrl || DEFAULTS.openclawBaseUrl).replace(/\/$/, "");
  const thinkingEl = appendBubble("agent", "…");
  try {
    const res = await fetchWithPolicy(openclawBase + "/api/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message: text }),
    }, { timeoutMs: 15000, retries: 1 });
    if (!res.ok) throw new Error("HTTP " + res.status);
    const data = await res.json();
    const reply = data.reply || data.response || data.message || JSON.stringify(data);
    thinkingEl.textContent = reply;
    const h2 = chatHistory();
    h2.push({ role: "agent", text: reply });
    saveChat(h2);
    chatStatus.textContent = "Last reply " + ts();
  } catch (err) {
    thinkingEl.className = "chat-msg error";
    thinkingEl.textContent = "Error: " + err.message + " — Is OpenClaw reachable?";
    chatStatus.textContent = "Error – check console";
    showError("network", "Chat API error: " + err.message);
  }
  chatBusy = false;
  chatInput.disabled = false;
  document.getElementById("btn-chat-send").disabled = false;
  chatInput.focus();
};

document.getElementById("btn-chat-send").addEventListener("click", sendChat);
chatInput.addEventListener("keydown", (e) => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); sendChat(); } });
document.getElementById("btn-chat-clear").addEventListener("click", () => {
  saveChat([]);
  chatHistoryEl.innerHTML = "";
  chatStatus.textContent = "History cleared.";
});
renderMessages();


    return {};
  }
};
