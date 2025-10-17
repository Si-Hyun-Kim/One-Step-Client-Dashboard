#!/usr/bin/env python3
"""
Suricata MCP Server - MCP 표준 프로토콜 (stdio)
- eve.json tail (권한/파일회전 대응)
- stdout은 JSON-RPC 통신 전용, 모든 로그는 stderr로만 출력
"""

import os
import sys
import asyncio
import json
import io
from pathlib import Path
from typing import Any, Optional
from mcp.server.models import InitializationOptions
from mcp.server import NotificationOptions, Server
from mcp.server.stdio import stdio_server
from mcp.types import Resource, Tool, TextContent, ImageContent, EmbeddedResource

# ------------------ 전역 상태 ------------------
alert_history: list[dict] = []
blocked_ips: set[str] = set()

# ------------------ 유틸: 안전 로깅 ------------------
def log(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

# ------------------ Suricata 모니터 ------------------
class SuricataMonitor:
    """Suricata eve.json tail 모니터링 (회전/권한/백필 대응)"""

    def __init__(self,
                 eve_log_path: str = "/var/log/suricata/eve.json",
                 backfill_lines: int = 0):
        self.eve_log_path = Path(eve_log_path)
        self.backfill_lines = max(0, backfill_lines)
        self._fd: Optional[io.TextIOBase] = None
        self._inode: Optional[int] = None
        self.running = False

    async def start(self):
        self.running = True
        # 파일 준비 대기
        while not self.eve_log_path.exists():
            log(f"[MCP] Waiting for {self.eve_log_path} ...")
            await asyncio.sleep(1)

        await self._open_file(initial=True)
        log(f"[MCP] Monitoring: {self.eve_log_path}")

        while self.running:
            try:
                await self._reopen_if_rotated()
                await self._drain_new_lines()
            except PermissionError:
                log("[MCP] Permission denied reading eve.json. "
                    "Try: sudo usermod -aG suricata $USER && newgrp suricata")
                await asyncio.sleep(2)
            except FileNotFoundError:
                log("[MCP] eve.json not found (rotating?). Re-trying...")
                await asyncio.sleep(1)
            except Exception as e:
                log(f"[MCP] Error reading eve.json: {e}")
                await asyncio.sleep(0.5)
            await asyncio.sleep(0.01)

    async def _open_file(self, initial=False):
        # 텍스트 모드, 유니버설 뉴라인
        self._fd = open(self.eve_log_path, "r", encoding="utf-8", errors="ignore")
        stat = self.eve_log_path.stat()
        self._inode = stat.st_ino

        if initial:
            if self.backfill_lines > 0:
                # 최근 N 라인 백필
                try:
                    self._fd.seek(0, 2)
                    size = self._fd.tell()
                    block = 4096
                    chunks = []
                    read = 0
                    while size > 0 and len(chunks) < 1024:
                        step = min(block, size)
                        size -= step
                        self._fd.seek(size)
                        data = self._fd.read(step)
                        chunks.append(data)
                        if data.count("\n") >= self.backfill_lines:
                            break
                    buf = "".join(reversed(chunks))
                    lines = buf.splitlines()[-self.backfill_lines:]
                    for line in lines:
                        self._consume_line(line)
                except Exception as e:
                    log(f"[MCP] backfill failed: {e}")
                # 이후 끝으로
                self._fd.seek(0, 2)
            else:
                # 끝으로 이동 (tail -f)
                self._fd.seek(0, 2)

    async def _reopen_if_rotated(self):
        if not self._fd:
            await self._open_file()
            return
        try:
            stat = self.eve_log_path.stat()
        except FileNotFoundError:
            # 회전 직후
            self._fd.close()
            self._fd = None
            self._inode = None
            raise
        if self._inode is not None and stat.st_ino != self._inode:
            # inode 변경 → 회전
            try:
                self._fd.close()
            except Exception:
                pass
            await self._open_file()

    async def _drain_new_lines(self):
        if not self._fd:
            return
        while True:
            pos = self._fd.tell()
            line = self._fd.readline()
            if not line:
                self._fd.seek(pos)
                break
            self._consume_line(line)

    def _consume_line(self, line: str):
        s = line.strip()
        if not s:
            return
        try:
            event = json.loads(s)
        except json.JSONDecodeError:
            return
        # alert 타입만 수집
        if event.get("event_type") != "alert":
            return
        self._process_alert(event)

    def _process_alert(self, event: dict):
        # Suricata 포맷을 평탄화하여 양쪽 키를 모두 제공
        alert = event.get("alert", {}) or {}
        info = {
            # 공통
            "timestamp": event.get("timestamp", ""),
            "protocol": event.get("proto", ""),
            "category": alert.get("category", ""),
            "severity": alert.get("severity", 3),
            "signature": alert.get("signature", ""),

            # 원본 키도 유지 (참고)
            "src_ip": event.get("src_ip", ""),
            "dest_ip": event.get("dest_ip", ""),
            "src_port": event.get("src_port", 0),
            "dest_port": event.get("dest_port", 0),

            # 에이전트 호환 키
            "source_ip": event.get("src_ip", ""),
            "dest_ip": event.get("dest_ip", ""),
            "source_port": event.get("src_port", 0),
            "dest_port": event.get("dest_port", 0),
        }

        alert_history.append(info)
        # 메모리 보호: 최근 1000개만 유지
        if len(alert_history) > 1000:
            del alert_history[: len(alert_history) - 1000]

# ------------------ MCP 서버 ------------------
server = Server("suricata-mcp-server")
# 경로는 환경변수 EVE_LOG 로 재정의 가능
eve_path = os.environ.get("EVE_LOG", "/var/log/suricata/eve.json")
# 시작 시 최근 50라인 백필(원치 않으면 0)
monitor = SuricataMonitor(eve_log_path=eve_path, backfill_lines=50)

@server.list_resources()
async def handle_list_resources() -> list[Resource]:
    return [
        Resource(
            uri="suricata://alerts",
            name="Suricata Alerts",
            description="Recent security alerts from Suricata IDS",
            mimeType="application/json",
        ),
        Resource(
            uri="suricata://blocked_ips",
            name="Blocked IPs",
            description="List of blocked IP addresses",
            mimeType="application/json",
        ),
    ]

@server.read_resource()
async def handle_read_resource(uri: str) -> str:
    if uri == "suricata://alerts":
        return json.dumps({"total": len(alert_history), "alerts": alert_history[-50:]}, indent=2)
    if uri == "suricata://blocked_ips":
        return json.dumps({"total": len(blocked_ips), "ips": list(blocked_ips)}, indent=2)
    raise ValueError(f"Unknown resource: {uri}")

@server.list_tools()
async def handle_list_tools() -> list[Tool]:
    return [
        Tool(
            name="get_recent_alerts",
            description="Get recent security alerts from Suricata",
            inputSchema={
                "type": "object",
                "properties": {
                    "count": {"type": "number", "default": 10},
                    "severity": {"type": "number", "minimum": 1, "maximum": 3},
                },
            },
        ),
        Tool(
            name="block_ip",
            description="Block an IP address using iptables/ip6tables",
            inputSchema={
                "type": "object",
                "properties": {
                    "ip": {"type": "string"},
                    "reason": {"type": "string"},
                },
                "required": ["ip"],
            },
        ),
        Tool(
            name="get_alert_stats",
            description="Get statistics about security alerts",
            inputSchema={"type": "object", "properties": {}},
        ),
        Tool(
            name="search_alerts",
            description="Search alerts by IP address or signature",
            inputSchema={
                "type": "object",
                "properties": {"query": {"type": "string"}},
                "required": ["query"],
            },
        ),
        Tool(  # 통신/파이프라인 점검용
            name="inject_test_alert",
            description="Inject a synthetic alert into memory for testing",
            inputSchema={
                "type": "object",
                "properties": {
                    "ip": {"type": "string", "default": "10.10.10.10"},
                    "signature": {"type": "string", "default": "TEST ICMP Ping detected"},
                    "severity": {"type": "number", "default": 3},
                },
            },
        ),
    ]

@server.call_tool()
async def handle_call_tool(name: str, arguments: dict | None) -> list[TextContent | ImageContent | EmbeddedResource]:
    args = arguments or {}

    if name == "get_recent_alerts":
        count = int(args.get("count", 10))
        sev = args.get("severity", None)
        alerts = alert_history[-count:]
        if sev is not None:
            try:
                s = int(sev)
                alerts = [a for a in alerts if int(a.get("severity", 3)) == s]
            except Exception:
                pass
        return [TextContent(type="text", text=json.dumps({"count": len(alerts), "alerts": alerts}, indent=2))]

    if name == "block_ip":
        ip = args.get("ip")
        if not ip:
            raise ValueError("IP address required")
        reason = args.get("reason", "Security threat")
        is_ipv6 = ":" in ip
        cmd = ["sudo", "ip6tables" if is_ipv6 else "iptables", "-A", "INPUT", "-s", ip, "-j", "DROP"]
        try:
            import subprocess
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode == 0:
                blocked_ips.add(ip)
                return [TextContent(type="text", text=f"Successfully blocked {ip}. Reason: {reason}")]
            return [TextContent(type="text", text=f"Failed to block {ip}: {result.stderr}")]
        except Exception as e:
            return [TextContent(type="text", text=f"Error blocking {ip}: {e}")]

    if name == "get_alert_stats":
        total = len(alert_history)
        by_severity: dict[int, int] = {}
        by_category: dict[str, int] = {}
        top_sources: dict[str, int] = {}

        for a in alert_history:
            sev = int(a.get("severity", 3))
            by_severity[sev] = by_severity.get(sev, 0) + 1
            cat = a.get("category", "unknown") or "unknown"
            by_category[cat] = by_category.get(cat, 0) + 1
            src = a.get("source_ip") or a.get("src_ip") or "unknown"
            top_sources[src] = top_sources.get(src, 0) + 1

        top_5 = dict(sorted(top_sources.items(), key=lambda x: x[1], reverse=True)[:5])
        stats = {"total_alerts": total, "by_severity": by_severity, "by_category": by_category,
                 "top_sources": top_5, "blocked_ips": len(blocked_ips)}
        return [TextContent(type="text", text=json.dumps(stats, indent=2))]

    if name == "search_alerts":
        q = str(args.get("query", "")).lower()
        results = []
        for a in alert_history:
            if q in (a.get("source_ip", "") or "").lower() \
               or q in (a.get("dest_ip", "") or "").lower() \
               or q in (a.get("signature", "") or "").lower():
                results.append(a)
        return [TextContent(type="text", text=json.dumps({"query": q, "results": len(results), "alerts": results[-20:]}, indent=2))]

    if name == "inject_test_alert":
        ip = args.get("ip", "10.10.10.10")
        sig = args.get("signature", "TEST ICMP Ping detected")
        sev = int(args.get("severity", 3))
        alert_history.append({
            "timestamp": "2099-01-01T00:00:00Z",
            "protocol": "ICMP",
            "category": "Test",
            "severity": sev,
            "signature": sig,
            "src_ip": ip, "dest_ip": "1.1.1.1", "src_port": 0, "dest_port": 0,
            "source_ip": ip, "dest_ip": "1.1.1.1", "source_port": 0, "dest_port": 0,
        })
        return [TextContent(type="text", text="Injected one synthetic alert")]

    raise ValueError(f"Unknown tool: {name}")

# ------------------ 엔트리 ------------------
async def main():
    # Suricata 모니터 시작
    monitor_task = asyncio.create_task(monitor.start())

    # MCP 서버 실행 (stdio)
    async with stdio_server() as (read_stream, write_stream):
        log("Suricata MCP Server started (stdio)")
        await server.run(
            read_stream,
            write_stream,
            InitializationOptions(
                server_name="suricata-mcp-server",
                server_version="1.1.0",
                capabilities=server.get_capabilities(
                    notification_options=NotificationOptions(),
                    experimental_capabilities={},
                ),
            ),
        )

if __name__ == "__main__":
    asyncio.run(main())
