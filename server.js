// server.js

import express from "express";
import cors from "cors";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

import reportsRouter from "./routes/reports.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, "public")));

app.set("view engine", "ejs");
app.set("views", path.join(__dirname, "views"));

// 편의: / → /dashboard
app.get("/", (_req, res) => res.redirect("/dashboard"));

// 공통 더미 데이터 로더
const readJSON = (fp) => JSON.parse(fs.readFileSync(fp, "utf-8"));

// Dashboard
app.get("/dashboard", (_req, res) => {
  const alerts = readJSON(path.join(__dirname, "data", "alerts.json"));
  const summary = readJSON(path.join(__dirname, "data", "summary.json"));
  res.render("dashboard", { active: "dashboard", alerts, summary });
});

// Policies
app.get("/policies", (_req, res) => {
  const policies = [
    { name: "Default Policy", apps: 15, sessions: 65, trafficPct: 60 },
    { name: "Teacher Policy", apps: 12, sessions: 20, trafficPct: 8 },
    { name: "Student Policy", apps: 10, sessions: 40, trafficPct: 18 },
    { name: "Admin Policy",   apps:  8, sessions: 15, trafficPct: 14 }
  ];
  res.render("policies", { active: "policies", policies });
});

// Hosts
app.get("/hosts", (_req, res) => {
  const hosts = [
    { ip: "192.168.0.2", bytes: 4.1, blocked: 3, allowed: 12 },
    { ip: "192.168.0.5", bytes: 3.2, blocked: 0, allowed: 25 },
    { ip: "192.168.0.9", bytes: 2.7, blocked: 5, allowed: 9  }
  ];
  res.render("hosts", { active: "hosts", hosts });
});

// Apps
app.get("/apps", (_req, res) => {
  const apps = [
    { name: "AMAZON", pct: 41.5 },
    { name: "SSL",    pct: 19.0 },
    { name: "GOOGLE", pct:  9.0 },
    { name: "FACEBOOK", pct: 8.2 },
    { name: "Other",  pct: 22.3 }
  ];
  res.render("apps", { active: "apps", apps });
});

// Reports (기본 리스트 페이지)
app.get("/reports", (_req, res) => {
  const reports = [
    { id: "RPT-2025-09-01", title: "Weekly Traffic Summary", period: "Aug 25—31" },
    { id: "RPT-2025-09-08", title: "Top Talkers & Apps", period: "Sep 1—7" }
  ];
  res.render("reports", { active: "reports", reports });
});

// ✅ Router 적용 (View/Export API)
app.use("/reports", reportsRouter);

// Settings
app.get("/settings", (_req, res) => {
  const settings = { timezone: "Asia/Seoul", theme: "auto", apiKeySet: false };
  res.render("settings", { active: "settings", settings });
});

// Alerts (전체 보기)
app.get("/alerts", (_req, res) => {
  const alerts = readJSON(path.join(__dirname, "data", "alerts.json")).filter(a => a.timestamp);
  res.render("alerts", { active: "alerts", alerts });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`✅ http://localhost:${PORT}`));
