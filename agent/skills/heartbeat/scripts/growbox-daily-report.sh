#!/bin/bash
# growbox-daily-report.sh — Thin Wrapper (kanonisch in growbox skill)
# Direkte Nutzung: ~/scripts/skills growbox daily-report
set -euo pipefail
exec "/home/steges/agent/skills/growbox/scripts/growbox-daily-report.sh" "$@"
