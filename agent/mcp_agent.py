#!/usr/bin/env python3
"""
MCP Agent - 규칙 기반 자동 방어 시스템
우선은 Ollama, Flask 없이 순수 Python + MCP만 사용
추후 Ollama, Flask 추가 예정
"""

import asyncio
import json
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path

# MCP 클라이언트 (mcp_client.py의 코드 통합)
from subprocess import Popen, PIPE
import threading


class SimpleMCPClient:
    """간단한 MCP 클라이언트 (동기 버전)"""
    
    def __init__(self, server_script='./mcp_suricata_server.py'):
        self.server_script = server_script
        self.process = None
        self.request_id = 0
        self.pending = {}
        self.buffer = ''
        
    def connect(self):
        """MCP 서버 연결"""
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
        self._send_request('initialize', {
            'protocolVersion': '2024-11-05',
            'capabilities': {},
            'clientInfo': {'name': 'mcp-agent', 'version': '1.0.0'}
        })
        
        print('✅ MCP Agent connected to server')
    
    def _read_responses(self):
        """응답 읽기 (백그라운드)"""
        for line in self.process.stdout:
            if not line.strip():
                continue
            try:
                msg = json.loads(line)
                if 'id' in msg and msg['id'] in self.pending:
                    self.pending[msg['id']] = msg.get('result', {})
            except json.JSONDecodeError:
                pass
    
    def _send_request(self, method, params=None):
        """MCP 요청 전송"""
        self.request_id += 1
        req = {
            'jsonrpc': '2.0',
            'id': self.request_id,
            'method': method,
            'params': params or {}
        }
        
        self.pending[self.request_id] = None
        self.process.stdin.write(json.dumps(req) + '\n')
        self.process.stdin.flush()
        
        # 응답 대기 (최대 5초)
        for _ in range(50):
            if self.pending[self.request_id] is not None:
                result = self.pending.pop(self.request_id)
                return result
            asyncio.sleep(0.1)
        
        return None
    
    def get_recent_alerts(self, count=50):
        """최근 알림 조회"""
        result = self._send_request('tools/call', {
            'name': 'get_recent_alerts',
            'arguments': {'count': count}
        })
        
        if result and 'content' in result:
            content = result['content'][0].get('text', '{}')
            data = json.loads(content)
            return data.get('alerts', [])
        
        return []
    
    def block_ip(self, ip, reason='Auto blocked by Agent'):
        """IP 차단"""
        result = self._send_request('tools/call', {
            'name': 'block_ip',
            'arguments': {'ip': ip, 'reason': reason}
        })
        
        if result and 'content' in result:
            return result['content'][0].get('text', 'Failed')
        
        return 'Failed'
    
    def disconnect(self):
        """연결 종료"""
        if self.process:
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
        
        # 필수 디렉토리 생성
        self._setup_directories()
        
        # 설정
        self.config = {
            'check_interval': 60,        # 체크 주기 (초)
            'alert_threshold': 5,         # IP당 알림 임계값
            'time_window': 300,           # 시간 윈도우 (5분)
            'severity_weight': {          # 심각도 가중치
                1: 10,  # Critical
                2: 5,   # High
                3: 2,   # Medium
            },
            'auto_block': True,           # 자동 차단 활성화
            'whitelist': [                # 화이트리스트
                '127.0.0.1',
                'localhost'
            ]
        }
    
    def _setup_directories(self):
        """필요한 디렉토리와 파일 생성"""
        try:
            # logs 디렉토리
            self.logs_dir.mkdir(parents=True, exist_ok=True)
            print(f'✅ Logs directory: {self.logs_dir}')
            
            # rules 디렉토리
            self.rules_dir.mkdir(parents=True, exist_ok=True)
            print(f'✅ Rules directory: {self.rules_dir}')
            
            # .gitkeep 파일 생성
            (self.logs_dir / '.gitkeep').touch(exist_ok=True)
            (self.rules_dir / '.gitkeep').touch(exist_ok=True)
            
            # README 파일 생성 (없을 때만)
            logs_readme = self.logs_dir / 'README.md'
            if not logs_readme.exists():
                logs_readme.write_text(
                    '# Agent Action Logs\n\n'
                    'This directory contains auto-generated logs from the MCP Security Agent.\n\n'
                    '- `agent_actions.log`: All blocking actions and decisions\n'
                    '- `error.log`: Error logs (if any)\n'
                )
            
            rules_readme = self.rules_dir / 'README.md'
            if not rules_readme.exists():
                rules_readme.write_text(
                    '# Auto-generated Suricata Rules\n\n'
                    'This directory will contain auto-generated Suricata rules based on detected patterns.\n\n'
                    '(Feature coming soon)\n'
                )
            
        except Exception as e:
            print(f'⚠️  Warning: Could not create directories: {e}')
            print(f'   Agent will continue but logging may fail.')
    
    def start(self):
        """Agent 시작"""
        print('🤖 MCP Security Agent Starting...')
        print(f'⚙️  Check Interval: {self.config["check_interval"]}s')
        print(f'⚙️  Alert Threshold: {self.config["alert_threshold"]}')
        print(f'⚙️  Time Window: {self.config["time_window"]}s')
        print(f'⚙️  Auto Block: {self.config["auto_block"]}')
        print()
        
        # MCP 연결
        self.mcp.connect()
        
        # 메인 루프
        try:
            while True:
                self.analyze_and_respond()
                asyncio.sleep(self.config['check_interval'])
        except KeyboardInterrupt:
            print('\n🛑 Agent stopping...')
            self.mcp.disconnect()
    
    def analyze_and_respond(self):
        """알림 분석 및 자동 대응"""
        print(f'\n[{datetime.now().strftime("%Y-%m-%d %H:%M:%S")}] 🔍 Analyzing...')
        
        # 1. 최근 알림 가져오기
        alerts = self.mcp.get_recent_alerts(100)
        
        if not alerts:
            print('   ℹ️  No alerts found')
            return
        
        print(f'   📊 Found {len(alerts)} alerts')
        
        # 2. 패턴 분석
        threats = self.detect_threats(alerts)
        
        # 3. 위협 대응
        if threats:
            print(f'   ⚠️  Detected {len(threats)} threats')
            self.respond_to_threats(threats)
        else:
            print('   ✅ No threats detected')
    
    def detect_threats(self, alerts):
        """위협 패턴 감지"""
        threats = []
        
        # 시간 윈도우 설정
        now = datetime.now()
        window_start = now - timedelta(seconds=self.config['time_window'])
        
        # IP별 알림 집계
        ip_stats = defaultdict(lambda: {
            'count': 0,
            'score': 0,
            'signatures': set(),
            'timestamps': []
        })
        
        for alert in alerts:
            # 시간 필터
            try:
                alert_time = datetime.fromisoformat(alert['timestamp'].replace('Z', '+00:00'))
                if alert_time < window_start:
                    continue
            except:
                continue
            
            ip = alert.get('source_ip', '')
            
            # 화이트리스트 체크
            if ip in self.config['whitelist']:
                continue
            
            # 통계 업데이트
            severity = alert.get('severity', 3)
            weight = self.config['severity_weight'].get(severity, 1)
            
            ip_stats[ip]['count'] += 1
            ip_stats[ip]['score'] += weight
            ip_stats[ip]['signatures'].add(alert.get('signature', 'Unknown'))
            ip_stats[ip]['timestamps'].append(alert['timestamp'])
        
        # 위협 판정
        for ip, stats in ip_stats.items():
            # 규칙 1: 알림 횟수 초과
            if stats['count'] >= self.config['alert_threshold']:
                threats.append({
                    'ip': ip,
                    'reason': f"High alert count ({stats['count']})",
                    'score': stats['score'],
                    'count': stats['count'],
                    'signatures': list(stats['signatures'])[:3]  # 상위 3개
                })
            
            # 규칙 2: 위험 점수 높음
            elif stats['score'] >= 20:
                threats.append({
                    'ip': ip,
                    'reason': f"High risk score ({stats['score']})",
                    'score': stats['score'],
                    'count': stats['count'],
                    'signatures': list(stats['signatures'])[:3]
                })
            
            # 규칙 3: 여러 공격 시그니처
            elif len(stats['signatures']) >= 3:
                threats.append({
                    'ip': ip,
                    'reason': f"Multiple attack signatures ({len(stats['signatures'])})",
                    'score': stats['score'],
                    'count': stats['count'],
                    'signatures': list(stats['signatures'])[:3]
                })
        
        # 점수순 정렬
        threats.sort(key=lambda x: x['score'], reverse=True)
        
        return threats
    
    def respond_to_threats(self, threats):
        """위협 대응"""
        for threat in threats:
            ip = threat['ip']
            
            # 이미 차단했는지 확인
            if ip in self.blocked_ips:
                print(f'   ⏭️  {ip} already blocked')
                continue
            
            # 위협 정보 출력
            print(f'\n   🚨 THREAT DETECTED')
            print(f'      IP: {ip}')
            print(f'      Reason: {threat["reason"]}')
            print(f'      Score: {threat["score"]}')
            print(f'      Count: {threat["count"]}')
            print(f'      Signatures: {", ".join(threat["signatures"])}')
            
            # 자동 차단
            if self.config['auto_block']:
                print(f'      🔒 Auto blocking...')
                
                result = self.mcp.block_ip(
                    ip, 
                    reason=f'{threat["reason"]} (Score: {threat["score"]})'
                )
                
                if 'Success' in result or 'blocked' in result.lower():
                    print(f'      ✅ Blocked successfully')
                    self.blocked_ips.add(ip)
                    
                    # 로그 저장
                    self.log_action('BLOCK', ip, threat)
                else:
                    print(f'      ❌ Block failed: {result}')
            else:
                print(f'      ℹ️  Auto-block disabled (manual action required)')
    
    def log_action(self, action, ip, details):
        """액션 로그 저장"""
        log_entry = {
            'timestamp': datetime.now().isoformat(),
            'action': action,
            'ip': ip,
            'details': details
        }
        
        log_file = Path('agent_actions.log')
        
        with open(log_file, 'a') as f:
            f.write(json.dumps(log_entry) + '\n')


def main():
    """메인 함수"""
    print("""
    ╔═══════════════════════════════════════╗
    ║   MCP Security Agent (Rule-based)   ║
    ║   Auto Defense System v1.0          ║
    ╚═══════════════════════════════════════╝
    """)
    
    agent = SecurityAgent()
    
    # 설정 수정 (선택)
    # agent.config['alert_threshold'] = 3
    # agent.config['auto_block'] = False  # 수동 모드
    
    # Agent 시작
    agent.start()


if __name__ == '__main__':
    main()