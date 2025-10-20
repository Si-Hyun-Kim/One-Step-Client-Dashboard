#!/bin/bash
# restart.sh - One Step Security System 재시작

CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════╗"
echo "║   🔄 Restarting Security System...    ║"
echo "╚═══════════════════════════════════════╝"
echo -e "${NC}"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# 정지
./stop.sh

echo ""
echo "⏳ 3초 대기 중..."
sleep 3

# 시작
./start.sh