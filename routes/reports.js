// routes/reports.js (ESM)
import express from 'express';
const router = express.Router();

// 데모 데이터
const REPORTS = [
  {
    id: 1, name: 'Traffic Summary (Last 24h)', created_at: new Date(),
    rows: [
      { hour: '00', blocked: 120, allowed: 980 },
      { hour: '01', blocked: 95,  allowed: 1021 },
      { hour: '02', blocked: 88,  allowed: 1103 },
    ]
  },
  {
    id: 2, name: 'Top Applications (This Week)', created_at: new Date(),
    rows: [
      { app: 'YouTube', bytes: 123456789 },
      { app: 'Slack',   bytes: 45678901 },
      { app: 'Zoom',    bytes: 23456789 },
    ]
  }
];

router.get('/', (req, res) => {
  res.render('reports', { active: 'reports', reports: REPORTS });
});

router.get('/:id', (req, res) => {
  const r = REPORTS.find(x => x.id === Number(req.params.id));
  if (!r) return res.status(404).json({ error: 'not found' });
  res.json(r);
});

router.get('/:id/export', (req, res) => {
  const r = REPORTS.find(x => x.id === Number(req.params.id));
  if (!r) return res.status(404).send('not found');

  const rows = r.rows || [];
  if (rows.length === 0) {
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="report_${r.id}.csv"`);
    return res.send('');
  }

  const headers = Object.keys(rows[0]);
  const csvLines = [
    headers.join(','),
    ...rows.map(obj => headers.map(h => String(obj[h]).replace(/"/g, '""')).join(','))
  ];
  const csv = '\uFEFF' + csvLines.join('\n'); // BOM

  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', `attachment; filename="${r.name.replace(/\s+/g,'_')}.csv"`);
  res.send(csv);
});

export default router; // ← ESM export
