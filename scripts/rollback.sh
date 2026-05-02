#!/bin/bash
# rollback.sh — Revert to the previous deployment

set -e

ACTIVE_FILE=".active"
PREV_COMMIT_FILE=".prev_commit"
LOG_DIR="logs"
mkdir -p "$LOG_DIR"

CURRENT=$(cat "$ACTIVE_FILE" 2>/dev/null || echo "blue")
if [ "$CURRENT" = "blue" ]; then
  PROD_PORT=3000
else
  PROD_PORT=3001
fi

CURR_PID_FILE=".${CURRENT}_pid"

echo "=== Rollback ==="
echo "Current active: $CURRENT (port $PROD_PORT)"

if [ ! -f "$PREV_COMMIT_FILE" ]; then
  echo "No .prev_commit file found — nothing to roll back to."
  exit 1
fi

PREV=$(cat "$PREV_COMMIT_FILE")
CURRENT_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")

echo "Current commit : $CURRENT_COMMIT"
echo "Rolling back to: $PREV"
echo ""

echo "[1/3] Stopping current app on port $PROD_PORT..."
if [ -f "$CURR_PID_FILE" ]; then
  kill "$(cat "$CURR_PID_FILE")" 2>/dev/null && echo "  Stopped" || true
  rm -f "$CURR_PID_FILE"
else
  echo "  No PID file found, port may already be free"
fi

echo "[2/3] Checking out previous commit ($PREV)..."
git checkout "$PREV" -- app/ 2>/dev/null || {
  echo "Could not checkout $PREV. Make sure the commit exists."
  exit 1
}

echo "[3/3] Restarting app (v1.0.0) on port $PROD_PORT..."
APP_VERSION="1.0.0" PORT="$PROD_PORT" nohup node app/index.js > "$LOG_DIR/rollback.log" 2>&1 &
echo $! > "$CURR_PID_FILE"
sleep 2

HEALTH=$(curl -s --max-time 5 "http://localhost:$PROD_PORT/health" || echo "FAIL")
if echo "$HEALTH" | grep -q '"status":"ok"'; then
  echo ""
  echo "Rollback successful. App is running on port $PROD_PORT."
  echo "Version: $(echo "$HEALTH" | grep -o '"version":"[^"]*"')"
else
  echo "WARNING: App started but health check returned: $HEALTH"
fi
