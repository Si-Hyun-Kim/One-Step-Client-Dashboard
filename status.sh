#!/bin/bash
# status.sh - One Step Security System 상태 확인

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════╗
║   📊 One Step Security System Status         ║
╚═══════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# PID 파일 확인
if [ -f ".pids" ]; then
    source .pids
else
    echo -e "${YELLOW}⚠  PID 파일이 없습니다. 서비스가 실행 중이 아닐 수 있습니다.${NC}"
    echo ""
fi

# 프로세스 상태 확인 함수
check_process() {
    local name=$1
    local pid=$2
    local process_name=$3
    
    # PID로 확인
    if [ ! -z "$pid" ] && ps -p $pid > /dev/null 2>&1; then
        local uptime=$(ps -o etime= -p $pid | tr -d ' ')
        local mem=$(ps -o rss= -p $pid | awk '{printf "%.1f MB", $1/1024}')
        local cpu=$(ps -o %cpu= -p $pid | tr -d ' ')
        echo -e "  ${GREEN}●${NC} ${name}"
        echo -e "      PID     : ${pid}"
        echo -e "      Uptime  : ${uptime}"
        echo -e "      Memory  : ${mem}"
        echo -e "      CPU     : ${cpu}%"
        return 0
    # 프로세스 이름으로 확인
    elif pgrep -f "$process_name" > /dev/null 2>&1; then
        local found_pid=$(pgrep -f "$process_name" | head -n 1)
        local uptime=$(ps -o etime= -p $found_pid | tr -d ' ')
        local mem=$(ps -o rss= -p $found_pid | awk '{printf "%.1f MB", $1/1024}')
        local cpu=$(ps -o %cpu= -p $found_pid | tr -d ' ')
        echo -e "  ${GREEN}●${NC} ${name}"
        echo -e "      PID     : ${found_pid}"
        echo -e "      Uptime  : ${uptime}"
        echo -e "      Memory  : ${mem}"
        echo -e "      CPU     : ${cpu}%"
        return 0
    else
        echo -e "  ${RED}●${NC} ${name}"
        echo -e "      Status  : ${RED}Not Running${NC}"
        return 1
    fi
}

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}서비스 상태${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

SERVICES_OK=0
SERVICES_FAIL=0

# MCP Server
if check_process "MCP Server" "$MCP_SERVER" "mcp_suricata_server.py"; then
    ((SERVICES_OK++))
else
    ((SERVICES_FAIL++))
fi
echo ""

# MCP Agent
if check_process "MCP Agent" "$AGENT" "mcp_agent.py"; then
    ((SERVICES_OK++))
else
    ((SERVICES_FAIL++))
fi
echo ""

# Dashboard
if check_process "Web Dashboard" "$DASHBOARD" "node server.js"; then
    ((SERVICES_OK++))
else
    ((SERVICES_FAIL++))
fi
echo ""

# 포트 확인
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}네트워크 상태${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if netstat -tuln 2>/dev/null | grep -q ":3100 "; then
    echo -e "  ${GREEN}●${NC} Port 3100 (Dashboard) - LISTENING"
else
    echo -e "  ${RED}●${NC} Port 3100 (Dashboard) - NOT LISTENING"
fi

echo ""

# 로그 파일 확인
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}로그 파일${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ -d "logs" ]; then
    for log in logs/*.log; do
        if [ -f "$log" ]; then
            local size=$(du -h "$log" 2>/dev/null | cut -f1)
            local lines=$(wc -l < "$log" 2>/dev/null)
            echo -e "  📄 $(basename $log)"
            echo -e "      Size  : ${size}"
            echo -e "      Lines : ${lines}"
        fi
    done
else
    echo -e "  ${YELLOW}⚠${NC} logs/ 디렉토리 없음"
fi

if [ -d "agent/logs" ] && [ -f "agent/logs/agent_actions.log" ]; then
    local size=$(du -h "agent/logs/agent_actions.log" 2>/dev/null | cut -f1)
    local lines=$(wc -l < "agent/logs/agent_actions.log" 2>/dev/null)
    echo ""
    echo -e "  📄 agent_actions.log"
    echo -e "      Size  : ${size}"
    echo -e "      Lines : ${lines}"
fi

echo ""

# 차단된 IP 확인 (iptables)
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}방화벽 규칙${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if command -v iptables &> /dev/null; then
    local blocked_count=$(sudo iptables -L INPUT -n 2>/dev/null | grep -c "DROP" || echo "0")
    echo -e "  🔒 차단된 IP: ${RED}${blocked_count}${NC}개"
    
    if [ "$blocked_count" -gt 0 ]; then
        echo ""
        echo -e "  최근 차단된 IP (최대 5개):"
        sudo iptables -L INPUT -n 2>/dev/null | grep "DROP" | head -5 | while read line; do
            echo -e "    ${RED}▸${NC} $(echo $line | awk '{print $4}')"
        done
    fi
else
    echo -e "  ${YELLOW}⚠${NC} iptables를 찾을 수 없습니다"
fi

echo ""

# 요약
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}요약${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  실행 중인 서비스: ${GREEN}${SERVICES_OK}${NC} / $((SERVICES_OK + SERVICES_FAIL))"

if [ $SERVICES_OK -eq 3 ]; then
    echo -e "  전체 상태: ${GREEN}✓ All Systems Operational${NC}"
elif [ $SERVICES_OK -gt 0 ]; then
    echo -e "  전체 상태: ${YELLOW}⚠ Partial Outage${NC}"
else
    echo -e "  전체 상태: ${RED}✗ All Services Down${NC}"
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}명령어${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  시작    : ${YELLOW}./start.sh${NC}"
echo -e "  정지    : ${YELLOW}./stop.sh${NC}"
echo -e "  재시작  : ${YELLOW}./restart.sh${NC}"
echo -e "  로그    : ${YELLOW}tail -f logs/*.log${NC}"
echo ""

if [ $SERVICES_OK -gt 0 ]; then
    echo -e "  Dashboard: ${GREEN}http://localhost:3100${NC}"
    echo ""
fi