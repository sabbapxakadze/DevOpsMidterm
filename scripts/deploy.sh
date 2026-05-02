#!/bin/bash
# deploy.sh — Blue-Green deployment script
#
# Blue runs on port 3000, Green on port 3001.
# .active tracks which slot is live.
# On each deploy: start the idle slot, health-check it,
# then cut over and stop the old slot.

set -e

BLUE_PORT=3000
GREEN_PORT=3001
ACTIVE_FILE=".active"
LOG_DIR="logs"
mkdir -p "$LOG_DIR"

# Save current git commit for rollback
git rev-parse HEAD > .prev_commit 2>/dev/null || true

# Read current active slot
CURRENT=$(cat "$ACTIVE_FILE" 2>/dev/null || echo "blue")

if [ "$CURRENT" = "blue" ]; then
  NEXT="green"
  NEXT_PORT=$GREEN_PORT
  CURR_PORT=$BLUE_PORT
else
  NEXT="blue"
  NEXT_PORT=$BLUE_PORT
  CURR_PORT=$GREEN_PORT
fi

echo "=== Blue-Green Deploy ==="
echo "Active slot : $CURRENT (port $CURR_PORT)"
echo "Deploy to   : $NEXT  (port $NEXT_PORT)"

# Kill any leftover process on the target port
echo ""
echo "[1/4] Clearing port $NEXT_PORT..."
fuser -k "$NEXT_PORT/tcp" 2>/dev/null && echo "  Killed existing process" || echo "  Port was free"

# Start app on the new slot
echo "[2/4] Starting $NEXT environment..."
APP_VERSION="2.0.0" PORT="$NEXT_PORT" nohup node app/index.js > "$LOG_DIR/$NEXT.log" 2>&1 &
echo $! > ".$NEXT_pid"
sleep 2

# Health check
echo "[3/4] Health checking port $NEXT_PORT..."
HEALTH=$(curl -s --max-time 5 "http://localhost:$NEXT_PORT/health" || echo "FAIL")

if echo "$HEALTH" | grep -q '"status":"ok"'; then
  echo "  Health check passed: $HEALTH"

  # Switch over
  echo "$NEXT" > "$ACTIVE_FILE"

  # Stop old slot
  echo "[4/4] Stopping old slot ($CURRENT, port $CURR_PORT)..."
  OLD_PID_FILE=".$CURRENT_pid"
  if [ -f "$OLD_PID_FILE" ]; then
    OLD_PID=$(cat "$OLD_PID_FILE")
    kill "$OLD_PID" 2>/dev/null && echo "  Stopped PID $OLD_PID" || true
    rm -f "$OLD_PID_FILE"
  else
    fuser -k "$CURR_PORT/tcp" 2>/dev/null || true
  fi

  echo ""
  echo "Deploy complete. Active slot is now: $NEXT (port $NEXT_PORT)"
  echo "Logged to: $LOG_DIR/$NEXT.log"
else
  echo "  Health check FAILED. Response: $HEALTH"
  echo "  Aborting — $CURRENT slot stays live."
  kill "$(cat .$NEXT_pid 2>/dev/null)" 2>/dev/null || fuser -k "$NEXT_PORT/tcp" 2>/dev/null || true
  rm -f ".$NEXT_pid"
  exit 1
fi
