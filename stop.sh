#!/bin/bash
# stop.sh - One Step Security System 정지

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════╗"
echo "║   🛑 Stopping Security System...      ║"
echo "╚═══════════════════════════════════════╝"
echo -e "${NC}"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# PID 파일 읽기
if [ -f ".pids" ]; then
    source .pids
    
    # MCP Server 정지
    if [ ! -z "$MCP_SERVER" ] && ps -p $MCP_SERVER > /dev/null 2>&1; then
        echo -e "${YELLOW}[●] MCP Server 정지 중... (PID: $MCP_SERVER)${NC}"
        kill $MCP_SERVER 2>/dev/null || true
        sleep 1
        if ps -p $MCP_SERVER > /dev/null 2>&1; then
            kill -9 $MCP_SERVER 2>/dev/null || true
        fi
        echo -e "    ${GREEN}✓${NC} MCP Server 정지됨"
    fi
    
    # Agent 정지
    if [ ! -z "$AGENT" ] && ps -p $AGENT > /dev/null 2>&1; then
        echo -e "${YELLOW}[●] MCP Agent 정지 중... (PID: $AGENT)${NC}"
        kill $AGENT 2>/dev/null || true
        sleep 1
        if ps -p $AGENT > /dev/null 2>&1; then
            kill -9 $AGENT 2>/dev/null || true
        fi
        echo -e "    ${GREEN}✓${NC} MCP Agent 정지됨"
    fi
    
    # Dashboard 정지
    if [ ! -z "$DASHBOARD" ] && ps -p $DASHBOARD > /dev/null 2>&1; then
        echo -e "${YELLOW}[●] Dashboard 정지 중... (PID: $DASHBOARD)${NC}"
        kill $DASHBOARD 2>/dev/null || true
        sleep 1
        if ps -p $DASHBOARD > /dev/null 2>&1; then
            kill -9 $DASHBOARD 2>/dev/null || true
        fi
        echo -e "    ${GREEN}✓${NC} Dashboard 정지됨"
    fi
    
    rm -f .pids
fi

# 프로세스 이름으로도 정리 (혹시 모르니)
echo ""
echo -e "${YELLOW}[●] 남은 프로세스 정리 중...${NC}"

pkill -f "mcp_suricata_server.py" 2>/dev/null && echo -e "    ${GREEN}✓${NC} MCP Server 정리" || true
pkill -f "mcp_agent.py" 2>/dev/null && echo -e "    ${GREEN}✓${NC} MCP Agent 정리" || true
pkill -f "node server.js" 2>/dev/null && echo -e "    ${GREEN}✓${NC} Node.js 정리" || true

sleep 1

echo ""
echo -e "${GREEN}✅ 모든 서비스가 정지되었습니다.${NC}"
echo ""