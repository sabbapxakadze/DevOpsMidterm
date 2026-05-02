#!/bin/bash
# setup.sh — single-command environment preparation

set -e

echo "=== Environment Setup ==="

# Install Node.js 18 if missing
if ! command -v node &>/dev/null; then
  echo "[1/4] Node.js not found — installing..."
  curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
  sudo apt-get install -y nodejs
else
  echo "[1/4] Node.js $(node -v) already installed"
fi

# Install project dependencies
echo "[2/4] Installing npm dependencies..."
npm ci

# Create required directories
echo "[3/4] Creating directories..."
mkdir -p logs

# Write default .active file if missing
if [ ! -f .active ]; then
  echo "blue" > .active
fi

echo "[4/4] Done."
echo ""
echo "Run the app:   npm start"
echo "Run tests:     npm test"
echo "Run linter:    npm run lint"
echo "Deploy:        bash scripts/deploy.sh"
echo "Health check:  bash scripts/healthcheck.sh"
