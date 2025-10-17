// server.js
import express from "express";
import cors from "cors";
import path from "path";
import { fileURLToPath } from "url";
import { getMCPClient } from "./mcp-client.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, "public")));

app.set("view engine", "ejs");
app.set("views", path.join(__dirname, "views"));

// MCP 클라이언트 초기화
let mcpClient = null;
let isConnecting = false;

async function ensureMCPConnection() {
  if (mcpClient) return mcpClient;
  
  if (isConnecting) {
    // 연결 중이면 대기
    await new Promise(resolve => setTimeout(resolve, 100));
    return ensureMCPConnection();
  }

  try {
    isConnecting = true;
    mcpClient = await getMCPClient();
    console.log('✅ MCP Client connected');
    return mcpClient;
  } catch (error) {
    console.error('❌ MCP Connection failed:', error.message);
    throw error;
  } finally {
    isConnecting = false;
  }
}

// 루트 리다이렉트
app.get("/", (_req, res) => res.redirect("/dashboard"));

// Dashboard - 실제 MCP 데이터 사용
app.get("/dashboard", async (_req, res) => {
  try {
    const client = await ensureMCPConnection();
    
    // 병렬로 데이터 가져오기
    const [alertsData, statsData] = await Promise.all([
      client.getRecentAlerts(20),
      client.getAlertStats()
    ]);

    // 알림 데이터 가공
    const alerts = (alertsData.alerts || []).map(a => ({
      id: `AL-${Date.parse(a.timestamp)}`,
      timestamp: a.timestamp,
      source_ip: a.source_ip,
      dest_ip: a.dest_ip,
      action: Math.random() > 0.3 ? 'BLOCK' : 'ALLOW', // 임시
      severity: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'][a.severity - 1] || 'MEDIUM',
      rule: a.signature
    }));

    // 시계열 데이터 생성 (최근 1시간, 10분 단위)
    const now = new Date();
    const labels = [];
    const blockedSeries = [];
    const allowedSeries = [];

    for (let i = 6; i >= 0; i--) {
      const time = new Date(now.getTime() - i * 10 * 60 * 1000);
      const hh = String(time.getHours()).padStart(2, '0');
      const mm = String(time.getMinutes()).padStart(2, '0');
      labels.push(`${hh}:${mm}`);
      
      // 해당 시간대의 알림 카운트
      const timeStart = time.getTime();
      const timeEnd = timeStart + 10 * 60 * 1000;
      
      let blocked = 0, allowed = 0;
      alerts.forEach(a => {
        const ts = Date.parse(a.timestamp);
        if (ts >= timeStart && ts < timeEnd) {
          if (a.action === 'BLOCK') blocked++;
          else allowed++;
        }
      });
      
      blockedSeries.push(blocked);
      allowedSeries.push(allowed);
    }

    // Top Apps (카테고리별 집계)
    const appCounts = {};
    alerts.forEach(a => {
      // 시그니처에서 앱 이름 추출 시도
      const sig = a.rule || '';
      let app = 'Other';
      
      if (sig.includes('HTTP')) app = 'HTTP';
      else if (sig.includes('DNS')) app = 'DNS';
      else if (sig.includes('SSH')) app = 'SSH';
      else if (sig.includes('TLS') || sig.includes('SSL')) app = 'TLS/SSL';
      
      appCounts[app] = (appCounts[app] || 0) + 1;
    });

    const topApps = Object.entries(appCounts)
      .map(([name, count]) => ({ name, bytes: count }))
      .sort((a, b) => b.bytes - a.bytes)
      .slice(0, 5);

    // Summary 데이터
    const summary = {
      kpis: {
        totalAlerts: alerts.length,
        blocked: alerts.filter(a => a.action === 'BLOCK').length,
        allowed: alerts.filter(a => a.action === 'ALLOW').length,
        activeHosts: new Set([
          ...alerts.map(a => a.source_ip),
          ...alerts.map(a => a.dest_ip)
        ].filter(Boolean)).size,
        cpuLoad: 0 // MCP 서버에서는 제공 안함
      },
      timeseries: {
        labels,
        blocked: blockedSeries,
        allowed: allowedSeries
      },
      topApps
    };

    res.render("dashboard", { active: "dashboard", alerts, summary });
  } catch (error) {
    console.error('Dashboard error:', error);
    
    // 연결 실패 시 더미 데이터로 폴백
    const dummyData = {
      alerts: [],
      summary: {
        kpis: { totalAlerts: 0, blocked: 0, allowed: 0, activeHosts: 0, cpuLoad: 0 },
        timeseries: { labels: ['00:00'], blocked: [0], allowed: [0] },
        topApps: []
      }
    };
    
    res.render("dashboard", { 
      active: "dashboard", 
      alerts: dummyData.alerts, 
      summary: dummyData.summary,
      error: 'MCP Server not connected. Please start mcp_suricata_server.py'
    });
  }
});

// API: 실시간 알림 가져오기
app.get("/api/alerts", async (req, res) => {
  try {
    const client = await ensureMCPConnection();
    const count = parseInt(req.query.count) || 50;
    const severity = req.query.severity;
    
    const data = await client.getRecentAlerts(count);
    
    let alerts = (data.alerts || []).map(a => ({
      id: `AL-${Date.parse(a.timestamp)}`,
      timestamp: a.timestamp,
      source_ip: a.source_ip,
      dest_ip: a.dest_ip,
      source_port: a.source_port,
      dest_port: a.dest_port,
      protocol: a.protocol,
      action: Math.random() > 0.3 ? 'BLOCK' : 'ALLOW',
      severity: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'][a.severity - 1] || 'MEDIUM',
      rule: a.signature,
      category: a.category
    }));

    // Severity 필터
    if (severity) {
      alerts = alerts.filter(a => a.severity === severity);
    }

    res.json({ success: true, count: alerts.length, alerts });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// API: 통계
app.get("/api/stats", async (req, res) => {
  try {
    const client = await ensureMCPConnection();
    const stats = await client.getAlertStats();
    
    res.json({ success: true, stats });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// API: IP 차단
app.post("/api/block-ip", async (req, res) => {
  try {
    const { ip, reason } = req.body;
    
    if (!ip) {
      return res.status(400).json({ success: false, error: 'IP address required' });
    }

    const client = await ensureMCPConnection();
    const result = await client.blockIP(ip, reason || 'Blocked from dashboard');
    
    res.json({ success: true, message: result });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// API: 알림 검색
app.get("/api/search", async (req, res) => {
  try {
    const query = req.query.q;
    
    if (!query) {
      return res.status(400).json({ success: false, error: 'Query required' });
    }

    const client = await ensureMCPConnection();
    const data = await client.searchAlerts(query);
    
    const alerts = (data.alerts || []).map(a => ({
      id: `AL-${Date.parse(a.timestamp)}`,
      timestamp: a.timestamp,
      source_ip: a.source_ip,
      dest_ip: a.dest_ip,
      source_port: a.source_port,
      dest_port: a.dest_port,
      protocol: a.protocol,
      action: Math.random() > 0.3 ? 'BLOCK' : 'ALLOW',
      severity: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'][a.severity - 1] || 'MEDIUM',
      rule: a.signature
    }));

    res.json({ success: true, query, results: data.results, alerts });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// SSE: 실시간 알림 스트림
app.get("/api/stream", async (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  const sendUpdate = async () => {
    try {
      const client = await ensureMCPConnection();
      const data = await client.getRecentAlerts(5);
      
      res.write(`data: ${JSON.stringify(data)}\n\n`);
    } catch (error) {
      res.write(`data: ${JSON.stringify({ error: error.message })}\n\n`);
    }
  };

  // 즉시 전송
  await sendUpdate();

  // 5초마다 업데이트
  const interval = setInterval(sendUpdate, 5000);

  req.on('close', () => {
    clearInterval(interval);
    res.end();
  });
});

// Policies (더미 유지)
app.get("/policies", (_req, res) => {
  const policies = [
    { name: "Default Policy", apps: 15, sessions: 65, trafficPct: 60 },
    { name: "Teacher Policy", apps: 12, sessions: 20, trafficPct: 8 },
    { name: "Student Policy", apps: 10, sessions: 40, trafficPct: 18 },
    { name: "Admin Policy",   apps:  8, sessions: 15, trafficPct: 14 }
  ];
  res.render("policies", { active: "policies", policies });
});

// Hosts (MCP 데이터에서 추출)
app.get("/hosts", async (_req, res) => {
  try {
    const client = await ensureMCPConnection();
    const alertsData = await client.getRecentAlerts(100);
    
    // IP별 집계
    const ipStats = {};
    
    (alertsData.alerts || []).forEach(a => {
      const ip = a.source_ip;
      if (!ip) return;
      
      if (!ipStats[ip]) {
        ipStats[ip] = { ip, bytes: 0, blocked: 0, allowed: 0 };
      }
      
      ipStats[ip].bytes += Math.random() * 5; // 임시
      
      if (Math.random() > 0.5) ipStats[ip].blocked++;
      else ipStats[ip].allowed++;
    });

    const hosts = Object.values(ipStats)
      .map(h => ({
        ...h,
        bytes: parseFloat(h.bytes.toFixed(1))
      }))
      .sort((a, b) => b.bytes - a.bytes)
      .slice(0, 20);

    res.render("hosts", { active: "hosts", hosts });
  } catch (error) {
    console.error('Hosts error:', error);
    res.render("hosts", { active: "hosts", hosts: [] });
  }
});

// Apps (시그니처 기반 집계)
app.get("/apps", async (_req, res) => {
  try {
    const client = await ensureMCPConnection();
    const alertsData = await client.getRecentAlerts(100);
    
    const appCounts = {};
    
    (alertsData.alerts || []).forEach(a => {
      const sig = a.signature || '';
      let app = 'Other';
      
      if (sig.includes('HTTP')) app = 'HTTP';
      else if (sig.includes('DNS')) app = 'DNS';
      else if (sig.includes('SSH')) app = 'SSH';
      else if (sig.includes('TLS') || sig.includes('SSL')) app = 'TLS/SSL';
      else if (sig.includes('SMTP')) app = 'SMTP';
      
      appCounts[app] = (appCounts[app] || 0) + 1;
    });

    const total = Object.values(appCounts).reduce((a, b) => a + b, 0) || 1;
    
    const apps = Object.entries(appCounts)
      .map(([name, count]) => ({
        name,
        pct: parseFloat(((count / total) * 100).toFixed(1))
      }))
      .sort((a, b) => b.pct - a.pct);

    res.render("apps", { active: "apps", apps });
  } catch (error) {
    console.error('Apps error:', error);
    res.render("apps", { active: "apps", apps: [] });
  }
});

// Alerts (전체 보기)
app.get("/alerts", async (_req, res) => {
  try {
    const client = await ensureMCPConnection();
    const alertsData = await client.getRecentAlerts(100);
    
    const alerts = (alertsData.alerts || [])
      .filter(a => a.timestamp)
      .map(a => ({
        id: `AL-${Date.parse(a.timestamp)}`,
        timestamp: a.timestamp,
        source_ip: a.source_ip,
        dest_ip: a.dest_ip,
        action: Math.random() > 0.3 ? 'BLOCK' : 'ALLOW',
        severity: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'][a.severity - 1] || 'MEDIUM',
        rule: a.signature
      }));

    res.render("alerts", { active: "alerts", alerts });
  } catch (error) {
    console.error('Alerts error:', error);
    res.render("alerts", { active: "alerts", alerts: [] });
  }
});

// Reports (더미 유지)
app.get("/reports", (_req, res) => {
  const reports = [
    { id: "RPT-2025-09-01", title: "Weekly Traffic Summary", period: "Aug 25—31" },
    { id: "RPT-2025-09-08", title: "Top Talkers & Apps", period: "Sep 1—7" }
  ];
  res.render("reports", { active: "reports", reports });
});

// Settings
app.get("/settings", (_req, res) => {
  const settings = { timezone: "Asia/Seoul", theme: "auto", apiKeySet: false };
  res.render("settings", { active: "settings", settings });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, async () => {
  console.log(`✅ Server running on http://localhost:${PORT}`);
  
  // 서버 시작 시 MCP 연결 시도
  try {
    await ensureMCPConnection();
  } catch (error) {
    console.warn('⚠️  MCP Server not available. Please start mcp_suricata_server.py');
  }
});

// 종료 시 정리
process.on('SIGINT', () => {
  console.log('\n🛑 Shutting down...');
  if (mcpClient) {
    mcpClient.disconnect();
  }
  process.exit(0);
});