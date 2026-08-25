#!/usr/bin/env bash
set -euo pipefail

RUN_AT="${1:-30 3 * * *}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$REPO_DIR/logs"
mkdir -p "$LOG_DIR"
CRON_LINE="$RUN_AT cd $REPO_DIR && ./scripts/backup-online.sh >> $LOG_DIR/backup-online.log 2>&1"
( crontab -l 2>/dev/null | grep -Fv './scripts/backup-online.sh' || true; echo "$CRON_LINE" ) | crontab -
echo "Installed cron entry: $CRON_LINE"
