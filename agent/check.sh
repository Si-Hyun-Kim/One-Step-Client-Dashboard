#!/bin/bash
# agent/check.sh - Agent 실행 전 환경 검증

echo "🔍 MCP Agent Environment Check"
echo "================================"
echo ""

ERRORS=0
WARNINGS=0

# 1. 디렉토리 구조 확인
echo "📁 Directory Structure:"
for dir in "logs" "rules"; do
    if [ -d "$dir" ]; then
        echo "   ✅ $dir/"
    else
        echo "   ❌ $dir/ (missing)"
        ERRORS=$((ERRORS + 1))
    fi
done
echo ""

# 2. 필수 파일 확인
echo "📄 Required Files:"
FILES=("mcp_agent.py")
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "   ✅ $file"
    else
        echo "   ❌ $file (missing)"
        ERRORS=$((ERRORS + 1))
    fi
done

# MCP 서버 확인
if [ -f "../mcp_suricata_server.py" ]; then
    echo "   ✅ ../mcp_suricata_server.py"
else
    echo "   ⚠️  ../mcp_suricata_server.py (not found)"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# 3. Python 환경 확인
echo "🐍 Python Environment:"
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
    echo "   ✅ Python 3: $PYTHON_VERSION"
    
    # 버전 체크 (3.7 이상 권장)
    PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
    PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)
    
    if [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -ge 7 ]; then
        echo "      (Version OK: >= 3.7)"
    else
        echo "      ⚠️  Python 3.7+ recommended"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "   ❌ Python 3 not found"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# 4. Python 모듈 확인
echo "📦 Python Modules:"
MODULES=("mcp" "json" "asyncio" "collections" "datetime" "pathlib" "subprocess" "threading")
for module in "${MODULES[@]}"; do
    if python3 -c "import $module" 2>/dev/null; then
        echo "   ✅ $module"
    else
        echo "   ❌ $module (not installed)"
        if [ "$module" = "mcp" ]; then
            ERRORS=$((ERRORS + 1))
            echo "      Install: sudo pip3 install mcp"
        fi
    fi
done
echo ""

# 5. 권한 확인
echo "🔐 Permissions:"
if [ -x "mcp_agent.py" ]; then
    echo "   ✅ mcp_agent.py is executable"
else
    echo "   ⚠️  mcp_agent.py is not executable"
    echo "      Fix: chmod +x mcp_agent.py"
    WARNINGS=$((WARNINGS + 1))
fi

if [ -w "logs" ]; then
    echo "   ✅ logs/ is writable"
else
    echo "   ❌ logs/ is not writable"
    ERRORS=$((ERRORS + 1))
fi

if [ -w "rules" ]; then
    echo "   ✅ rules/ is writable"
else
    echo "   ❌ rules/ is not writable"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# 6. Suricata 확인
echo "🛡️  Suricata:"
if command -v suricata &> /dev/null; then
    SURICATA_VERSION=$(suricata --version 2>&1 | head -n1 | awk '{print $2}')
    echo "   ✅ Suricata: $SURICATA_VERSION"
else
    echo "   ⚠️  Suricata not found (agent will work but no alerts)"
    WARNINGS=$((WARNINGS + 1))
fi

if [ -f "/var/log/suricata/eve.json" ]; then
    echo "   ✅ eve.json exists"
    
    # 읽기 권한 확인
    if [ -r "/var/log/suricata/eve.json" ]; then
        echo "   ✅ eve.json is readable"
    else
        echo "   ⚠️  eve.json is not readable"
        echo "      Fix: sudo chmod 644 /var/log/suricata/eve.json"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "   ⚠️  eve.json not found"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# 7. iptables 권한 확인
echo "🔥 Firewall:"
if command -v iptables &> /dev/null; then
    echo "   ✅ iptables installed"
    
    # sudo 없이 실행 가능한지 확인
    if sudo -n iptables -L > /dev/null 2>&1; then
        echo "   ✅ iptables sudo access (passwordless)"
    else
        echo "   ⚠️  iptables requires password"
        echo "      To enable passwordless: sudo visudo"
        echo "      Add: $(whoami) ALL=(ALL) NOPASSWD: /usr/sbin/iptables"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "   ⚠️  iptables not found"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# 결과 요약
echo "================================"
echo "Summary:"
echo "  Errors:   $ERRORS"
echo "  Warnings: $WARNINGS"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo "✅ All critical checks passed!"
    echo ""
    echo "Ready to run:"
    echo "  python3 mcp_agent.py"
    exit 0
else
    echo "❌ Please fix errors before running agent"
    exit 1
fi