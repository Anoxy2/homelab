/* ─── app-mqtt.js — Canvas MQTT Browser ─── */
/* Exposes window.CanvasMqtt. Lazy-init via .initPage(). */
window.CanvasMqtt = (() => {
  let _deps = null;
  let mqttPageInitialized = false;

  const register = ({ ts, showError, setLoading }) => {
    _deps = { ts, showError, setLoading };
  };

  const initPage = () => {
    if (!_deps) return;
    if (mqttPageInitialized) return;
    mqttPageInitialized = true;
    _initMqttPage(_deps);
  };

  const _initMqttPage = ({ ts, showError, setLoading }) => {
    const { cfg } = window.CanvasConfig;
    const fetchWithPolicy = window.CanvasNet?.fetchWithPolicy || fetch;

/* ════════════════ MQTT BROWSER ════════════════ */
let mqttClient = null;
const mqttDot    = document.getElementById("mqtt-dot");
const mqttStatusTxt = document.getElementById("mqtt-status-text");
const mqttStream = document.getElementById("mqtt-stream");
const mqttFilter = document.getElementById("mqtt-filter");
const btnConnect = document.getElementById("btn-mqtt-connect");
const btnDisconn = document.getElementById("btn-mqtt-disconnect");
const actionLogStream = document.getElementById("action-log-stream");
const actionLogStatus = document.getElementById("action-log-status");
const actionLogHist = document.getElementById("action-log-hist");

const setMqttStatus = (state, text) => {
  mqttDot.className = "mqtt-dot " + (state || "");
  mqttStatusTxt.textContent = text;
};

const appendMqttMsg = (topic, payload) => {
  const line = document.createElement("div");
  line.className = "mqtt-msg";
  line.innerHTML =
    '<span class="ts">' + ts() + '</span>' +
    '<span class="topic">' + escHtml(topic) + '</span>' +
    '<span class="payload">' + escHtml(String(payload)) + '</span>';
  mqttStream.appendChild(line);
  while (mqttStream.children.length > 200) mqttStream.removeChild(mqttStream.firstChild);
  mqttStream.scrollTop = mqttStream.scrollHeight;
};

const escHtml = window.CanvasNet?.escHtml || ((s) => String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;"));

const mqttVarInt = (len) => {
  const bytes = [];
  do {
    let digit = len % 128;
    len = Math.floor(len / 128);
    if (len > 0) digit |= 0x80;
    bytes.push(digit);
  } while (len > 0);
  return bytes;
};

const renderActionHistogram = (entries) => {
  if (!actionLogHist) return;
  const W = 420;
  const H = 120;
  const padL = 28;
  const padR = 8;
  const padT = 8;
  const padB = 22;
  const chartW = W - padL - padR;
  const chartH = H - padT - padB;
  actionLogHist.innerHTML = "";

  const mk = (tag) => document.createElementNS("http://www.w3.org/2000/svg", tag);
  const bg = mk("rect");
  bg.setAttribute("x", "0");
  bg.setAttribute("y", "0");
  bg.setAttribute("width", String(W));
  bg.setAttribute("height", String(H));
  bg.setAttribute("fill", "rgba(0,0,0,0.15)");
  actionLogHist.appendChild(bg);

  const now = Date.now();
  const buckets = [];
  for (let i = 23; i >= 0; i--) {
    const start = new Date(now - i * 60 * 60 * 1000);
    start.setMinutes(0, 0, 0);
    buckets.push({ key: start.getTime(), label: start.getHours(), success: 0, fail: 0 });
  }
  const byKey = new Map(buckets.map((b) => [b.key, b]));

  const isSuccess = (r) => /(ok|success|completed|sent)/i.test(String(r || ""));
  const isFail = (r) => /(fail|error|timeout|denied)/i.test(String(r || ""));

  entries.forEach((row) => {
    const d = new Date(String(row.ts || ""));
    if (Number.isNaN(d.getTime())) return;
    d.setMinutes(0, 0, 0);
    const bucket = byKey.get(d.getTime());
    if (!bucket) return;
    const result = String(row.result || "");
    if (isSuccess(result)) bucket.success += 1;
    else if (isFail(result)) bucket.fail += 1;
  });

  const maxCount = Math.max(1, ...buckets.map((b) => b.success + b.fail));
  const barW = chartW / buckets.length;

  buckets.forEach((b, i) => {
    const x = padL + i * barW;
    const total = b.success + b.fail;
    const totalH = (total / maxCount) * chartH;
    const failH = total > 0 ? (b.fail / total) * totalH : 0;
    const successH = totalH - failH;
    const yBase = padT + chartH;

    if (successH > 0) {
      const okBar = mk("rect");
      okBar.setAttribute("x", String(x + 0.5));
      okBar.setAttribute("y", String(yBase - successH));
      okBar.setAttribute("width", String(Math.max(1, barW - 1.5)));
      okBar.setAttribute("height", String(successH));
      okBar.setAttribute("fill", "rgba(57,217,138,0.8)");
      actionLogHist.appendChild(okBar);
    }
    if (failH > 0) {
      const failBar = mk("rect");
      failBar.setAttribute("x", String(x + 0.5));
      failBar.setAttribute("y", String(yBase - totalH));
      failBar.setAttribute("width", String(Math.max(1, barW - 1.5)));
      failBar.setAttribute("height", String(failH));
      failBar.setAttribute("fill", "rgba(255,107,107,0.9)");
      actionLogHist.appendChild(failBar);
    }

    if (i % 6 === 0) {
      const tick = mk("text");
      tick.setAttribute("x", String(x + 1));
      tick.setAttribute("y", String(H - 6));
      tick.setAttribute("font-size", "9");
      tick.setAttribute("fill", "#9fb4bb");
      tick.textContent = String(b.label).padStart(2, "0") + "h";
      actionLogHist.appendChild(tick);
    }
  });

  const topLabel = mk("text");
  topLabel.setAttribute("x", "8");
  topLabel.setAttribute("y", "11");
  topLabel.setAttribute("font-size", "9");
  topLabel.setAttribute("fill", "#9fb4bb");
  topLabel.textContent = "24h success/fail histogram";
  actionLogHist.appendChild(topLabel);
};

const loadActionLog = async () => {
  try {
    setLoading("action-log-stream", true);
    actionLogStatus.textContent = "Loading…";
    const res = await fetchWithPolicy("/action-log.latest.json", { cache: "no-store" }, { timeoutMs: 4500, retries: 1 });
    if (!res.ok) throw new Error("HTTP " + res.status);
    const payload = await res.json();
    const entries = Array.isArray(payload.entries) ? payload.entries : [];

    actionLogStream.innerHTML = "";
    entries.slice().reverse().forEach((row) => {
      const line = document.createElement("div");
      line.className = "mqtt-msg";
      const tsRaw = String(row.ts || "");
      const tsLabel = tsRaw ? new Date(tsRaw).toLocaleString() : "-";
      const skill = String(row.skill || "-");
      const action = String(row.action || "-");
      const result = String(row.result || "-");
      const by = String(row.triggered_by || "-");
      line.innerHTML =
        '<span class="ts">' + escHtml(tsLabel) + '</span>' +
        '<span class="topic">' + escHtml(skill + " / " + action) + '</span>' +
        '<span class="payload">' + escHtml(result + " (by " + by + ")") + '</span>';
      actionLogStream.appendChild(line);
    });

    if (!entries.length) {
      actionLogStream.innerHTML = '<div class="mqtt-msg"><span class="payload">No action entries yet.</span></div>';
    }

    renderActionHistogram(entries);

    actionLogStatus.textContent =
      "Updated " + ts() + " - entries: " + entries.length +
      (payload.updated_at ? " - source: " + payload.updated_at : "");
  } catch (err) {
    actionLogStatus.textContent = "Action log unavailable: " + err.message;
    showError("network", "Action log fetch failed: " + err.message);
  } finally {
    setLoading("action-log-stream", false);
  }
};

loadActionLog();

document.getElementById("btn-action-log-refresh").addEventListener("click", loadActionLog);

btnConnect.addEventListener("click", () => {
  const c = cfg();
  const host = c.mqttHost;
  const port = c.mqttPort;
  const username = String(c.mqttUsername || "");
  const password = String(c.mqttPassword || "");
  const filter = mqttFilter.value.trim() || "#";

  if (mqttClient) { mqttClient.close(); mqttClient = null; }

  setMqttStatus("connecting", "Connecting to ws://" + host + ":" + port + "…");
  btnConnect.disabled = true;

  const connectVia = (path) => {
    const ws = new WebSocket("ws://" + host + ":" + port + path, ["mqtt"]);
    mqttClient = ws;

    ws.binaryType = "arraybuffer";

    ws.onopen = () => {
      // Build MQTT CONNECT packet from Settings (optional username/password)
      const clientId = "oc-canvas-" + Math.random().toString(36).slice(2, 8);
      const cid = new TextEncoder().encode(clientId);
      const proto = new TextEncoder().encode("MQTT");
      const uname = new TextEncoder().encode(username);
      const pass = new TextEncoder().encode(password);

      let connectFlags = 0x02; // clean session
      if (username) connectFlags |= 0x80;
      if (password) connectFlags |= 0x40;

      const payload = [0x00, cid.length, ...cid];
      if (username) payload.push(0x00, uname.length, ...uname);
      if (password) payload.push(0x00, pass.length, ...pass);

      const pkt = new Uint8Array([
        0x10,
        ...mqttVarInt(10 + payload.length),
        0x00, 0x04, ...proto,
        0x04,
        connectFlags,
        0x00, 0x3c,
        ...payload,
      ]);
      ws.send(pkt);
      setMqttStatus("connecting", username ? "Authenticating with credentials…" : "Authenticating…");
    };

    ws.onmessage = (ev) => {
      const buf = new Uint8Array(typeof ev.data === "string" ? new TextEncoder().encode(ev.data) : ev.data);
      if (buf[0] === 0x20) { // CONNACK
        const rc = buf[3];
        if (rc === 0) {
          setMqttStatus("connected", "Connected (" + path + ") — subscribed to " + filter);
          btnDisconn.disabled = false;
          btnConnect.disabled = false;
          // SUBSCRIBE
          const topic = new TextEncoder().encode(filter);
          const sub = new Uint8Array([
            0x82,                         // SUBSCRIBE
            5 + topic.length,
            0x00, 0x01,                   // packet id
            0x00, topic.length, ...topic,
            0x00,                         // QoS 0
          ]);
          ws.send(sub);
        } else {
          const reasons = ["","Unacceptable protocol","ID rejected","Server unavailable","Bad credentials","Not authorised"];
          setMqttStatus("", "Connection refused: " + (reasons[rc] || "code " + rc));
          appendMqttMsg("system", "CONNACK rc=" + rc + ": " + (reasons[rc] || "unknown"));
          btnConnect.disabled = false;
        }
      } else if ((buf[0] & 0xf0) === 0x30) { // PUBLISH
        let i = 1;
        let rem = 0, mul = 1;
        while (buf[i] & 0x80) { rem += (buf[i++] & 0x7f) * mul; mul *= 128; }
        rem += (buf[i++] & 0x7f);
        const tlen = (buf[i] << 8) | buf[i+1]; i += 2;
        const topic = new TextDecoder().decode(buf.slice(i, i + tlen)); i += tlen;
        const payload = new TextDecoder().decode(buf.slice(i));
        appendMqttMsg(topic, payload);
      } else if (buf[0] === 0xd0) { // PINGRESP — ignore
      }
    };

    ws.onerror = () => {
      if (path === "/mqtt") {
        connectVia("/");
        return;
      }
      setMqttStatus("", "WebSocket error");
      btnConnect.disabled = false;
      btnDisconn.disabled = true;
    };

    ws.onclose = () => {
      if (mqttClient === ws) {
        mqttClient = null;
        setMqttStatus("", "Disconnected");
        btnConnect.disabled = false;
        btnDisconn.disabled = true;
      }
    };
  };

  connectVia("/mqtt");
});

btnDisconn.addEventListener("click", () => {
  if (mqttClient) { mqttClient.close(); mqttClient = null; }
});

document.getElementById("btn-mqtt-clear").addEventListener("click", () => { mqttStream.innerHTML = ""; });

document.getElementById("btn-mqtt-publish").addEventListener("click", () => {
  const topic   = document.getElementById("pub-topic").value.trim();
  const payload = document.getElementById("pub-payload").value;
  const statusEl = document.getElementById("mqtt-publish-status");
  if (!topic) { statusEl.textContent = "Topic is required."; return; }
  if (!mqttClient || mqttClient.readyState !== WebSocket.OPEN) {
    statusEl.textContent = "Not connected."; return;
  }
  const t = new TextEncoder().encode(topic);
  const p = new TextEncoder().encode(payload);
  const pkt = new Uint8Array([
    0x30,                              // PUBLISH QoS0
    ...mqttVarInt(2 + t.length + p.length),
    0x00, t.length, ...t,
    ...p,
  ]);
  mqttClient.send(pkt);
  statusEl.textContent = "Published to " + topic + " at " + ts();
});

  };

  return { register, initPage };
})();
