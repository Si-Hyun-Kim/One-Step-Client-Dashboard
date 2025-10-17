#!/bin/bash
# agent/setup.sh - Agent 초기 설정 스크립트

echo "🤖 Setting up MCP Security Agent..."
echo ""

# 현재 위치 확인
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "📁 Creating directory structure..."

# logs 디렉토리
if [ ! -d "logs" ]; then
    mkdir -p logs
    echo "   ✅ Created: logs/"
else
    echo "   ℹ️  Already exists: logs/"
fi

# rules 디렉토리
if [ ! -d "rules" ]; then
    mkdir -p rules
    echo "   ✅ Created: rules/"
else
    echo "   ℹ️  Already exists: rules/"
fi

echo ""
echo "📝 Creating configuration files..."

# .gitkeep 파일
touch logs/.gitkeep
touch rules/.gitkeep
echo "   ✅ Created: .gitkeep files"

# logs/README.md
if [ ! -f "logs/README.md" ]; then
    cat > logs/README.md << 'EOF'
# Agent Action Logs

This directory contains auto-generated logs from the MCP Security Agent.

## Files

- `agent_actions.log`: All blocking actions and security decisions
- `error.log`: Error logs (if any)

## Log Format

```json
{
  "timestamp": "2025-01-17T10:30:15",
  "action": "BLOCK",
  "ip": "203.0.113.10",
  "details": {
    "reason": "High alert count (8)",
    "score": 35,
    "count": 8,
    "signatures": ["SSH-BRUTEFORCE", "WEB-APP-SQLi"]
  }
}
```

## Viewing Logs

```bash
# Real-time monitoring
tail -f agent_actions.log

# Last 20 entries
tail -n 20 agent_actions.log

# Search by IP
grep "203.0.113.10" agent_actions.log
```
EOF
    echo "   ✅ Created: logs/README.md"
else
    echo "   ℹ️  Already exists: logs/README.md"
fi

# rules/README.md
if [ ! -f "rules/README.md" ]; then
    cat > rules/README.md << 'EOF'
# Auto-generated Suricata Rules

This directory will contain auto-generated Suricata rules based on detected attack patterns.

## Status

🚧 Feature coming soon!

## Planned Features

- Pattern-based rule generation
- AI-assisted rule optimization
- Automatic Suricata reload

## Manual Rule Format

```
alert tcp $EXTERNAL_NET any -> $HOME_NET any (msg:"Auto-generated: SSH Brute Force"; flow:to_server; threshold:type limit,track by_src,count 5,seconds 60; classtype:attempted-admin; sid:9000001; rev:1;)
```
EOF
    echo "   ✅ Created: rules/README.md"
else
    echo "   ℹ️  Already exists: rules/README.md"
fi

# agent_config.json (샘플)
if [ ! -f "agent_config.json" ]; then
    cat > agent_config.json << 'EOF'
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
  ],
  "notifications": {
    "enabled": false,
    "email": "admin@example.com"
  }
}
EOF
    echo "   ✅ Created: agent_config.json (sample)"
else
    echo "   ℹ️  Already exists: agent_config.json"
fi

echo ""
echo "🔍 Checking dependencies..."

# Python 확인
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
    echo "   ✅ Python 3: $PYTHON_VERSION"
else
    echo "   ❌ Python 3 not found!"
    echo "      Install: sudo apt install python3"
    exit 1
fi

# MCP 모듈 확인
if python3 -c "import mcp" 2>/dev/null; then
    echo "   ✅ MCP module installed"
else
    echo "   ❌ MCP module not found!"
    echo "      Install: sudo pip3 install mcp"
    exit 1
fi

# MCP 서버 확인
if [ -f "../mcp_suricata_server.py" ]; then
    echo "   ✅ MCP Server found: ../mcp_suricata_server.py"
else
    echo "   ⚠️  MCP Server not found at: ../mcp_suricata_server.py"
    echo "      Make sure mcp_suricata_server.py is in the parent directory"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "📚 Next steps:"
echo "   1. Review configuration: nano agent_config.json"
echo "   2. Start agent: python3 mcp_agent.py"
echo "   3. View logs: tail -f logs/agent_actions.log"
echo ""
echo "🔧 Optional:"
echo "   - Add to systemd: sudo systemctl enable mcp-agent"
echo "   - Test mode: python3 mcp_agent.py --test"
echo ""