# 🛡️ Suricata MCP Dashboard 설치 가이드

## 📋 개요

이 대시보드는 Suricata IDS와 MCP(Model Context Protocol) 서버를 연동하여 실시간 보안 이벤트를 모니터링하고 대응할 수 있는 웹 인터페이스입니다.

## 🏗️ 아키텍처

```
[Suricata IDS] → [MCP Server] → [Express Backend] → [Web Dashboard]
                  (Python)        (MCP Client)        (Browser)
```

## 📦 사전 요구사항

### 1. Suricata IDS 설치 및 실행 중
```bash
sudo apt update
sudo apt install suricata -y
sudo systemctl enable suricata
sudo systemctl start suricata
```

### 2. Python 3.8+ 및 MCP SDK
```bash
# uv 설치 (권장)
curl -LsSf https://astral.sh/uv/install.sh | sh

# 또는 pip 사용
pip3 install mcp asyncio
```

### 3. Node.js 18+
```bash
# Ubuntu
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# 확인
node --version
npm --version
```

## 🚀 설치 단계

### 1️⃣ 프로젝트 클론 또는 파일 복사

```bash
cd ~
mkdir suricata-dashboard
cd suricata-dashboard
```

다음 파일들을 프로젝트 디렉토리에 배치:
- `server.js` - Express 서버
- `mcp-client.js` - MCP 클라이언트 래퍼
- `mcp_suricata_server.py` - MCP 서버 (이미 있는 파일)
- `package.json` - Node.js 의존성
- `views/` - EJS 템플릿 디렉토리
- `public/` - 정적 파일 (CSS, JS)

### 2️⃣ Node.js 의존성 설치

```bash
npm install
```

### 3️⃣ Suricata 로그 권한 설정

```bash
# 현재 사용자를 adm 그룹에 추가
sudo usermod -a -G adm $USER

# 또는 로그 파일 권한 변경
sudo chmod 644 /var/log/suricata/eve.json

# 적용 (로그아웃 후 재로그인 또는)
newgrp adm
```

### 4️⃣ MCP 서버 실행 권한

```bash
chmod +x mcp_suricata_server.py
```

## 🎮 실행 방법

### 옵션 1: 터미널 2개 사용 (개발용)

**터미널 1 - MCP 서버:**
```bash
cd ~/suricata-dashboard
python3 mcp_suricata_server.py
```

**터미널 2 - 웹 서버:**
```bash
cd ~/suricata-dashboard
npm start
```

### 옵션 2: 자동 시작 (프로덕션용)

MCP 서버가 자동으로 시작되도록 설정되어 있으므로 웹 서버만 실행:

```bash
npm start
```

웹 브라우저에서 접속:
```
http://localhost:3000
```

## 🎯 주요 기능

### 1. 실시간 모니터링
- **Live Dashboard**: 5초마다 자동 업데이트
- **SSE (Server-Sent Events)**: 실시간 알림 스트림
- **차트 자동 갱신**: 트래픽 추세 실시간 반영

### 2. 알림 관리
- **필터링**: Action(BLOCK/ALLOW), Severity, Rule로 필터
- **검색**: IP 주소 또는 시그니처 검색
- **정렬**: 시간순 정렬

### 3. IP 차단
- **원클릭 차단**: 알림 테이블에서 바로 IP 차단
- **iptables 연동**: MCP 서버를 통해 실제 방화벽 규칙 추가

### 4. 통계 및 분석
- **KPI**: 총 알림, 차단/허용 수, 활성 호스트
- **Top Apps**: 애플리케이션별 알림 집계
- **Top Hosts**: IP별 트래픽 통계

## 🧪 테스트

### 1. Suricata 테스트 트래픽 생성

```bash
# ICMP 테스트
ping -c 10 8.8.8.8

# HTTP 테스트 (알림 발생)
curl http://testmynids.org/uid/index.html

# SSH 브루트포스 테스트 (주의!)
# 실제 브루트포스는 하지 마세요
```

### 2. 로그 확인

```bash
# Suricata 로그
sudo tail -f /var/log/suricata/eve.json

# MCP 서버 출력
# (MCP 서버 실행 터미널에서 확인)

# 웹 서버 로그
# (웹 서버 실행 터미널에서 확인)
```

### 3. API 직접 테스트

```bash
# 최근 알림 조회
curl http://localhost:3000/api/alerts?count=10

# 통계 조회
curl http://localhost:3000/api/stats

# IP 검색
curl http://localhost:3000/api/search?q=192.168

# IP 차단 (주의!)
curl -X POST http://localhost:3000/api/block-ip \
  -H "Content-Type: application/json" \
  -d '{"ip":"192.168.1.100","reason":"Test block"}'
```

## 🔧 문제 해결

### "MCP Server not connected" 에러

**원인**: MCP 서버가 실행되지 않았거나 연결 실패

**해결**:
```bash
# MCP 서버 수동 실행
python3 mcp_suricata_server.py

# 로그 확인
# "Monitoring: /var/log/suricata/eve.json" 메시지가 나와야 함
```

### "Permission denied" (Suricata 로그)

**원인**: eve.json 파일 읽기 권한 없음

**해결**:
```bash
# 권한 확인
ls -l /var/log/suricata/eve.json

# 읽기 권한 추가
sudo chmod 644 /var/log/suricata/eve.json

# 또는 그룹 추가
sudo usermod -a -G adm $USER
newgrp adm
```

### IP 차단 실패 ("Failed to block IP")

**원인**: iptables 권한 없음

**해결**:
```bash
# sudoers 설정 (조심!)
sudo visudo

# 다음 줄 추가 (youruser를 실제 사용자명으로):
youruser ALL=(ALL) NOPASSWD: /usr/sbin/iptables, /usr/sbin/ip6tables

# 또는 MCP 서버를 root로 실행
sudo python3 mcp_suricata_server.py
```

### 포트 3000 이미 사용 중

**해결**:
```bash
# 포트 변경
PORT=3001 npm start

# 또는 package.json에서 변경
```

## 🔐 보안 고려사항

### 1. 프로덕션 배포 시
- **HTTPS 사용**: Let's Encrypt 인증서 적용
- **인증 추가**: Express 세션 + 비밀번호 인증
- **CORS 제한**: 특정 도메인만 허용

### 2. IP 차단 기능
- **주의**: 실수로 자신의 IP를 차단하지 않도록 주의
- **화이트리스트**: 중요 IP는 화이트리스트에 추가
- **로깅**: 모든 차단 작업을 로그에 기록

### 3. MCP 서버 보안
- **Root 권한**: 가능하면 root로 실행하지 말 것
- **방화벽**: MCP 서버 포트는 localhost만 접근 가능하도록

## 📊 Systemd 서비스 등록 (선택)

### MCP 서버 서비스

```bash
sudo nano /etc/systemd/system/suricata-mcp.service
```

```ini
[Unit]
Description=Suricata MCP Server
After=network.target suricata.service

[Service]
Type=simple
User=root
WorkingDirectory=/home/youruser/suricata-dashboard
ExecStart=/usr/bin/python3 /home/youruser/suricata-dashboard/mcp_suricata_server.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### 웹 서버 서비스

```bash
sudo nano /etc/systemd/system/suricata-dashboard.service
```

```ini
[Unit]
Description=Suricata Dashboard
After=network.target suricata-mcp.service

[Service]
Type=simple
User=youruser
WorkingDirectory=/home/youruser/suricata-dashboard
Environment="NODE_ENV=production"
ExecStart=/usr/bin/node /home/youruser/suricata-dashboard/server.js
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### 서비스 등록 및 시작

```bash
sudo systemctl daemon-reload
sudo systemctl enable suricata-mcp
sudo systemctl enable suricata-dashboard
sudo systemctl start suricata-mcp
sudo systemctl start suricata-dashboard

# 상태 확인
sudo systemctl status suricata-mcp
sudo systemctl status suricata-dashboard

# 로그 확인
sudo journalctl -u suricata-mcp -f
sudo journalctl -u suricata-dashboard -f
```

## 🎨 UI 커스터마이징

### 테마 변경
- 브라우저에서 `Toggle Theme` 버튼 클릭
- 또는 `public/styles.css`의 `:root` 변수 수정

### 업데이트 주기 변경
`server.js`에서:
```javascript
// 5초 → 10초로 변경
const interval = setInterval(sendUpdate, 10000);
```

### 알림 보존 개수 변경
`views/dashboard.ejs`에서:
```javascript
// 100개 → 200개로 변경
if (currentAlerts.length > 200) {
  currentAlerts = currentAlerts.slice(0, 200);
}
```

## 🔄 업데이트 및 유지보수

### 코드 업데이트 후
```bash
# 서비스 재시작
sudo systemctl restart suricata-mcp
sudo systemctl restart suricata-dashboard
```

### 로그 로테이션
Suricata 로그가 계속 쌓이므로 로그 로테이션 설정 권장:
```bash
sudo nano /etc/logrotate.d/suricata
```

## 📚 API 엔드포인트

| 메서드 | 경로 | 설명 |
|--------|------|------|
| GET | `/api/alerts` | 최근 알림 조회 |
| GET | `/api/stats` | 통계 조회 |
| GET | `/api/search?q=<query>` | 알림 검색 |
| POST | `/api/block-ip` | IP 차단 |
| GET | `/api/stream` | SSE 스트림 |

## 🎯 다음 단계

1. **AI 연동**: Claude Desktop에서 MCP 서버 사용
2. **자동 대응**: 특정 패턴 감지 시 자동 차단
3. **알림**: 이메일/Slack 알림 추가
4. **리포트**: PDF 리포트 생성 기능

## 📖 참고 자료

- [MCP 공식 문서](https://modelcontextprotocol.io/)
- [Suricata 문서](https://suricata.io/)
- [Express.js 문서](https://expressjs.com/)

## 🆘 지원

문제가 발생하면 다음을 확인하세요:
1. Suricata가 실행 중인가?
2. MCP 서버가 실행 중인가?
3. 로그 파일 권한이 있는가?
4. 방화벽에서 포트 3000이 열려있는가?