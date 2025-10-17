// public/reports.js
(function () {
  // 이벤트 위임: 동적으로 생겨도 동작
  document.addEventListener('click', async (e) => {
    // View
    const vbtn = e.target.closest('.btn-view');
    if (vbtn) {
      const id = vbtn.dataset.id || '1';
      const res = await fetch(`/reports/${id}`);
      const data = await res.json();
      openPreviewModal(data.name || 'Report', data.rows || []);
      return;
    }

    // Export
    const ebtn = e.target.closest('.btn-export');
    if (ebtn) {
      const id = ebtn.dataset.id;
      window.location.href = `/reports/${id}/export`; // 다운로드 시작
      return;
    }

    // 모달 닫기
    if (e.target.id === 'modalClose' || e.target.classList.contains('modal-backdrop')) {
      closeModal();
      return;
    }
  });

  async function openReportModal(id) {
    try {
      const res = await fetch(`/reports/${id}`);
      if (!res.ok) throw new Error('failed');
      const data = await res.json();

      // 제목
      document.getElementById('modalTitle').textContent = data.name;

      // 바디: rows를 표로 렌더
      const body = document.getElementById('modalBody');
      body.innerHTML = rowsToTableHTML(data.rows || []);

      // 모달 열기
      const modal = document.getElementById('reportModal');
      modal.setAttribute('aria-hidden', 'false');
      modal.classList.add('open');
    } catch (err) {
      console.error(err);
      alert('리포트를 불러오지 못했습니다.');
    }
  }

  function closeModal() {
    const modal = document.getElementById('reportModal');
    modal.setAttribute('aria-hidden', 'true');
    modal.classList.remove('open');
    document.body.classList.remove('modal-open');
  }

  function rowsToTableHTML(rows) {
    const headers = Object.keys(rows[0] || {});
    if (!headers.length) return '<p class="muted">No data</p>';
    const thead = `<thead><tr>${headers.map(h=>`<th>${esc(h)}</th>`).join('')}</tr></thead>`;
    const tbody = `<tbody>${rows.map(r=>`<tr>${headers.map(h=>`<td>${esc(String(r[h]))}</td>`).join('')}</tr>`).join('')}</tbody>`;
    return `<div class="table-wrap"><table>${thead}${tbody}</table></div>`;
  }
  const esc = (s) => s.replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
})();
