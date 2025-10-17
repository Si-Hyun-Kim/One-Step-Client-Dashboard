#!/bin/bash
# start.sh - One Step Security System Launcher

set -e  # 에러 발생 시 중단

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 로고
echo -e "${CYAN}"
echo "========================================"
echo ""
echo "    ONE STEP SECURITY SYSTEM"
echo ""
echo "  Automated Security Dashboard & Agent"
echo "          Version 2.0.0"
echo ""
echo "========================================"
echo -e "${NC}"

# 스크립트 디렉토리
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# ============================================
# 0. 스크립트 파일 실행 권한 확인 및 부여
# ============================================

echo -e "${BLUE}[0/9] Checking script permissions...${NC}"

# 확인할 스크립트 파일 목록
SCRIPT_FILES=(
    "stop.sh"
    "restart.sh"
    "status.sh"
    "fix-permissions.sh"
    "agent/setup.sh"
    "agent/check.sh"
    "agent/mcp_agent.py"
)

FIXED_COUNT=0

for script in "${SCRIPT_FILES[@]}"; do
    if [ -f "$script" ]; then
        if [ ! -x "$script" ]; then
            echo -e "  ${YELLOW}⚠${NC} ${script} - No execute permission, adding..."
            chmod +x "$script" 2>/dev/null
            if [ -x "$script" ]; then
                echo -e "  ${GREEN}✓${NC} ${script} - Permission granted"
                ((FIXED_COUNT++))
            else
                echo -e "  ${RED}✗${NC} ${script} - Failed to grant permission"
            fi
        else
            echo -e "  ${GREEN}✓${NC} ${script} - Execute permission OK"
        fi
    else
        echo -e "  ${YELLOW}⊝${NC} ${script} - File not found (will be created later)"
    fi
done

if [ $FIXED_COUNT -gt 0 ]; then
    echo -e "  ${CYAN}💡 Automatically granted execute permission to ${FIXED_COUNT} files${NC}"
fi

echo ""

# ============================================
# 1. 시스템 요구사항 체크
# ============================================

check_command() {
    if command -v $1 &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $1"
        return 0
    else
        echo -e "  ${RED}✗${NC} $1 (설치 필요)"
        return 1
    fi
}

NEED_SUDO=false
MISSING_PACKAGES=()

# Python 3 체크
if ! check_command python3; then
    MISSING_PACKAGES+=("python3")
    NEED_SUDO=true
fi

# pip3 체크 (MCP 설치용)
if ! check_command pip3; then
    echo -e "  ${RED}✗${NC} pip3 (설치 필요)"
    MISSING_PACKAGES+=("python3-pip")
    NEED_SUDO=true
fi

# Node.js 체크 (nvm 방식)
if ! check_command node; then
    echo -e "  ${YELLOW}⚠${NC} Node.js (nvm으로 설치 필요)"
fi

# npm 체크
if ! check_command npm; then
    echo -e "  ${YELLOW}⚠${NC} npm (Node.js와 함께 설치됨)"
fi

# Suricata 체크 (선택적)
if ! check_command suricata; then
    echo -e "  ${YELLOW}⚠${NC} suricata (선택 사항, 실제 IDS 기능)"
fi

# ============================================
# 2. sudo 권한 확인 (필요한 경우)
# ============================================

if [ "$NEED_SUDO" = true ]; then
    echo ""
    echo -e "${YELLOW}⚠️  일부 패키지는 sudo 권한이 필요합니다.${NC}"
    echo -e "   필요한 패키지: ${MISSING_PACKAGES[*]}"
    echo ""
    
    # sudo 비밀번호 미리 입력받기
    echo -e "${CYAN}🔐 sudo 비밀번호를 입력해주세요:${NC}"
    sudo -v
    
    # sudo 타임아웃 방지 (백그라운드에서 주기적으로 갱신)
    while true; do sudo -n true; sleep 50; kill -0 "$" || exit; done 2>/dev/null &
    SUDO_KEEPER_PID=$!
fi

# ============================================
# 3. Python 및 pip3 설치
# ============================================

echo ""
echo -e "${BLUE}[2/9] Python 환경 확인 중...${NC}"

if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    echo -e "  ${YELLOW}⚠${NC} 패키지 설치 시작..."
    
    sudo apt update -qq
    
    for pkg in "${MISSING_PACKAGES[@]}"; do
        echo -e "  설치 중: ${pkg}"
        sudo apt install -y ${pkg} > /dev/null 2>&1
    done
    
    echo -e "  ${GREEN}✓${NC} 패키지 설치 완료"
else
    echo -e "  ${GREEN}✓${NC} Python3와 pip3가 설치되어 있습니다."
fi

# Python 버전 확인
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
echo -e "  ${GREEN}✓${NC} Python: ${PYTHON_VERSION}"

# pip3 버전 확인
PIP_VERSION=$(pip3 --version 2>&1 | awk '{print $2}')
echo -e "  ${GREEN}✓${NC} pip3: ${PIP_VERSION}"

# ============================================
# 4. Node.js 설치 (nvm 방식)
# ============================================

echo ""
echo -e "${BLUE}[3/9] Node.js 환경 확인 중...${NC}"

if ! command -v node &> /dev/null; then
    echo -e "  ${YELLOW}⚠${NC} Node.js가 설치되지 않았습니다."
    echo -e "  ${CYAN}nvm을 통해 Node.js를 설치합니다...${NC}"
    
    # nvm 설치 여부 확인
    if [ ! -d "$HOME/.nvm" ]; then
        echo -e "  ${YELLOW}⚠${NC} nvm 설치 중..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
        
        # nvm 환경변수 로드
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        
        echo -e "  ${GREEN}✓${NC} nvm 설치 완료"
    else
        # nvm 환경변수 로드
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        echo -e "  ${GREEN}✓${NC} nvm이 이미 설치되어 있습니다."
    fi
    
    # Node.js 22 설치
    echo -e "  ${YELLOW}⚠${NC} Node.js 22 설치 중... (시간이 걸릴 수 있습니다)"
    nvm install 22
    nvm use 22
    
    echo -e "  ${GREEN}✓${NC} Node.js 설치 완료"
else
    # nvm 환경변수 로드 (이미 설치된 경우)
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" 2>/dev/null || true
    
    echo -e "  ${GREEN}✓${NC} Node.js가 이미 설치되어 있습니다."
fi

# Node.js 버전 확인
NODE_VERSION=$(node -v 2>/dev/null || echo "none")
if [ "$NODE_VERSION" != "none" ]; then
    echo -e "  ${GREEN}✓${NC} Node.js: ${NODE_VERSION}"
    
    # npm 버전 확인
    NPM_VERSION=$(npm -v 2>/dev/null || echo "none")
    echo -e "  ${GREEN}✓${NC} npm: ${NPM_VERSION}"
else
    echo -e "  ${RED}✗${NC} Node.js 설치 실패"
    echo -e "  ${YELLOW}수동 설치가 필요합니다:${NC}"
    echo -e "    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash"
    echo -e "    source ~/.bashrc"
    echo -e "    nvm install 22"
    exit 1
fi

# ============================================
# 5. MCP 모듈 설치
# ============================================

echo ""
echo -e "${BLUE}[4/9] Python 의존성 확인 중...${NC}"

# MCP 모듈 체크
if python3 -c "import mcp" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} mcp module"
else
    echo -e "  ${YELLOW}⚠${NC} mcp module 설치 중..."
    
    # pip3가 제대로 설치되었는지 재확인
    if ! command -v pip3 &> /dev/null; then
        echo -e "  ${RED}✗${NC} pip3를 찾을 수 없습니다. 재설치 중..."
        sudo apt install -y python3-pip
    fi
    
    # MCP 설치 (사용자 홈에만)
    pip3 install mcp --user
    
    # 설치 확인
    if python3 -c "import mcp" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} mcp 설치 완료"
    else
        echo -e "  ${RED}✗${NC} mcp 설치 실패"
        echo -e "  ${YELLOW}수동 설치를 시도하세요:${NC}"
        echo -e "    pip3 install mcp"
        exit 1
    fi
fi

# ============================================
# 6. Node.js 의존성 설치
# ============================================

echo ""
echo -e "${BLUE}[5/9] Node.js 의존성 확인 중...${NC}"

if [ ! -d "node_modules" ]; then
    echo -e "  ${YELLOW}⚠${NC} node_modules 없음. npm install 실행 중..."
    npm install
    echo -e "  ${GREEN}✓${NC} Node.js 패키지 설치 완료"
else
    echo -e "  ${GREEN}✓${NC} node_modules 존재"
    
    # package.json이 변경되었는지 확인
    if [ package.json -nt node_modules ]; then
        echo -e "  ${YELLOW}⚠${NC} package.json이 변경됨. npm install 실행..."
        npm install
    fi
fi

# ============================================
# 7. 디렉토리 구조 생성
# ============================================

echo ""
echo -e "${BLUE}[6/9] 디렉토리 구조 생성 중...${NC}"

# agent 디렉토리
if [ ! -d "agent" ]; then
    mkdir -p agent/logs agent/rules
    echo -e "  ${GREEN}✓${NC} agent/ 생성"
else
    mkdir -p agent/logs agent/rules 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} agent/ 확인"
fi

# data 디렉토리
mkdir -p data 2>/dev/null || true
echo -e "  ${GREEN}✓${NC} data/ 확인"

# logs 디렉토리 (서비스 로그용)
mkdir -p logs 2>/dev/null || true
echo -e "  ${GREEN}✓${NC} logs/ 확인"

# .gitkeep 생성
touch agent/logs/.gitkeep agent/rules/.gitkeep 2>/dev/null || true

# ============================================
# 7.5. Suricata 로그 권한 설정
# ============================================

echo ""
echo -e "${BLUE}[6.5/9] Suricata 설정 확인 중...${NC}"

# Suricata 설치 확인
if command -v suricata &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} Suricata 설치됨"
    
    # eve.json 파일 확인
    if [ -f "/var/log/suricata/eve.json" ]; then
        echo -e "  ${GREEN}✓${NC} eve.json 파일 존재"
        
        # 읽기 권한 확인
        if [ -r "/var/log/suricata/eve.json" ]; then
            echo -e "  ${GREEN}✓${NC} eve.json 읽기 가능"
        else
            echo -e "  ${YELLOW}⚠${NC} eve.json 읽기 권한 없음. 권한 설정 중..."
            
            # 방법 1: 파일 권한 변경 (sudo 필요)
            if sudo chmod 644 /var/log/suricata/eve.json 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} eve.json 권한 설정 완료 (644)"
            else
                # 방법 2: 사용자를 adm 그룹에 추가
                echo -e "  ${YELLOW}⚠${NC} 사용자를 adm 그룹에 추가 중..."
                sudo usermod -a -G adm $USER
                echo -e "  ${GREEN}✓${NC} adm 그룹 추가 완료"
                echo -e "  ${YELLOW}💡 변경사항 적용을 위해 재로그인이 필요할 수 있습니다.${NC}"
            fi
        fi
        
        # Suricata 실행 확인
        if systemctl is-active --quiet suricata; then
            echo -e "  ${GREEN}✓${NC} Suricata 실행 중"
        else
            echo -e "  ${YELLOW}⚠${NC} Suricata가 실행되지 않았습니다."
            read -p "Suricata를 시작하시겠습니까? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sudo systemctl start suricata
                echo -e "  ${GREEN}✓${NC} Suricata 시작됨"
            fi
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} eve.json 파일이 없습니다."
        echo -e "  ${CYAN}💡 Suricata를 시작하면 자동으로 생성됩니다.${NC}"
        
        # Suricata 시작 시도
        if ! systemctl is-active --quiet suricata; then
            read -p "Suricata를 시작하시겠습니까? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sudo systemctl start suricata
                sleep 3
                if [ -f "/var/log/suricata/eve.json" ]; then
                    sudo chmod 644 /var/log/suricata/eve.json
                    echo -e "  ${GREEN}✓${NC} Suricata 시작 및 권한 설정 완료"
                fi
            fi
        fi
    fi
else
    echo -e "  ${YELLOW}⚠${NC} Suricata가 설치되지 않았습니다."
    echo -e "  ${CYAN}💡 MCP Server는 실행되지만 실제 알림은 수신되지 않습니다.${NC}"
    echo ""
    echo -e "  ${CYAN}Suricata 설치 방법:${NC}"
    echo -e "    sudo apt update"
    echo -e "    sudo apt install suricata -y"
    echo -e "    sudo systemctl enable suricata"
    echo -e "    sudo systemctl start suricata"
    echo ""
fi

# ============================================
# 8. 설정 파일 자동 생성
# ============================================

echo ""
echo -e "${BLUE}[7/9] 설정 파일 생성 중...${NC}"

# agent_config.json (없을 때만 생성)
if [ ! -f "agent/agent_config.json" ]; then
    cat > agent/agent_config.json << 'CONFIGEOF'
{
  "check_interval": 60,
  "alert_threshold": 5,
  "time_window": 300,
  "auto_block": true,
  "severity_weight": {
    "1": 10,
    "2": 5,
    "3": 2
  },
  "whitelist": [
    "127.0.0.1",
    "localhost"
  ]
}
CONFIGEOF
    echo -e "  ${GREEN}✓${NC} agent_config.json 생성"
else
    echo -e "  ${GREEN}✓${NC} agent_config.json 존재"
fi

# README 파일들
if [ ! -f "agent/logs/README.md" ]; then
    cat > agent/logs/README.md << 'READMEEOF'
# Agent Action Logs

Auto-generated logs from MCP Security Agent.

## Files
- `agent_actions.log`: All blocking actions
READMEEOF
    echo -e "  ${GREEN}✓${NC} logs/README.md 생성"
fi

if [ ! -f "agent/rules/README.md" ]; then
    cat > agent/rules/README.md << 'READMEEOF'
# Auto-generated Suricata Rules

(Feature coming soon)
READMEEOF
    echo -e "  ${GREEN}✓${NC} rules/README.md 생성"
fi

# ============================================
# 9. 서비스 시작
# ============================================

echo ""
echo -e "${BLUE}[8/9] 서비스 시작 중...${NC}"
echo ""

# 이전 프로세스 정리
pkill -f "mcp_suricata_server.py" 2>/dev/null || true
pkill -f "mcp_agent.py" 2>/dev/null || true
pkill -f "node server.js" 2>/dev/null || true
sleep 1

# sudo keeper 종료
if [ ! -z "$SUDO_KEEPER_PID" ]; then
    kill $SUDO_KEEPER_PID 2>/dev/null || true
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# MCP 서버 시작
echo -e "${GREEN}[▶] MCP Server 시작 중...${NC}"
if [ -f "mcp_suricata_server.py" ]; then
    python3 mcp_suricata_server.py > logs/mcp_server.log 2>&1 &
    MCP_PID=$!
    echo -e "    PID: ${MCP_PID}"
    sleep 2
    
    if ps -p $MCP_PID > /dev/null; then
        echo -e "    ${GREEN}✓${NC} MCP Server 실행 중"
    else
        echo -e "    ${RED}✗${NC} MCP Server 시작 실패"
        echo -e "    로그: cat logs/mcp_server.log"
    fi
else
    echo -e "    ${YELLOW}⚠${NC} mcp_suricata_server.py 없음 (스킵)"
fi

sleep 1

# MCP Agent 시작
echo ""
echo -e "${GREEN}[▶] MCP Agent 시작 중...${NC}"
if [ -f "agent/mcp_agent.py" ]; then
    cd agent
    python3 mcp_agent.py > ../logs/mcp_agent.log 2>&1 &
    AGENT_PID=$!
    echo -e "    PID: ${AGENT_PID}"
    cd ..
    sleep 2
    
    if ps -p $AGENT_PID > /dev/null; then
        echo -e "    ${GREEN}✓${NC} MCP Agent 실행 중"
    else
        echo -e "    ${YELLOW}⚠${NC} MCP Agent 시작 실패 (선택 사항)"
        echo -e "    로그: cat logs/mcp_agent.log"
    fi
else
    echo -e "    ${YELLOW}⚠${NC} agent/mcp_agent.py 없음 (스킵)"
fi

sleep 1

# 웹 대시보드 시작
echo ""
echo -e "${GREEN}[▶] Web Dashboard 시작 중...${NC}"
npm start > logs/dashboard.log 2>&1 &
DASHBOARD_PID=$!
echo -e "    PID: ${DASHBOARD_PID}"
sleep 3

if ps -p $DASHBOARD_PID > /dev/null; then
    echo -e "    ${GREEN}✓${NC} Dashboard 실행 중"
else
    echo -e "    ${RED}✗${NC} Dashboard 시작 실패"
    echo -e "    로그: cat logs/dashboard.log"
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ============================================
# 상태 요약
# ============================================

echo -e "${GREEN}✅ One Step Security System 실행 완료!${NC}"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📊 서비스 상태${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ ! -z "$MCP_PID" ] && ps -p $MCP_PID > /dev/null; then
    echo -e "  MCP Server    : ${GREEN}●${NC} Running (PID: $MCP_PID)"
else
    echo -e "  MCP Server    : ${RED}●${NC} Stopped"
fi

if [ ! -z "$AGENT_PID" ] && ps -p $AGENT_PID > /dev/null; then
    echo -e "  MCP Agent     : ${GREEN}●${NC} Running (PID: $AGENT_PID)"
else
    echo -e "  MCP Agent     : ${YELLOW}●${NC} Stopped (선택 사항)"
fi

if [ ! -z "$DASHBOARD_PID" ] && ps -p $DASHBOARD_PID > /dev/null; then
    echo -e "  Web Dashboard : ${GREEN}●${NC} Running (PID: $DASHBOARD_PID)"
else
    echo -e "  Web Dashboard : ${RED}●${NC} Stopped"
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🌐 접속 정보${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Dashboard URL : ${GREEN}http://localhost:3100${NC}"
echo -e "  Agent Logs    : ${YELLOW}tail -f logs/mcp_agent.log${NC}"
echo -e "  Server Logs   : ${YELLOW}tail -f logs/mcp_server.log${NC}"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}⚙️  제어 명령어${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  정지       : ${YELLOW}./stop.sh${NC}"
echo -e "  재시작     : ${YELLOW}./restart.sh${NC}"
echo -e "  상태 확인  : ${YELLOW}./status.sh${NC}"
echo ""

# PID 저장
cat > .pids << PIDEOF
MCP_SERVER=$MCP_PID
AGENT=$AGENT_PID
DASHBOARD=$DASHBOARD_PID
PIDEOF

echo -e "${GREEN}💡 브라우저에서 http://localhost:3100 을 열어보세요!${NC}"
echo ""
echo -e "${YELLOW}💡 종료하려면: Ctrl+C 또는 ./stop.sh${NC}"
echo ""

# 실시간 로그 출력 (선택)
read -p "실시간 로그를 보시겠습니까? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📝 실시간 로그 (Ctrl+C로 종료)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    tail -f logs/*.log
fi