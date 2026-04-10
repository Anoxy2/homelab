#!/usr/bin/env python3
"""
Chat Bridge — POST /api/chat → openclaw agent CLI

Bridget den Canvas-UI-Chat-Endpunkt (/api/chat) zum OpenClaw-Agent-CLI.
Das OpenClaw-Gateway bietet keinen /api/chat REST-Endpunkt; die CLI im
Container ist der einzig zuverlässige synchrone Zugang.

Port: 127.0.0.1:18792 (nur lokal; Caddy proxied von openclaw.lan/api/chat)
"""

import http.server
import json
import logging
import subprocess
import sys

PORT = 18792
BIND = "127.0.0.1"
AGENT_ID = "main"
TIMEOUT_SECONDS = 120

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [chat-bridge] %(message)s",
    stream=sys.stdout,
)
log = logging.getLogger()

CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
}


class ChatHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        log.info(fmt % args)

    def _send(self, status=200, body=b"", content_type="application/json"):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        for k, v in CORS_HEADERS.items():
            self.send_header(k, v)
        self.end_headers()
        if body:
            self.wfile.write(body)

    def do_OPTIONS(self):
        # CORS preflight
        self._send(204)

    def do_POST(self):
        if self.path != "/api/chat":
            self._send(404, json.dumps({"error": "not found"}).encode())
            return

        try:
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length)
            data = json.loads(body)
            message = str(data.get("message", "")).strip()
        except Exception as exc:
            log.error("Bad request body: %s", exc)
            self._send(400, json.dumps({"error": "bad request"}).encode())
            return

        if not message:
            self._send(400, json.dumps({"error": "message required"}).encode())
            return

        log.info("→ agent: %r", message[:100])

        try:
            result = subprocess.run(
                [
                    "docker", "exec", "openclaw",
                    "openclaw", "agent",
                    "--agent", AGENT_ID,
                    "--message", message,
                    "--json",
                ],
                capture_output=True,
                text=True,
                timeout=TIMEOUT_SECONDS,
            )
            resp = json.loads(result.stdout)
            payloads = resp.get("result", {}).get("payloads", [])
            reply = payloads[0].get("text", "") if payloads else ""
            if not reply:
                summary = resp.get("summary", "")
                reply = f"[status: {resp.get('status', 'unknown')}{' – ' + summary if summary else ''}]"
        except subprocess.TimeoutExpired:
            log.error("Agent timeout (%ds)", TIMEOUT_SECONDS)
            reply = f"Timeout: Agent hat nach {TIMEOUT_SECONDS}s nicht geantwortet."
        except json.JSONDecodeError as exc:
            log.error("JSON parse error: %s | stdout: %r", exc, result.stdout[:200])
            reply = f"Fehler beim Parsen der Agent-Antwort: {exc}"
        except Exception as exc:
            log.error("Agent call failed: %s", exc)
            reply = f"Fehler: {exc}"

        log.info("← reply: %r", reply[:100])
        self._send(200, json.dumps({"reply": reply}).encode())


if __name__ == "__main__":
    server = http.server.HTTPServer((BIND, PORT), ChatHandler)
    log.info("Chat-Bridge listening on %s:%d (agent=%s, timeout=%ds)",
             BIND, PORT, AGENT_ID, TIMEOUT_SECONDS)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log.info("Shutting down")
