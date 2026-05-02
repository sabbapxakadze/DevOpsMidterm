#!/bin/bash
# deploy.sh — Blue-Green deployment script

set -e

BLUE_PORT=3000
GREEN_PORT=3001
ACTIVE_FILE=".active"
LOG_DIR="logs"
mkdir -p "$LOG_DIR"

git rev-parse HEAD > .prev_commit 2>/dev/null || true

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

NEXT_PID_FILE=".${NEXT}_pid"
CURR_PID_FILE=".${CURRENT}_pid"

echo "=== Blue-Green Deploy ==="
echo "Active slot : $CURRENT (port $CURR_PORT)"
echo "Deploy to   : $NEXT  (port $NEXT_PORT)"
echo ""

# Kill any leftover process on the target port
echo "[1/4] Clearing port $NEXT_PORT..."
if [ -f "$NEXT_PID_FILE" ]; then
  kill "$(cat "$NEXT_PID_FILE")" 2>/dev/null && echo "  Killed previous $NEXT process" || true
  rm -f "$NEXT_PID_FILE"
else
  echo "  Port was free"
fi

# Start app on the new slot
echo "[2/4] Starting $NEXT environment (v2.0.0)..."
APP_VERSION="2.0.0" PORT="$NEXT_PORT" nohup node app/index.js > "$LOG_DIR/${NEXT}.log" 2>&1 &
echo $! > "$NEXT_PID_FILE"
sleep 2

# Health check
echo "[3/4] Health checking port $NEXT_PORT..."
HEALTH=$(curl -s --max-time 5 "http://localhost:$NEXT_PORT/health" || echo "FAIL")

if echo "$HEALTH" | grep -q '"status":"ok"'; then
  echo "  Health check passed: $HEALTH"

  echo "$NEXT" > "$ACTIVE_FILE"

  echo "[4/4] Stopping old slot ($CURRENT, port $CURR_PORT)..."
  if [ -f "$CURR_PID_FILE" ]; then
    OLD_PID=$(cat "$CURR_PID_FILE")
    kill "$OLD_PID" 2>/dev/null && echo "  Stopped PID $OLD_PID" || true
    rm -f "$CURR_PID_FILE"
  else
    echo "  No PID file for $CURRENT slot"
  fi

  echo ""
  echo "Deploy complete. Active slot is now: $NEXT (port $NEXT_PORT)"
  echo "Logged to: $LOG_DIR/${NEXT}.log"
else
  echo "  Health check FAILED. Response: $HEALTH"
  echo "  Aborting — $CURRENT slot stays live."
  kill "$(cat "$NEXT_PID_FILE" 2>/dev/null)" 2>/dev/null || true
  rm -f "$NEXT_PID_FILE"
  exit 1
fi
