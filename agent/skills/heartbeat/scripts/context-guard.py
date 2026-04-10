#!/usr/bin/env python3
"""
context-guard.py — Erkennt hohe Context-Nutzung und triggert Session-Rotate.

Usage:
    python3 context-guard.py <used_tokens> <max_tokens> [--threshold 0.8]

Output:
    [ROTATE_NEEDED]   + Handoff-Hinweis  (exit 0)
    [ROTATE_NOT_NEEDED] ratio=x.xxx      (exit 0)
"""

import sys
import argparse


def main() -> None:
    parser = argparse.ArgumentParser(description="Context threshold guard")
    parser.add_argument("used_tokens", type=int, nargs="?", default=0)
    parser.add_argument("max_tokens", type=int, nargs="?", default=200000)
    parser.add_argument("--threshold", type=float, default=0.8)
    args = parser.parse_args()

    used = max(0, args.used_tokens)
    max_t = max(1, args.max_tokens)
    threshold = max(0.0, min(1.0, args.threshold))

    ratio = used / max_t

    if ratio >= threshold:
        print("[ROTATE_NEEDED]")
        print(
            f"[NEW_SESSION] Context {ratio:.0%} ({used}/{max_t}) — "
            "bitte neue Session starten"
        )
        print("[HANDOFF_HINT] Laufende Tasks in Handover dokumentieren vor Session-Ende.")
    else:
        print(f"[ROTATE_NOT_NEEDED] ratio={ratio:.3f} < {threshold:.3f}")


if __name__ == "__main__":
    main()
