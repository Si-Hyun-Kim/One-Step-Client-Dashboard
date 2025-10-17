// public/charts.js
(function (global) {
  let trendChart, appsChart;
  const mode = () => (document.documentElement.classList.contains('dark') ? 'dark' : 'light');

  // 공통: 차트 기본 반응형 설정
  if (global.Chart) {
    Chart.defaults.responsive = true;
    Chart.defaults.maintainAspectRatio = false;             // ← 높이는 CSS가 책임지도록
    Chart.defaults.devicePixelRatio = Math.min(window.devicePixelRatio || 1, 2);
  }

  function applyChartTheme() {
    if (!global.Chart) return;
    const text = ChartTheme.cssVar("--text");
    const border = ChartTheme.cssVar("--border");

    // 전역 라벨/그리드 텍스트
    Chart.defaults.color = text;
    Chart.defaults.borderColor = border;

    // trend
    if (trendChart) {
      const s = trendChart.options.scales;
      if (s?.x?.ticks) s.x.ticks.color = text;
      if (s?.x?.grid)  s.x.grid.color  = border;
      if (s?.y?.ticks) s.y.ticks.color = text;
      if (s?.y?.grid)  s.y.grid.color  = border;
      if (trendChart.options.plugins?.legend?.labels) {
        trendChart.options.plugins.legend.labels.color = text;
      }
      trendChart.update();
    }

    // donut
    if (appsChart) {
      appsChart.data.datasets.forEach((ds) => {
        ds.backgroundColor = ChartTheme.PALETTE[mode()];
        ds.borderColor = "transparent";
        ds.borderWidth = 0;
      });
      if (appsChart.options.plugins?.legend?.labels) {
        appsChart.options.plugins.legend.labels.color = text;
      }
      appsChart.update();
    }
  }

  function buildTrendChart(summary, overrides = {}) {
    const m = mode();
    const colors = {
      light: {
        blocked: { border: "#e74c3c", bg: "rgba(231,76,60,0.20)" },
        allowed: { border: "#3498db", bg: "rgba(52,152,219,0.20)" }
      },
      dark: {
        blocked: { border: "#c0392b", bg: "rgba(192,57,43,0.30)" },
        allowed: { border: "#2980b9", bg: "rgba(41,128,185,0.30)" }
      }
    };

    const el = document.getElementById("trendChart");
    if (!el) return;
    trendChart?.destroy();
    trendChart = new Chart(el, {
      type: "line",
      data: {
        labels: summary.timeseries.labels,
        datasets: [
          {
            label: "Blocked",
            data: summary.timeseries.blocked,
            borderColor: colors[m].blocked.border,
            backgroundColor: colors[m].blocked.bg,
            borderWidth: 2,
            tension: .3,
            pointRadius: 3,
            pointHoverRadius: 5,
            pointHitRadius: 12
          },
          {
            label: "Allowed",
            data: summary.timeseries.allowed,
            borderColor: colors[m].allowed.border,
            backgroundColor: colors[m].allowed.bg,
            borderWidth: 2,
            tension: .3,
            pointRadius: 3,
            pointHoverRadius: 5,
            pointHitRadius: 12
          }
        ]
      },
      options: Object.assign({
        plugins: {
          legend: { position: "bottom" },
          tooltip: { mode: "nearest", intersect: true }   // ← 꼭 점/선과 교차할 때만
        },
        interaction: { mode: "nearest", intersect: true }, // ← axis 제거(2D 교차)
        scales: { y: { beginAtZero: true } }
      }, overrides)
    });
  }



  function buildAppsChart(apps) {
    const el = document.getElementById("appsChart");
    if (!el) return;

    const textColor = ChartTheme.cssVar("--text");

    appsChart?.destroy();
    appsChart = new Chart(el, {
      type: "doughnut",
      data: {
        labels: apps.map(a => a.name),
        datasets: [{
          data: apps.map(a => a.bytes ?? a.pct),
          backgroundColor: ChartTheme.PALETTE[mode()],
          borderColor: "transparent",
          borderWidth: 0
        }]
      },
      options: {
        plugins: {
          legend: {
            position: "right",
            labels: {
              color: textColor,
              generateLabels: (chart) => {
                const meta = chart.getDatasetMeta(0);
                const ds   = chart.data.datasets[0];
                return chart.data.labels.map((label, i) => {
                  const style = meta.controller.getStyle(i);
                  return {
                    text: label,
                    fillStyle: style.backgroundColor ?? (Array.isArray(ds.backgroundColor) ? ds.backgroundColor[i] : ds.backgroundColor),
                    strokeStyle: "transparent",
                    lineWidth: 0,
                    hidden: !chart.getDataVisibility(i),
                    index: i,
                    datasetIndex: 0
                  };
                });
              }
            },
            onClick: (evt, item, legend) => {
              const chart = legend.chart;
              chart.toggleDataVisibility(item.index); // 클릭한 조각만 토글
              chart.update();
            }
          },
          tooltip: { mode: "nearest", intersect: true }
        }
      }
    });
  }

  // 카드 컨테이너 크기 변화를 감지해 부드럽게 리사이즈
  const ro = new ResizeObserver(() => {
    trendChart?.resize();
    appsChart?.resize();
    // 사이드바 겹침도 재판단
    ChartTheme.detectOverlapAndCompact?.();
  });
  
  window.addEventListener('DOMContentLoaded', () => {
    const containers = document.querySelectorAll('.card');
    containers.forEach(c => ro.observe(c));
  });

  global.ChartBuilder = { buildTrendChart, buildAppsChart, applyChartTheme };
})(window);

// refresh botton 동작
document.addEventListener('click', (e) => {
  const btn = e.target.closest('#refreshBtn');
  if (!btn) return;
  e.preventDefault();
  window.location.reload(); // 필요 시 fetch로 데이터만 갱신해도 OK
});