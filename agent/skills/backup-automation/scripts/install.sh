#!/bin/bash
# install.sh - Install backup-automation skill

set -euo pipefail

readonly SKILL_ROOT="/home/steges/agent/skills/backup-automation"
readonly SYSTEMD_USER_DIR="/etc/systemd/system"

echo "=========================================="
echo "Backup-Automation Skill Installer"
echo "=========================================="
echo ""

# Check root for systemd
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (for systemd services)"
   echo "Usage: sudo $0"
   exit 1
fi

# Check if skill exists
if [[ ! -d "$SKILL_ROOT" ]]; then
    echo "ERROR: Skill not found at $SKILL_ROOT"
    exit 1
fi

echo "[1/5] Setting permissions..."
chmod +x "$SKILL_ROOT/scripts/"*.sh
echo "  ✓ Scripts made executable"

echo ""
echo "[2/5] Installing systemd services..."

# Link services
for service in "$SKILL_ROOT/systemd/"*.service; do
    if [[ -f "$service" ]]; then
        name=$(basename "$service")
        if [[ -L "$SYSTEMD_USER_DIR/$name" ]] || [[ -f "$SYSTEMD_USER_DIR/$name" ]]; then
            rm -f "$SYSTEMD_USER_DIR/$name"
        fi
        ln -s "$service" "$SYSTEMD_USER_DIR/$name"
        echo "  ✓ Installed: $name"
    fi
done

# Link timers
for timer in "$SKILL_ROOT/systemd/"*.timer; do
    if [[ -f "$timer" ]]; then
        name=$(basename "$timer")
        if [[ -L "$SYSTEMD_USER_DIR/$name" ]] || [[ -f "$SYSTEMD_USER_DIR/$name" ]]; then
            rm -f "$SYSTEMD_USER_DIR/$name"
        fi
        ln -s "$timer" "$SYSTEMD_USER_DIR/$name"
        echo "  ✓ Installed: $name"
    fi
done

echo ""
echo "[3/5] Creating state directory..."
mkdir -p "$SKILL_ROOT/.state"
chown steges:steges "$SKILL_ROOT/.state"
echo "  ✓ State directory ready"

echo ""
echo "[4/5] Reloading systemd..."
systemctl daemon-reload
echo "  ✓ systemd reloaded"

echo ""
echo "[5/5] Enabling services..."
systemctl enable backup-automation.timer 2>/dev/null && echo "  ✓ backup-automation.timer enabled" || echo "  ⚠ backup-automation.timer failed"
systemctl enable backup-github-check.timer 2>/dev/null && echo "  ✓ backup-github-check.timer enabled" || echo "  ⚠ backup-github-check.timer failed"
systemctl enable backup-verify.timer 2>/dev/null && echo "  ✓ backup-verify.timer enabled" || echo "  ⚠ backup-verify.timer failed"

echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "Status check:"
systemctl list-timers backup-* 2>/dev/null || true
echo ""
echo "Next steps:"
echo "  1. Configure USB mount in /etc/fstab"
echo "     (see docs/infrastructure/backup-strategy.md)"
echo "  2. Start timers:"
echo "     sudo systemctl start backup-automation.timer"
echo "  3. Test backup:"
echo "     $SKILL_ROOT/scripts/backup-full.sh"
echo ""
echo "Logs: tail -f /var/log/backup-automation.log"
