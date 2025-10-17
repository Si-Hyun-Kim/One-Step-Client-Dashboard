# 🚀 One Step Security System - 빠른 시작

단 **하나의 명령어**로 모든 것을 설치하고 실행합니다.

---

## ⚡ 초간단 시작 (3초!)

```bash
cd ~/onestep-dashboard
./start.sh
```

**끝!** 🎉

> `start.sh`가 자동으로:
> - ✅ 모든 스크립트 파일에 실행 권한 자동 부여
> - ✅ Python, Node.js 설치 확인 및 설치
> - ✅ MCP 모듈 설치
> - ✅ Suricata 권한 자동 설정
> - ✅ 모든 서비스 자동 시작

---

## 📦 전체 파일 구조

```
onestep-dashboard/
├── start.sh              # ⭐ 올인원 실행 (이것만 실행!)
├── stop.sh               # 정지
├── restart.sh            # 재시작
├── status.sh             # 상태 확인
├── server.js             # Express 서버
├── mcp_suricata_server.py # MCP 서버
├── mcp-client.js         # MCP 클라이언트
├── package.json          # Node.js 의존성
├── agent/
│   ├── mcp_agent.py      # Agent (자동 생성 코드 포함)
│   ├── agent_config.json # 설정 (자동 생성)
│   ├── logs/             # 로그 (자동 생성)
│   └── rules/            # 룰 (자동 생성)
├── logs/                 # 서비스 로그 (자동 생성)
└── .pids                 # PID 저장 (자동 생성)
```

---

## ⚡ 빠른 시작 (3단계)

### 1. 저장소 클론 또는 다운로드

```bash
# GitHub에서 클론
git clone https://github.com/yourusername/onestep-dashboard.git
cd onestep-dashboard

# 또는 ZIP 다운로드 후 압축 해제
```

### 2. start.sh 실행 권한 부여 (최초 1회만)

```bash
chmod +x start.sh
```

### 3. 실행!

```bash
./start.sh
```

**끝!** 🎉

> **💡 참고**: `start.sh`가 다른 모든 스크립트 파일(`stop.sh`, `restart.sh` 등)의 실행 권한을 자동으로 확인하고 부여하므로, `start.sh`에만 권한을 주면 됩니다!

---

## 🎯 start.sh가 자동으로 하는 일

### ✅ 0단계: 스크립트 권한 자동 설정 (NEW!)
**자동으로 모든 스크립트 파일의 실행 권한 확인 및 부여:**
- `stop.sh`
- `restart.sh`
- `status.sh`
- `fix-permissions.sh`
- `agent/setup.sh`
- `agent/check.sh`
- `agent/mcp_agent.py`

→ **이제 `start.sh`에만 권한을 주면 나머지는 자동!**

### ✅ 1단계: 시스템 검사
- Python 3 확인
- Node.js 확인
- npm 확인
- Suricata 확인 (선택)

### ✅ 2단계: 패키지 자동 설치
없는 패키지가 있으면 자동 설치:
- `python3`
- `python3-pip`
- `nodejs` (nvm 방식)

### ✅ 3단계: Python 의존성
- `mcp` 모듈 자동 설치
- `pip3 install mcp`

### ✅ 4단계: Node.js 의존성
- `npm install` 자동 실행
- `node_modules` 생성

### ✅ 5단계: 디렉토리 생성
자동으로 생성:
- `agent/`
- `agent/logs/`
- `agent/rules/`
- `data/`
- `logs/`

### ✅ 6단계: Suricata 권한 자동 설정 (NEW!)
- eve.json 파일 권한 자동 설정 (644)
- 사용자를 adm 그룹에 자동 추가
- Suricata 서비스 시작 확인

### ✅ 7단계: 설정 파일 생성
없을 때만 자동 생성:
- `agent/agent_config.json`
- `agent/logs/README.md`
- `agent/rules/README.md`
- `.gitkeep` 파일들

### ✅ 8단계: 서비스 시작
자동으로 백그라운드 실행:
1. **MCP Server** (Suricata 로그 읽기)
2. **MCP Agent** (자동 방어)
3. **Web Dashboard** (모니터링)

---

## 📊 실행 결과

```
╔═══════════════════════════════════════════════╗
║   🛡️  ONE STEP SECURITY SYSTEM 🛡️            ║
╚═══════════════════════════════════════════════╝

[0/9] 스크립트 권한 확인 중...
  ⚠ stop.sh - 실행 권한 없음, 권한 부여 중...
  ✓ stop.sh - 권한 부여 완료
  ⚠ restart.sh - 실행 권한 없음, 권한 부여 중...
  ✓ restart.sh - 권한 부여 완료
  ⚠ status.sh - 실행 권한 없음, 권한 부여 중...
  ✓ status.sh - 권한 부여 완료
  💡 3개 파일의 실행 권한을 자동으로 부여했습니다.

[1/9] 시스템 검사 중...
  ✓ python3
  ✓ pip3
  ✓ node
  ✓ npm

[2/9] Python 환경 확인 중...
  ✓ Python: 3.10.12
  ✓ pip3: 22.0.2

[3/9] Node.js 환경 확인 중...
  ✓ Node.js: v22.20.0
  ✓ npm: 10.9.3

[4/9] Python 의존성 확인 중...
  ✓ mcp module

[5/9] Node.js 의존성 확인 중...
  ✓ node_modules 존재

[6/9] 디렉토리 구조 생성 중...
  ✓ agent/ 확인
  ✓ data/ 확인
  ✓ logs/ 확인

[6.5/9] Suricata 설정 확인 중...
  ✓ Suricata 설치됨
  ✓ eve.json 파일 존재
  ⚠ eve.json 읽기 권한 없음. 권한 설정 중...
  ✓ eve.json 권한 설정 완료 (644)
  ✓ Suricata 실행 중

[7/9] 설정 파일 생성 중...
  ✓ agent_config.json 존재
  ✓ logs/README.md 존재

[8/9] 서비스 시작 중...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[▶] MCP Server 시작 중...
    PID: 12345
    ✓ MCP Server 실행 중

[▶] MCP Agent 시작 중...
    PID: 12346
    ✓ MCP Agent 실행 중

[▶] Web Dashboard 시작 중...
    PID: 12347
    ✓ Dashboard 실행 중

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ One Step Security System 실행 완료!

  Dashboard: http://localhost:3100
```

---

## 🎮 제어 명령어

### 서비스 정지

```bash
./stop.sh
```

**출력:**
```
╔═══════════════════════════════════════╗
║   🛑 Stopping Security System...     ║
╚═══════════════════════════════════════╝

[●] MCP Server 정지 중... (PID: 12345)
    ✓ MCP Server 정지됨
[●] MCP Agent 정지 중... (PID: 12346)
    ✓ MCP Agent 정지됨
[●] Dashboard 정지 중... (PID: 12347)
    ✓ Dashboard 정지됨

✅ 모든 서비스가 정지되었습니다.
```

### 서비스 재시작

```bash
./restart.sh
```

### 상태 확인

```bash
./status.sh
```

**출력 예시:**
```
╔═══════════════════════════════════════════════╗
║   📊 One Step Security System Status         ║
╚═══════════════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
서비스 상태
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ● MCP Server
      PID     : 12345
      Uptime  : 00:15:23
      Memory  : 45.2 MB
      CPU     : 2.3%

  ● MCP Agent
      PID     : 12346
      Uptime  : 00:15:20
      Memory  : 38.7 MB
      CPU     : 1.8%

  ● Web Dashboard
      PID     : 12347
      Uptime  : 00:15:18
      Memory  : 89.3 MB
      CPU     : 0.5%

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
네트워크 상태
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ● Port 3100 (Dashboard) - LISTENING

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
방화벽 규칙
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  🔒 차단된 IP: 3개

  최근 차단된 IP (최대 5개):
    ▸ 203.0.113.10
    ▸ 198.51.100.77
    ▸ 192.0.2.44

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
요약
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  실행 중인 서비스: 3 / 3
  전체 상태: ✓ All Systems Operational

  Dashboard: http://localhost:3100
```

---

## 🔧 설정 변경

### agent_config.json (자동 생성됨)

첫 실행 시 자동으로 생성되는 기본 설정:

```json
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
```

**설정 변경 후:**
```bash
./restart.sh  # 재시작하여 적용
```

---

## 📝 로그 확인

### 실시간 로그

```bash
# 모든 로그 실시간 보기
tail -f logs/*.log

# Agent 로그만
tail -f logs/mcp_agent.log

# Dashboard 로그만
tail -f logs/dashboard.log

# Agent 액션 로그
tail -f agent/logs/agent_actions.log
```

### 로그 파일 위치

```
logs/
├── mcp_server.log       # MCP 서버 로그
├── mcp_agent.log        # Agent 로그
└── dashboard.log        # 웹 대시보드 로그

agent/logs/
└── agent_actions.log    # 차단 액션 기록
```

---

## 🆘 문제 해결

### Q: "Permission denied" 에러

**해결:**
```bash
chmod +x *.sh
chmod +x agent/*.py
```

### Q: 포트 3100이 이미 사용 중

**해결:**
```bash
# 기존 프로세스 종료
./stop.sh

# 또는 수동으로
pkill -f "node server.js"
```

### Q: MCP 모듈을 찾을 수 없음

**해결:**
```bash
# 수동 설치
pip3 install mcp

# 또는
sudo pip3 install mcp
```

### Q: 서비스가 자동으로 시작 안 됨

**해결:**
```bash
# 상태 확인
./status.sh

# 로그 확인
cat logs/mcp_server.log
cat logs/mcp_agent.log
cat logs/dashboard.log

# 재시작
./restart.sh
```

---

## 🚀 시작 옵션

### 백그라운드 실행 (기본)

```bash
./start.sh
```

### 실시간 로그 보면서 실행

```bash
./start.sh
# "실시간 로그를 보시겠습니까?" → y 입력
```

---

## ✨ 주요 특징

| 특징 | 설명 |
|------|------|
| **원클릭 설치** | 의존성 자동 설치 |
| **원클릭 실행** | 모든 서비스 자동 시작 |
| **자동 설정** | 디렉토리/파일 자동 생성 |
| **상태 모니터링** | `./status.sh`로 실시간 확인 |
| **간편한 제어** | start/stop/restart 스크립트 |
| **로그 통합** | `logs/` 디렉토리에 모든 로그 |

---

## 🎯 요약

```bash
# 처음 한 번만
cd ~/onestep-dashboard
chmod +x *.sh

# 이후로는 이것만!
./start.sh   # 시작
./stop.sh    # 정지
./restart.sh # 재시작
./status.sh  # 상태 확인
```

**브라우저에서 http://localhost:3100 접속!** 🎉

---

## 💡 팁

1. **화이트리스트 설정**: `agent/agent_config.json`에 관리자 IP 추가
2. **자동 시작**: systemd 서비스로 등록하면 부팅 시 자동 시작
3. **로그 백업**: `logs/` 디렉토리 주기적 백업 권장
4. **보안**: iptables 규칙 주기적으로 확인

---

**Windows .exe처럼 간단하죠?** 😊