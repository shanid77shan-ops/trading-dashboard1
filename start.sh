#!/bin/bash
# ================================================
# AI Signal Desk — One-command startup
# Usage:
#   ./start.sh                  (api.py in same folder)
#   ./start.sh /path/to/api.py  (custom path)
#   ./start.sh --phone          (accessible from phone on same WiFi)
# ================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  AI Signal Desk — Starting Up        ${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

PHONE_MODE=false
API_PATH="api.py"

for arg in "$@"; do
  case $arg in
    --phone) PHONE_MODE=true ;;
    *.py) API_PATH="$arg" ;;
  esac
done

# ---- Find Python ----
if command -v python3 &>/dev/null; then
  PYTHON=python3
elif command -v python &>/dev/null; then
  PYTHON=python
else
  echo -e "${RED}❌ Python not found. Install Python 3 first.${NC}"
  exit 1
fi

# ---- Start Python backend ----
if [ -f "$API_PATH" ]; then
  echo -e "${GREEN}▶ Starting Python backend: $API_PATH${NC}"
  $PYTHON "$API_PATH" &
  BACKEND_PID=$!
  sleep 2

  if kill -0 $BACKEND_PID 2>/dev/null; then
    echo -e "${GREEN}✅ Backend running (PID $BACKEND_PID)${NC}"
  else
    echo -e "${YELLOW}⚠️  Backend may have crashed — check api.py for errors${NC}"
    BACKEND_PID=""
  fi
else
  echo -e "${YELLOW}⚠️  $API_PATH not found — starting frontend only${NC}"
  echo "   Pass path: ./start.sh /path/to/api.py"
  BACKEND_PID=""
fi

echo ""

# ---- Phone mode: show local IP ----
if $PHONE_MODE; then
  LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "unknown")
  echo -e "${BLUE}📱 Phone mode enabled${NC}"
  echo -e "   Open on your phone: ${GREEN}http://${LOCAL_IP}:3000${NC}"
  echo -e "   Backend URL: ${GREEN}http://${LOCAL_IP}:5000${NC}"
  echo ""
  echo -e "${YELLOW}   → Set REACT_APP_API_URL=http://${LOCAL_IP}:5000 in .env${NC}"
  echo ""
  export HOST=0.0.0.0
  export REACT_APP_API_URL="http://${LOCAL_IP}:5000"
fi

# ---- Start React frontend ----
echo -e "${GREEN}▶ Starting React frontend...${NC}"
echo ""

cleanup() {
  echo ""
  echo "Shutting down..."
  [ -n "$BACKEND_PID" ] && kill $BACKEND_PID 2>/dev/null && echo "Backend stopped."
}
trap cleanup EXIT INT TERM

npm start
