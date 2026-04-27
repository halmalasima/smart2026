/* Control Panel — small enhancements */
(function () {
  function getCookie(name) {
    const v = document.cookie.split('; ').find(r => r.startsWith(name + '='));
    return v ? decodeURIComponent(v.split('=')[1]) : null;
  }

  // Theme toggle
  const btn = document.getElementById('cp-theme-toggle');
  if (btn) {
    btn.addEventListener('click', async () => {
      const csrf = document.querySelector('meta[name="csrf-token"]').content;
      try {
        const r = await fetch('/cp/theme/toggle/', {
          method: 'POST',
          headers: { 'X-CSRFToken': csrf, 'Accept': 'application/json' },
          credentials: 'same-origin',
        });
        const data = await r.json();
        document.documentElement.setAttribute('data-bs-theme', data.theme);
      } catch (e) { /* ignore */ }
    });
  }
})();
