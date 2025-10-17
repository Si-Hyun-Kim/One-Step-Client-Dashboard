# 🤖 MCP Agent 사용 가이드

## 개요

Ollama, Flask 없이 **순수 Python + MCP만으로** 구현한 자동 방어 Agent입니다.

## 특징

✅ **규칙 기반 자동 탐지**
- IP당 알림 횟수 집계
- 심각도 가중치 계산
- 시간 윈도우 기반 분석

✅ **자동 차단**
- 임계값 초과 시 자동 IP 차단
- 화이트리스트 지원
- 액션 로깅

✅ **의존성 최소화**
- Ollama 불필요
- Flask 불필요
- 표준 Python 라이브러리만 사용

✅ **자동 초기화**
- 디렉토리 자동 생성
- 설정 파일 자동 생성
- README 자동 생성

## 파일 구조

```
onestep-dashboard/
├── mcp_suricata_server.py     # MCP 서버 (기존)
├── mcp-client.js              # MCP 클라이언트 (기존)
├── server.js                  # Express 서버 (기존)
└── agent/                     # Agent 디렉토리 (새로 추가!)
    ├── mcp_agent.py           # Agent 메인 파일
    ├── setup.sh               # 초기 설정 스크립트
    ├── check.sh               # 환경 검증 스크립트
    ├── agent_config.json      # 설정 파일 (자동 생성)
    ├── logs/                  # 로그 디렉토리 (자동 생성)
    │   ├── .gitkeep
    │   ├── README.md
    │   └── agent_actions.log  # 액션 로그
    └── rules/                 # 룰 디렉토리 (자동 생성)
        ├── .gitkeep
        └── README.md
```

## 설치 및 초기 설정

### 방법 1: 자동 설정 (추천) ⭐

```bash
cd ~/onestep-dashboard

# 1. agent 디렉토리 생성
mkdir -p agent
cd agent

# 2. 파일 생성 (mcp_agent.py, setup.sh, check.sh)
# VSCode나 nano로 위의 코드 복사

# 3. 실행 권한 부여
chmod +x setup.sh check.sh mcp_agent.py

# 4. 초기 설정 실행
./setup.sh
```

**출력 예시:**
```
🤖 Setting up MCP Security Agent...

📁 Creating directory structure...
   ✅ Created: logs/
   ✅ Created: rules/

📝 Creating configuration files...
   ✅ Created: .gitkeep files
   ✅ Created: logs/README.md
   ✅ Created: rules/README.md
   ✅ Created: agent_config.json (sample)

🔍 Checking dependencies...
   ✅ Python 3: 3.10.12
   ✅ MCP module installed
   ✅ MCP Server found: ../mcp_suricata_server.py

✅ Setup complete!
```

### 방법 2: 수동 설정

```bash
cd ~/onestep-dashboard

# MCP 설치 확인
sudo pip3 install mcp

# agent 디렉토리 생성
mkdir -p agent/logs agent/rules

# Agent 파일 생성
nano agent/mcp_agent.py
# (코드 복사)

# 실행 권한
chmod +x agent/mcp_agent.py
```

## 실행 전 환경 체크

```bash
cd ~/onestep-dashboard/agent

# 환경 검증 스크립트 실행
./check.sh
```

**체크 항목:**
- ✅ 디렉토리 구조
- ✅ Python 버전 (3.7+)
- ✅ MCP 모듈
- ✅ 파일 권한
- ✅ Suricata 상태
- ✅ iptables 권한

## 실행

### 기본 실행

```bash
cd ~/onestep-dashboard/agent

# Agent 실행 (디렉토리 자동 생성!)
python3 mcp_agent.py
```

### 터미널 2개 사용 (디버깅 시)

```bash
# 터미널 1: MCP 서버
cd ~/onestep-dashboard
python3 mcp_suricata_server.py

# 터미널 2: Agent
cd ~/onestep-dashboard/agent
python3 mcp_agent.py
```

## 작동 원리

```
[60초마다 실행]
    ↓
1. MCP 서버에서 최근 100개 알림 가져오기
    ↓
2. 패턴 분석 (5분 윈도우)
   - IP별 알림 횟수 집계
   - 심각도 점수 계산
   - 공격 시그니처 분석
    ↓
3. 위협 탐지 규칙 적용
   ✓ 알림 5회 이상
   ✓ 위험 점수 20 이상
   ✓ 공격 시그니처 3개 이상
    ↓
4. 자동 차단 (또는 알림)
    ↓
5. 로그 기록
```

## 탐지 규칙

### 규칙 1: 알림 횟수 (High Alert Count)
```python
if alert_count >= 5:  # 5분간 5회 이상
    → BLOCK
```

### 규칙 2: 위험 점수 (High Risk Score)
```python
score = (critical * 10) + (high * 5) + (medium * 2)

if score >= 20:  # 예: Critical 2개
    → BLOCK
```

### 규칙 3: 다양한 공격 (Multiple Signatures)
```python
if len(unique_signatures) >= 3:  # 3가지 이상 공격 유형
    → BLOCK
```

## 설정 커스터마이징

### 방법 1: 코드에서 직접 수정

```python
# agent/mcp_agent.py - main() 함수 수정
def main():
    agent = SecurityAgent()

    # 설정 변경
    agent.config['alert_threshold'] = 3      # 알림 3회로 낮춤
    agent.config['check_interval'] = 30      # 30초마다 체크
    agent.config['time_window'] = 600        # 시간 윈도우 10분
    agent.config['auto_block'] = False       # 자동 차단 비활성화 (테스트용)
    
    # 화이트리스트 추가
    agent.config['whitelist'].extend([
        '192.168.1.1',      # 공유기
        '10.0.0.1',         # 내부 서버
    ])
    
    # 심각도 가중치 변경
    agent.config['severity_weight'] = {
        1: 20,   # Critical → 더 높게
        2: 10,   # High
        3: 5     # Medium
    }

    agent.start()
```

### 방법 2: 설정 파일 사용 (agent_config.json)

```json
{
  "check_interval": 30,
  "alert_threshold": 3,
  "time_window": 600,
  "auto_block": true,
  "severity_weight": {
    "1": 20,
    "2": 10,
    "3": 5
  },
  "whitelist": [
    "127.0.0.1",
    "localhost",
    "192.168.1.1",
    "10.0.0.1"
  ]
}
```

**설정 적용 (향후 기능):**
```python
# agent/mcp_agent.py에 추가
def load_config(self):
    config_file = self.base_dir / 'agent_config.json'
    if config_file.exists():
        with open(config_file) as f:
            self.config.update(json.load(f))
```

## 화이트리스트 추가

**중요한 IP는 반드시 화이트리스트에 추가하세요!**

```python
agent.config['whitelist'] = [
    '127.0.0.1',           # 로컬호스트
    'localhost',
    '192.168.1.1',         # 공유기
    '192.168.1.100',       # 관리자 PC
    '10.0.0.1',            # 내부 서버
    '203.0.113.50',        # 신뢰하는 외부 서버
]
```

## 디렉토리 및 로그

### 자동 생성되는 파일

Agent 실행 시 자동으로 생성:

1. **`logs/` 디렉토리**
   - `agent_actions.log` - 모든 차단 액션 기록
   - `.gitkeep` - Git 추적용
   - `README.md` - 로그 설명

2. **`rules/` 디렉토리**
   - `.gitkeep` - Git 추적용
   - `README.md` - 룰 설명
   - 향후: 자동 생성 룰 파일

3. **`agent_config.json`**
   - 설정 샘플 파일

### 로그 파일 확인

```bash
# 실시간 모니터링
tail -f logs/agent_actions.log

# 최근 20개
tail -n 20 logs/agent_actions.log

# 특정 IP 검색
grep "203.0.113.10" logs/agent_actions.log

# 오늘 차단된 IP 목록
grep "$(date +%Y-%m-%d)" logs/agent_actions.log | grep BLOCK
```

### 로그 형식

```json
{
  "timestamp": "2025-01-17T10:30:15",
  "action": "BLOCK",
  "ip": "203.0.113.10",
  "details": {
    "reason": "High alert count (8)",
    "score": 35,
    "count": 8,
    "signatures": ["SSH-BRUTEFORCE", "WEB-APP-SQLi", "PORT-SCAN"]
  }
}
```

```
🤖 MCP Security Agent Starting...
⚙️  Check Interval: 60s
⚙️  Alert Threshold: 5
⚙️  Time Window: 300s
⚙️  Auto Block: True

✅ MCP Agent connected to server

[2025-01-17 10:30:15] 🔍 Analyzing...
   📊 Found 25 alerts
   ⚠️  Detected 2 threats

   🚨 THREAT DETECTED
      IP: 203.0.113.10
      Reason: High alert count (8)
      Score: 35
      Count: 8
      Signatures: SSH-BRUTEFORCE, WEB-APP-SQLi, PORT-SCAN
      🔒 Auto blocking...
      ✅ Blocked successfully

   🚨 THREAT DETECTED
      IP: 198.51.100.77
      Reason: High risk score (25)
      Score: 25
      Count: 3
      Signatures: MALWARE-CNCC, TROJAN-ACTIVITY
      🔒 Auto blocking...
      ✅ Blocked successfully
```

## 로그 파일

`agent_actions.log`에 모든 액션 기록:

```json
{"timestamp": "2025-01-17T10:30:15", "action": "BLOCK", "ip": "203.0.113.10", "details": {...}}
{"timestamp": "2025-01-17T10:35:20", "action": "BLOCK", "ip": "198.51.100.77", "details": {...}}
```

## 동시 실행

Agent와 웹 대시보드를 함께 실행:

```bash
# 터미널 1: MCP 서버
python3 mcp_suricata_server.py

# 터미널 2: Agent (자동 방어)
python3 mcp_agent.py

# 터미널 3: 웹 대시보드
npm start
```

→ Agent가 자동으로 차단하고, 웹에서 결과 확인 가능!

## Systemd 서비스 등록

```bash
sudo nano /etc/systemd/system/mcp-agent.service
```

```ini
[Unit]
Description=MCP Security Agent
After=network.target suricata.service

[Service]
Type=simple
User=root
WorkingDirectory=/home/onestep/onestep-dashboard
ExecStart=/usr/bin/python3 /home/onestep/onestep-dashboard/mcp_agent.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable mcp-agent
sudo systemctl start mcp-agent

# 로그 확인
sudo journalctl -u mcp-agent -f
```

## 문제 해결

### Agent가 시작 안 됨

**증상**: `ModuleNotFoundError: No module named 'mcp'`

**해결**:
```bash
# MCP 설치 확인
python3 -c "import mcp; print('OK')"

# 없으면 설치
sudo pip3 install mcp

# 또는
pip3 install mcp
```

### 디렉토리 생성 실패

**증상**: `Permission denied` 또는 디렉토리 생성 안 됨

**해결**:
```bash
# 수동으로 디렉토리 생성
cd ~/onestep-dashboard/agent
mkdir -p logs rules

# 권한 확인
ls -la

# 권한 수정 (필요시)
chmod 755 logs rules
```

### 알림이 안 잡힘

**증상**: "No alerts found" 계속 표시

**해결**:
```bash
# 1. Suricata 실행 중인지 확인
sudo systemctl status suricata

# 2. 로그 생성되는지 확인
sudo tail -f /var/log/suricata/eve.json

# 3. 로그 권한 확인
ls -la /var/log/suricata/eve.json

# 4. 권한 없으면 수정
sudo chmod 644 /var/log/suricata/eve.json
```

### 차단이 안 됨

**증상**: "Failed to block IP" 메시지

**해결**:
```bash
# 1. iptables 권한 확인
sudo iptables -L -n

# 2. sudoers 설정
sudo visudo

# 3. 다음 줄 추가 (onestep을 실제 사용자명으로 변경)
onestep ALL=(ALL) NOPASSWD: /usr/sbin/iptables, /usr/sbin/ip6tables

# 4. 저장 후 재시작
sudo systemctl restart mcp-agent
```

### MCP 서버 연결 실패

**증상**: `[MCP Server] Process exited with code 1`

**해결**:
```bash
# 1. MCP 서버 경로 확인
ls -la ~/onestep-dashboard/mcp_suricata_server.py

# 2. 수동으로 MCP 서버 실행 (다른 터미널)
cd ~/onestep-dashboard
python3 mcp_suricata_server.py

# 3. Agent 실행 (원래 터미널)
cd ~/onestep-dashboard/agent
python3 mcp_agent.py
```

### 로그가 안 쌓임

**증상**: `logs/agent_actions.log` 파일이 비어있음

**해결**:
```bash
# 1. 디렉토리 권한 확인
ls -la logs/

# 2. 쓰기 권한 확인
touch logs/test.txt

# 3. 코드에서 로그 경로 확인
# agent/mcp_agent.py의 log_action 메서드 디버깅
```

### 설정이 적용 안 됨

**증상**: `agent_config.json` 수정해도 변화 없음

**원인**: 현재는 코드에서 직접 설정을 수정해야 함

**해결**:
```python
# agent/mcp_agent.py의 main() 함수에서 수정
agent = SecurityAgent()
agent.config['alert_threshold'] = 3  # 여기서 변경!
agent.start()
```

## 테스트

```bash
# 테스트 트래픽 생성
curl http://testmynids.org/uid/index.html

# 포트 스캔 시뮬레이션 (주의!)
# nmap -sS localhost

# Agent 로그 확인
tail -f agent_actions.log
```

## 고급 설정

### 심각도 가중치 조정

공격의 심각도에 따라 점수를 다르게 부여:

```python
agent.config['severity_weight'] = {
    1: 20,   # Critical → 매우 높게 (기본: 10)
    2: 10,   # High → 높게 (기본: 5)
    3: 5     # Medium → 보통 (기본: 2)
}
```

**예시**:
- Critical 2개 = 20×2 = 40점 → 즉시 차단
- High 4개 = 10×4 = 40점 → 즉시 차단
- Medium 10개 = 5×10 = 50점 → 즉시 차단

### 시간 윈도우 변경

분석 기간 조정:

```python
agent.config['time_window'] = 600  # 10분으로 확장 (기본: 300초/5분)
agent.config['time_window'] = 180  # 3분으로 축소
```

**권장 설정**:
- 일반 환경: 300초 (5분)
- 공격 많은 환경: 600초 (10분) - 패턴 더 잘 보임
- 빠른 대응 필요: 120초 (2분)

### 수동 모드 (알림만)

차단은 하지 않고 탐지만:

```python
agent.config['auto_block'] = False  # 자동 차단 끄기
```

→ 위협 탐지만 하고, 차단은 웹 대시보드에서 수동으로!

### 체크 주기 조정

분석 빈도 변경:

```python
agent.config['check_interval'] = 30   # 30초마다 (기본: 60초)
agent.config['check_interval'] = 300  # 5분마다 (리소스 절약)
```

**권장 설정**:
- 프로덕션: 60초 (기본)
- 테스트: 30초
- 리소스 부족 시: 120~300초

### 커스텀 탐지 규칙 추가 (향후)

```python
def custom_threat_detection(self, alerts):
    """커스텀 위협 탐지 로직"""
    threats = []
    
    # 예: 특정 포트 공격 탐지
    for alert in alerts:
        if alert.get('dest_port') == 22:  # SSH
            if 'brute' in alert.get('signature', '').lower():
                threats.append({
                    'ip': alert['source_ip'],
                    'reason': 'SSH Brute Force Detected',
                    'score': 50
                })
    
    return threats
```

## 다음 단계 (향후 기능)

### Phase 1: 현재 (규칙 기반) ✅
- IP별 알림 집계
- 심각도 점수 계산
- 자동 차단
- 로그 기록

### Phase 2: Ollama 연동 (로컬 AI)
```python
# agent/mcp_agent_ai.py (향후)
import ollama

def ai_analyze(self, alerts):
    response = ollama.chat(
        model='qwen2.5:7b',
        messages=[{
            'role': 'user',
            'content': f'이 알림들을 분석하고 위협도 평가: {alerts}'
        }]
    )
    return response['message']['content']
```

### Phase 3: Suricata 룰 자동 생성
```python
# agent/rule_generator.py (향후)
def generate_suricata_rule(self, pattern):
    """패턴 기반 룰 자동 생성"""
    rule = f'''
    alert tcp any any -> $HOME_NET any (
        msg:"Auto-generated: {pattern['name']}";
        content:"{pattern['signature']}";
        threshold:type limit,track by_src,count 5,seconds 60;
        sid:{self.get_next_sid()};
        rev:1;
    )
    '''
    self.save_rule(rule)
    self.reload_suricata()
```

### Phase 4: 웹 UI 통합
- 웹 대시보드에서 Agent 상태 확인
- 차단된 IP 목록 표시
- Agent 설정 변경
- 생성된 룰 승인/거부

### Phase 5: 알림 시스템
```python
# agent/notifier.py (향후)
def send_notification(self, threat):
    # 이메일
    send_email(admin_email, f'Threat detected: {threat}')
    
    # Slack
    post_to_slack(f'🚨 {threat["ip"]} blocked')
    
    # Telegram
    send_telegram(f'Blocked: {threat["ip"]}')
```

## 참고 자료

### 공식 문서
- [MCP 공식 문서](https://modelcontextprotocol.io/)
- [Suricata 문서](https://suricata.io/)
- [Python asyncio](https://docs.python.org/3/library/asyncio.html)

### 관련 프로젝트
- [Claude Desktop MCP](https://github.com/anthropics/anthropic-quickstarts/tree/main/mcp)
- [Suricata Rules](https://rules.emergingthreats.net/)

### 커뮤니티
- [Suricata Forum](https://forum.suricata.io/)
- [MCP Discord](https://discord.gg/modelcontextprotocol)

## 요약

### 빠른 시작 체크리스트

```bash
# 1. 디렉토리 생성
cd ~/onestep-dashboard
mkdir -p agent
cd agent

# 2. 파일 생성
# - mcp_agent.py (메인 코드)
# - setup.sh (초기 설정)
# - check.sh (환경 검증)

# 3. 권한 설정
chmod +x *.sh *.py

# 4. 초기 설정 실행
./setup.sh

# 5. 환경 확인
./check.sh

# 6. Agent 실행
python3 mcp_agent.py
```

### 주요 특징 요약

| 항목 | 설명 |
|------|------|
| **의존성** | Python + MCP만 (Ollama, Flask 불필요) |
| **자동 생성** | logs/, rules/ 디렉토리 자동 생성 |
| **실행** | `python3 mcp_agent.py` |
| **설정** | 코드에서 `agent.config` 수정 |
| **로그** | `logs/agent_actions.log` |
| **탐지 규칙** | 알림 횟수, 위험 점수, 시그니처 수 |
| **자동화** | Systemd 서비스로 등록 가능 |

### 일반적인 사용 시나리오

#### 시나리오 1: 개발/테스트
```bash
# 수동 모드로 실행
agent.config['auto_block'] = False  # 코드에서 수정
python3 mcp_agent.py

# 웹에서 결과 확인 후 수동 차단
```

#### 시나리오 2: 프로덕션 (자동 방어)
```bash
# 자동 차단 활성화
agent.config['auto_block'] = True
python3 mcp_agent.py

# 또는 systemd 서비스로
sudo systemctl start mcp-agent
```

#### 시나리오 3: 모니터링만
```bash
# 낮은 임계값 + 수동 모드
agent.config['alert_threshold'] = 10  # 높게 설정
agent.config['auto_block'] = False
python3 mcp_agent.py
```

### 성능 최적화

**메모리 사용량**: ~50MB  
**CPU 사용량**: ~5% (60초 체크 기준)  
**디스크 I/O**: 최소 (로그만 기록)

**권장 리소스**:
- RAM: 최소 512MB
- CPU: 1 Core
- 디스크: 100MB (로그 공간)

### 보안 고려사항

1. **화이트리스트 필수**
   ```python
   # 관리자 IP는 반드시 추가!
   agent.config['whitelist'].append('your.ip.address')
   ```

2. **로그 백업**
   ```bash
   # 주기적 백업
   cp logs/agent_actions.log logs/backup_$(date +%Y%m%d).log
   ```

3. **iptables 규칙 검토**
   ```bash
   # 차단된 IP 확인
   sudo iptables -L -n | grep DROP
   
   # 차단 해제 (필요시)
   sudo iptables -D INPUT -s 203.0.113.10 -j DROP
   ```

4. **Root 권한 최소화**
   - iptables만 sudo로 실행
   - Agent는 일반 사용자로 실행 가능

### FAQ

**Q: Ollama 없이도 충분한가요?**  
A: 네! 규칙 기반으로도 대부분의 공격을 차단할 수 있습니다. 나중에 AI를 추가하면 더 정교해집니다.

**Q: 실수로 제 IP를 차단하면?**  
A: 
```bash
# SSH로 접속 가능하면
sudo iptables -D INPUT -s YOUR_IP -j DROP

# 접속 불가하면 물리적 접근 필요
# 또는 화이트리스트에 미리 추가!
```

**Q: 웹 대시보드와 Agent 중 뭘 써야 하나요?**  
A: 둘 다 사용하세요!
- **웹 대시보드**: 수동 모니터링 + 차단
- **Agent**: 자동 방어 (24시간)

**Q: 로그가 너무 많이 쌓이면?**  
A:
```bash
# 로그 로테이션 설정
sudo nano /etc/logrotate.d/mcp-agent

/home/onestep/onestep-dashboard/agent/logs/*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
}
```

**Q: Agent가 멈추면?**  
A: Systemd가 자동 재시작합니다:
```ini
[Service]
Restart=always
RestartSec=10
```

**Q: 테스트는 어떻게?**  
A:
```bash
# 1. 테스트 트래픽 생성
curl http://testmynids.org/uid/index.html

# 2. Agent 로그 확인
tail -f logs/agent_actions.log

# 3. 웹에서 확인
http://localhost:3100
```

### 문제 발생 시 연락처

1. **로그 확인**: `tail -f logs/agent_actions.log`
2. **시스템 로그**: `sudo journalctl -u mcp-agent -f`
3. **MCP 서버 로그**: MCP 서버 실행 터미널 확인
4. **웹 대시보드**: `http://localhost:3100`

### 마지막 체크리스트

실행 전 확인:
- [ ] Python 3.7+ 설치됨
- [ ] MCP 모듈 설치됨 (`pip3 install mcp`)
- [ ] Suricata 실행 중
- [ ] `logs/`, `rules/` 디렉토리 생성됨 (자동)
- [ ] 화이트리스트 설정함
- [ ] iptables 권한 확인함
- [ ] 웹 대시보드 접속 확인함

---

**이제 준비 완료!** 🎉

```bash
cd ~/onestep-dashboard/agent
python3 mcp_agent.py
```

**즐거운 보안 자동화 되세요!** 🛡️🤖