#!/usr/bin/env python3
"""
MCP Agent - 규칙 기반 자동 방어 시스템
- Suricata eve.json 필드 호환 파싱 (src_ip, alert.signature, alert.severity 등)
- agent_config.json 로드/병합 지원
"""

import json
import time
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path
from subprocess import Popen, PIPE
import threading


class SimpleMCPClient:
    """간단한 MCP 클라이언트 (동기 버전)"""

    def __init__(self, server_script=None):
        # 프로젝트 루트(…/One-Step-Client-Dashboard-main)
        self.root = Path(__file__).resolve().parents[1]

        # 서버 스크립트 절대경로 계산
        if server_script is None:
            candidate = self.root / 'mcp_suricata_server.py'
        else:
            candidate = Path(server_script)
            candidate = candidate if candidate.is_absolute() else (self.root / candidate)

        self.server_script = str(candidate.resolve())
        self.process = None
        self.request_id = 0
        self.pending = {}

    def connect(self):
        """MCP 서버 연결(에이전트가 자식 프로세스로 서버를 띄움)"""
        server_path = Path(self.server_script)
        if not server_path.exists():
            raise FileNotFoundError(
                f"[MCP] 서버 스크립트를 찾을 수 없습니다: {server_path}\n"
                f"실행 위치: {Path.cwd()}\n"
                f"에이전트 파일: {Path(__file__).resolve()}\n"
                f"※ 프로젝트 루트에서 실행하거나, server_script 경로를 확인하세요."
            )

        self.process = Popen(
            ['python3', self.server_script],
            stdin=PIPE,
            stdout=PIPE,
            stderr=PIPE,
            text=True,
            bufsize=1
        )

        # 응답 읽기 스레드
        threading.Thread(target=self._read_responses, daemon=True).start()

        # 초기화
        init_res = self._send_request('initialize', {
            'protocolVersion': '2024-11-05',
            'capabilities': {},
            'clientInfo': {'name': 'mcp-agent', 'version': '1.0.0'}
        })
        if init_res is None:
            raise RuntimeError("[MCP] 서버 초기화 응답이 없습니다. 서버가 즉시 종료되었을 수 있습니다.")

        print(f'✅ MCP Agent connected to server ({server_path})')

    def _read_responses(self):
        """서버 stdout에서 JSON-RPC 응답 읽기"""
        for line in self.process.stdout:
            s = line.strip()
            if not s:
                continue
            try:
                msg = json.loads(s)
            except json.JSONDecodeError:
                continue
            if 'id' in msg and msg['id'] in self.pending:
                # 정상 결과 또는 에러를 그대로 저장
                result = msg.get('result')
                if result is None and 'error' in msg:
                    result = {'error': msg['error']}
                self.pending[msg['id']] = result

    def _send_request(self, method, params=None):
        """MCP 요청 전송 + 최대 5초 대기"""
        self.request_id += 1
        req_id = self.request_id
        req = {'jsonrpc': '2.0', 'id': req_id, 'method': method, 'params': params or {}}
        self.pending[req_id] = None

        try:
            self.process.stdin.write(json.dumps(req) + '\n')
            self.process.stdin.flush()
        except BrokenPipeError:
            return {'error': {'message': 'Broken pipe: server process is not accepting input'}}

        for _ in range(50):  # 5s
            if self.pending[req_id] is not None:
                return self.pending.pop(req_id)
            time.sleep(0.1)

        self.pending.pop(req_id, None)
        return None

    def get_recent_alerts(self, count=50):
        """최근 알림 조회 (서버가 alerts JSON 문자열을 content[0].text로 전달한다고 가정)"""
        result = self._send_request('tools/call', {
            'name': 'get_recent_alerts',
            'arguments': {'count': count}
        })

        if not result:
            return []
        if 'error' in result:
            print(f"⚠️  MCP error(get_recent_alerts): {result['error']}")
            return []

        if 'content' in result and result['content']:
            content = result['content'][0].get('text', '{}')
            try:
                data = json.loads(content)
                return data.get('alerts', [])
            except json.JSONDecodeError:
                print("⚠️  MCP content JSON decode error")
        return []

    def block_ip(self, ip, reason='Auto blocked by Agent'):
        """IP 차단"""
        result = self._send_request('tools/call', {
            'name': 'block_ip',
            'arguments': {'ip': ip, 'reason': reason}
        })

        if not result:
            return 'Failed: no response'
        if 'error' in result:
            return f"Failed: {result['error']}"

        if 'content' in result and result['content']:
            return result['content'][0].get('text', 'Failed')
        return 'Failed'

    def disconnect(self):
        """연결 종료"""
        if self.process:
            try:
                self.process.stdin.close()
            except Exception:
                pass
            self.process.terminate()


class SecurityAgent:
    """보안 자동 대응 Agent"""

    def __init__(self):
        self.mcp = SimpleMCPClient()
        self.blocked_ips = set()
        self.alert_history = []

        # 디렉토리 구조 설정
        self.base_dir = Path(__file__).parent
        self.logs_dir = self.base_dir / 'logs'
        self.rules_dir = self.base_dir / 'rules'
        self._setup_directories()

        # 기본 설정
        self.config = {
            'check_interval': 60,
            'alert_threshold': 5,
            'time_window': 300,
            'severity_weight': {1: 10, 2: 5, 3: 2},
            'auto_block': True,
            'whitelist': ['127.0.0.1', 'localhost']
        }

        # agent_config.json 로드/병합
        cfg_file = Path(__file__).with_name('agent_config.json')
        if cfg_file.exists():
            try:
                user_cfg = json.load(open(cfg_file))
                # 가중치 키가 문자열이면 int로 변환
                if 'severity_weight' in user_cfg:
                    sw = user_cfg['severity_weight']
                    user_cfg['severity_weight'] = {int(k): v for k, v in sw.items()}
                # 필요한 키만 덮어쓰기
                for k in ['check_interval', 'alert_threshold', 'time_window',
                          'severity_weight', 'auto_block', 'whitelist']:
                    if k in user_cfg:
                        self.config[k] = user_cfg[k]
                print('🧩 Loaded agent_config.json')
            except Exception as e:
                print(f'⚠️  agent_config.json 로드 실패: {e}')

    # ---------- 파일/디렉토리 준비 ----------
    def _setup_directories(self):
        try:
            self.logs_dir.mkdir(parents=True, exist_ok=True)
            print(f'✅ Logs directory: {self.logs_dir}')
            self.rules_dir.mkdir(parents=True, exist_ok=True)
            print(f'✅ Rules directory: {self.rules_dir}')
            (self.logs_dir / '.gitkeep').touch(exist_ok=True)
            (self.rules_dir / '.gitkeep').touch(exist_ok=True)
        except Exception as e:
            print(f'⚠️  Warning: Could not create directories: {e}')
            print('   Agent will continue but logging may fail.')

    # ---------- 유틸: Suricata 호환 파서 ----------
    def _parse_ts(self, s: str):
        """ISO8601 (Z/오프셋/마이크로초) 대응"""
        try:
            if s.endswith('Z'):
                return datetime.fromisoformat(s[:-1]).replace(tzinfo=timezone.utc)
            return datetime.fromisoformat(s)
        except Exception:
            return None

    def _extract_ip(self, alert: dict):
        """src_ip 우선, 서버가 가공해 보낸 source_ip도 지원"""
        return (
            alert.get('source_ip')
            or alert.get('src_ip')
            or alert.get('src')  # 혹시 모를 다른 키
            or ''
        )

    def _extract_severity(self, alert: dict):
        """상위 severity 또는 Suricata alert.severity"""
        if 'severity' in alert:
            return int(alert['severity'])
        return int(alert.get('alert', {}).get('severity', 3))

    def _extract_signature(self, alert: dict):
        """상위 signature 또는 Suricata alert.signature"""
        if 'signature' in alert:
            return alert['signature']
        return alert.get('alert', {}).get('signature', 'Unknown')

    # ---------- 메인 루프 ----------
    def start(self):
        print('🤖 MCP Security Agent Starting...')
        print(f'⚙️  Check Interval: {self.config["check_interval"]}s')
        print(f'⚙️  Alert Threshold: {self.config["alert_threshold"]}')
        print(f'⚙️  Time Window: {self.config["time_window"]}s')
        print(f'⚙️  Auto Block: {self.config["auto_block"]}\n')

        self.mcp.connect()

        try:
            while True:
                self.analyze_and_respond()
                time.sleep(self.config['check_interval'])
        except KeyboardInterrupt:
            print('\n🛑 Agent stopping...')
        finally:
            self.mcp.disconnect()

    def analyze_and_respond(self):
        print(f'\n[{datetime.now().strftime("%Y-%m-%d %H:%M:%S")}] 🔍 Analyzing...')
        alerts = self.mcp.get_recent_alerts(100)

        if not alerts:
            print('   ℹ️  No alerts found')
            return

        print(f'   📊 Found {len(alerts)} alerts')
        threats = self.detect_threats(alerts)

        if threats:
            print(f'   ⚠️  Detected {len(threats)} threats')
            self.respond_to_threats(threats)
        else:
            print('   ✅ No threats detected')

    def detect_threats(self, alerts):
        threats = []
        now = datetime.now(timezone.utc)
        window_start = now - timedelta(seconds=self.config['time_window'])

        ip_stats = defaultdict(lambda: {
            'count': 0,
            'score': 0,
            'signatures': set(),
            'timestamps': []
        })

        for alert in alerts:
            # 시간 필터
            ts = alert.get('timestamp')
            t = self._parse_ts(ts) if ts else None
            if not t or t < window_start:
                continue

            ip = self._extract_ip(alert)
            if not ip or ip in self.config['whitelist']:
                continue

            severity = self._extract_severity(alert)
            weight = self.config['severity_weight'].get(int(severity), 1)

            sig = self._extract_signature(alert)

            ip_stats[ip]['count'] += 1
            ip_stats[ip]['score'] += weight
            ip_stats[ip]['signatures'].add(sig)
            ip_stats[ip]['timestamps'].append(ts)

        for ip, stats in ip_stats.items():
            if stats['count'] >= self.config['alert_threshold']:
                threats.append({
                    'ip': ip,
                    'reason': f"High alert count ({stats['count']})",
                    'score': stats['score'],
                    'count': stats['count'],
                    'signatures': list(stats['signatures'])[:3]
                })
            elif stats['score'] >= 20:
                threats.append({
                    'ip': ip,
                    'reason': f"High risk score ({stats['score']})",
                    'score': stats['score'],
                    'count': stats['count'],
                    'signatures': list(stats['signatures'])[:3]
                })
            elif len(stats['signatures']) >= 3:
                threats.append({
                    'ip': ip,
                    'reason': f"Multiple attack signatures ({len(stats['signatures'])})",
                    'score': stats['score'],
                    'count': stats['count'],
                    'signatures': list(stats['signatures'])[:3]
                })

        threats.sort(key=lambda x: x['score'], reverse=True)
        return threats

    def respond_to_threats(self, threats):
        for threat in threats:
            ip = threat['ip']
            if ip in self.blocked_ips:
                print(f'   ⏭️  {ip} already blocked')
                continue

            print(f'\n   🚨 THREAT DETECTED')
            print(f'      IP: {ip}')
            print(f'      Reason: {threat["reason"]}')
            print(f'      Score: {threat["score"]}')
            print(f'      Count: {threat["count"]}')
            print(f'      Signatures: {", ".join(threat["signatures"])}')

            if self.config['auto_block']:
                print(f'      🔒 Auto blocking...')
                result = self.mcp.block_ip(ip, reason=f'{threat["reason"]} (Score: {threat["score"]})')

                if isinstance(result, str) and ('Success' in result or 'blocked' in result.lower()):
                    print(f'      ✅ Blocked successfully')
                    self.blocked_ips.add(ip)
                    self.log_action('BLOCK', ip, threat)
                else:
                    print(f'      ❌ Block failed: {result}')
            else:
                print(f'      ℹ️  Auto-block disabled (manual action required)')

    def log_action(self, action, ip, details):
        log_entry = {
            'timestamp': datetime.now().isoformat(),
            'action': action,
            'ip': ip,
            'details': details
        }
        log_file = self.logs_dir / 'agent_actions.log'
        with open(log_file, 'a') as f:
            f.write(json.dumps(log_entry) + '\n')


def main():
    print("""
    ╔═══════════════════════════════════════╗
    ║   MCP Security Agent (Rule-based)     ║
    ║   Auto Defense System v1.0            ║
    ╚═══════════════════════════════════════╝
    """)
    agent = SecurityAgent()
    agent.start()


if __name__ == '__main__':
    main()
