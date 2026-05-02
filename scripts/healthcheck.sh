#!/bin/bash
# healthcheck.sh — Periodically checks the app and logs results
#
# Usage: bash scripts/healthcheck.sh [port] [interval_seconds]
# Defaults: port=3000, interval=30

PORT="${1:-3000}"
INTERVAL="${2:-30}"
LOG_DIR="logs"
LOG_FILE="$LOG_DIR/health.log"

mkdir -p "$LOG_DIR"

echo "Starting health monitor — port $PORT, every ${INTERVAL}s"
echo "Logging to: $LOG_FILE"
echo "Press Ctrl+C to stop."
echo ""

check() {
  TS=$(date '+%Y-%m-%d %H:%M:%S')
  RESPONSE=$(curl -s --max-time 5 "http://localhost:$PORT/health" 2>/dev/null)

  if [ -z "$RESPONSE" ]; then
    STATUS="FAIL"
    DETAIL="No response (app may be down)"
  elif echo "$RESPONSE" | grep -q '"status":"ok"'; then
    STATUS="OK"
    VERSION=$(echo "$RESPONSE" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
    UPTIME=$(echo "$RESPONSE" | grep -o '"uptime":[0-9]*' | cut -d':' -f2)
    DETAIL="version=$VERSION uptime=${UPTIME}s"
  else
    STATUS="WARN"
    DETAIL="Unexpected response: $RESPONSE"
  fi

  LOG_LINE="[$TS] [$STATUS] $DETAIL"
  echo "$LOG_LINE"
  echo "$LOG_LINE" >> "$LOG_FILE"
}

while true; do
  check
  sleep "$INTERVAL"
done
