#!/bin/bash
# ================================================
# Run this on your HOME PC to expose the backend
# to the internet so your phone can reach it.
#
# Usage:
#   ./start-home.sh                  (api.py in same folder)
#   ./start-home.sh /path/to/api.py  (custom path)
# ================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  AI Signal Desk — Remote Access Startup   ${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# ---- Find Python ----
if command -v python3 &>/dev/null; then PYTHON=python3
elif command -v python &>/dev/null; then  PYTHON=python
else echo -e "${RED}❌ Python not found.${NC}"; exit 1; fi

API_PATH="${1:-api.py}"

# ---- Start Python backend ----
if [ ! -f "$API_PATH" ]; then
  echo -e "${RED}❌ Cannot find: $API_PATH${NC}"
  echo "   Usage: ./start-home.sh /path/to/api.py"
  exit 1
fi

echo -e "${GREEN}▶ Starting backend: $API_PATH${NC}"
$PYTHON "$API_PATH" &
BACKEND_PID=$!
sleep 2

if kill -0 $BACKEND_PID 2>/dev/null; then
  echo -e "${GREEN}✅ Backend running on port 5000 (PID $BACKEND_PID)${NC}"
else
  echo -e "${RED}❌ Backend crashed. Check api.py for errors.${NC}"
  exit 1
fi

echo ""

# ---- Start tunnel ----
if command -v ngrok &>/dev/null; then
  echo -e "${GREEN}▶ Starting ngrok tunnel...${NC}"
  echo ""
  echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║  Copy the https URL from ngrok output    ║${NC}"
  echo -e "${BLUE}║  Open app on phone → tap ⚙ → paste URL  ║${NC}"
  echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
  echo ""
  cleanup() { kill $BACKEND_PID 2>/dev/null; }
  trap cleanup EXIT INT TERM
  ngrok http 5000

elif command -v lt &>/dev/null || npx --yes localtunnel --version &>/dev/null 2>&1; then
  SUBDOMAIN="trading-api-$USER"
  echo -e "${GREEN}▶ Starting localtunnel (subdomain: $SUBDOMAIN)...${NC}"
  echo ""
  echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║  Your URL: https://${SUBDOMAIN}.loca.lt              ║${NC}"
  echo -e "${BLUE}║  Open app on phone → tap ⚙ → paste this URL         ║${NC}"
  echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
  echo ""
  cleanup() { kill $BACKEND_PID 2>/dev/null; }
  trap cleanup EXIT INT TERM
  npx localtunnel --port 5000 --subdomain "$SUBDOMAIN"

else
  echo -e "${YELLOW}⚠️  No tunnel tool found. Install one:${NC}"
  echo ""
  echo "   Option A — ngrok (recommended, free static domain):"
  echo "     https://ngrok.com/download"
  echo "     ngrok config add-authtoken YOUR_TOKEN"
  echo "     ngrok http 5000"
  echo ""
  echo "   Option B — localtunnel (no account needed):"
  echo "     npm install -g localtunnel"
  echo "     lt --port 5000 --subdomain trading-api-mine"
  echo ""
  echo -e "${GREEN}Backend is running on port 5000.${NC}"
  echo "Start a tunnel manually and paste the URL into ⚙ on your phone."
  wait $BACKEND_PID
fi
