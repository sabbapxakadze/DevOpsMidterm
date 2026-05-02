#!/bin/bash
# rollback.sh — Revert to the previous deployment
#
# Reads the commit hash saved by deploy.sh, checks it out,
# and restarts the app on the production port.

set -e

ACTIVE_FILE=".active"
PREV_COMMIT_FILE=".prev_commit"
LOG_DIR="logs"
mkdir -p "$LOG_DIR"

# Determine which port is currently live
CURRENT=$(cat "$ACTIVE_FILE" 2>/dev/null || echo "blue")
if [ "$CURRENT" = "blue" ]; then
  PROD_PORT=3000
else
  PROD_PORT=3001
fi

echo "=== Rollback ==="
echo "Current active: $CURRENT (port $PROD_PORT)"

# Check we have a previous commit to roll back to
if [ ! -f "$PREV_COMMIT_FILE" ]; then
  echo "No .prev_commit file found — nothing to roll back to."
  exit 1
fi

PREV=$(cat "$PREV_COMMIT_FILE")
CURRENT_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")

echo "Current commit : $CURRENT_COMMIT"
echo "Rolling back to: $PREV"
echo ""

# Stop current process
echo "[1/3] Stopping current app on port $PROD_PORT..."
PID_FILE=".$CURRENT_pid"
if [ -f "$PID_FILE" ]; then
  kill "$(cat "$PID_FILE")" 2>/dev/null && echo "  Stopped" || true
  rm -f "$PID_FILE"
else
  fuser -k "$PROD_PORT/tcp" 2>/dev/null || echo "  Nothing running on $PROD_PORT"
fi

# Checkout previous commit
echo "[2/3] Checking out previous commit ($PREV)..."
git checkout "$PREV" -- app/ 2>/dev/null || {
  echo "Could not checkout $PREV. Make sure the commit exists."
  exit 1
}

# Restart app
echo "[3/3] Restarting app (v1.0.0) on port $PROD_PORT..."
APP_VERSION="1.0.0" PORT="$PROD_PORT" nohup node app/index.js > "$LOG_DIR/rollback.log" 2>&1 &
echo $! > "$PID_FILE"
sleep 2

HEALTH=$(curl -s --max-time 5 "http://localhost:$PROD_PORT/health" || echo "FAIL")
if echo "$HEALTH" | grep -q '"status":"ok"'; then
  echo ""
  echo "Rollback successful. App is running on port $PROD_PORT."
  echo "Version in health response: $(echo $HEALTH | grep -o '"version":"[^"]*"')"
else
  echo "WARNING: App started but health check returned: $HEALTH"
fi
