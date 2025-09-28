// public/common.js
(function (global) {
  const root = document.documentElement;
  const cssVar = (n) => getComputedStyle(root).getPropertyValue(n).trim();
  const mode = () => (root.classList.contains("dark") ? "dark" : "light");

  // 🎨 도넛(원형) 차트 팔레트 (다크는 톤다운)
  const PALETTE = {
    light: ["#4e79a7", "#59a14f", "#f28e2b", "#e15759", "#76b7b2", "#edc949", "#af7aa1"],
    dark:  ["#3b5d7d", "#3e7a38", "#d35400", "#b03a2e", "#4e7d78", "#b7950b", "#7d5a76"]
  };

  // ⏱️ 디바운스
  const debounce = (fn, d = 120) => {
    let t; return (...a) => { clearTimeout(t); t = setTimeout(() => fn(...a), d); };
  };

  // 🌓 저장된 테마 반영
  function initThemeFromStorage() {
    if (localStorage.getItem("theme") === "dark") root.classList.add("dark");
  }

  // 🖱️ 토글 버튼 바인딩 + 차트 테마 동기화 + 레이아웃 재판단
  function bindThemeToggle(btnId = "themeToggle") {
    const btn = document.getElementById(btnId);
    if (!btn) return;
    btn.addEventListener("click", () => {
      root.classList.toggle("dark");
      localStorage.setItem("theme", root.classList.contains("dark") ? "dark" : "light");
      applyChartTheme();
      detectOverlapAndCompact(); // 테마 바뀌어도 레이아웃 재확인
    });
  }

  // 📐 사이드바-콘텐츠 겹침 감지 → 강제 모바일 레이아웃
  // 🔧 수정: 창이 커지면 자동으로 force-mobile 해제
  function detectOverlapAndCompact() {
  const sidebar = document.querySelector(".sidebar");
  const firstCard = document.querySelector(".page .card");
  if (!sidebar || !firstCard) return;

  const W = window.innerWidth;

  if (W <= 640) {
    // 1) 작은 화면이면 무조건 모바일 모드
    document.documentElement.classList.add("force-mobile");
    return;
  }

  // 2) 넓은 화면이면, 먼저 데스크탑 레이아웃으로 돌려놓고(측정용) 겹침 계산
  document.documentElement.classList.remove("force-mobile");
  sidebar.classList.remove("open"); // 혹시 열려있던 메뉴 닫기

  // 데스크탑 레이아웃 기준으로 다시 측정
  const sb = sidebar.getBoundingClientRect();
  const card = firstCard.getBoundingClientRect();
  const overlap = sb.right > card.left;

  if (overlap) {
    // 진짜로 겹치면 다시 모바일 강제
    document.documentElement.classList.add("force-mobile");
  } else {
    document.documentElement.classList.remove("force-mobile");
  }
}

  // 🧭 레이아웃 관찰(로드/리사이즈/내비 클릭 등)
  function observeLayout() {
    window.addEventListener("load", detectOverlapAndCompact);
    window.addEventListener("resize", debounce(detectOverlapAndCompact, 120));
    document.addEventListener("click", (e) => {
      // 햄버거 또는 사이드바 링크 클릭 후에도 재판단
      if (e.target.closest(".hamburger") || e.target.closest(".sidebar nav a")) {
        setTimeout(detectOverlapAndCompact, 0);
      }
    });
  }

  // 📊 Chart.js 전역 기본값 + 기존 차트 색상 동기화
  function applyChartTheme() {
    if (!global.Chart) return;

    // 전역 기본(새로 생성될 차트)
    const text = cssVar("--text");
    const border = cssVar("--border");
    Chart.defaults.responsive = true;
    Chart.defaults.maintainAspectRatio = false;  // 높이는 CSS에서 관리(.card canvas height)
    Chart.defaults.devicePixelRatio = Math.min(window.devicePixelRatio || 1, 2);
    Chart.defaults.color = text;
    Chart.defaults.borderColor = border;
    Chart.defaults.plugins = Chart.defaults.plugins || {};
    Chart.defaults.plugins.tooltip = Chart.defaults.plugins.tooltip || {};
    Chart.defaults.plugins.tooltip.mode = 'nearest';
    Chart.defaults.plugins.tooltip.intersect = true;

    // 도넛 기본 팔레트(새 차트에 자동 적용)
    Chart.overrides.doughnut = Chart.overrides.doughnut || {};
    Chart.overrides.doughnut.datasets = Chart.overrides.doughnut.datasets || {};
    Chart.overrides.doughnut.datasets.backgroundColor = PALETTE[mode()];
    Chart.overrides.doughnut.datasets.borderColor = "transparent";
    Chart.overrides.doughnut.datasets.borderWidth = 0;

    // 이미 만들어진 차트도 갱신
    const instances = Object.values(Chart.instances || {});
    instances.forEach((inst) => {
      // 축/그리드/범례 텍스트
      const s = inst.options.scales || {};
      ["x", "x1", "y", "r"].forEach((axis) => {
        if (s[axis]?.ticks) s[axis].ticks.color = text;
        if (s[axis]?.grid)  s[axis].grid.color  = border;
      });
      if (inst.options.plugins?.legend?.labels) {
        inst.options.plugins.legend.labels.color = text;
      }

      // 도넛 팔레트 교체
      if (inst.config.type === "doughnut") {
        inst.data.datasets.forEach((ds) => {
          ds.backgroundColor = PALETTE[mode()];
          ds.borderColor = "transparent";
          ds.borderWidth = 0; 
        });
      }
      inst.update();
    });
  }

  // 🔁 카드 사이즈 변화 시 차트도 부드럽게 리사이즈
  function observeCardsForResize() {
    if (!global.ResizeObserver) return;
    const ro = new ResizeObserver(debounce(() => {
      if (global.Chart) {
        Object.values(Chart.instances || {}).forEach((inst) => inst.resize());
      }
      detectOverlapAndCompact();
    }, 60));
    document.querySelectorAll(".card").forEach((el) => ro.observe(el));
  }

  // 🔌 외부로 노출
  global.ChartTheme = {
    PALETTE,
    cssVar,
    initThemeFromStorage,
    bindThemeToggle,
    applyChartTheme,
    detectOverlapAndCompact,
    observeLayout,
    observeCardsForResize
  };

  // 구버전 호환(ChartBuilder.applyChartTheme 호출해도 동작)
  if (global.ChartBuilder && !global.ChartBuilder.applyChartTheme) {
    global.ChartBuilder.applyChartTheme = applyChartTheme;
  }
})(window);
