/* SelectYours Learn page: term search, section highlighting, source pop-ups. */
(function () {
  'use strict';
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  var cards = $$('.lcontent .card');
  var input = $('#lq');

  // search
  input.addEventListener('input', function () {
    var t = input.value.trim().toLowerCase();
    var any = false;
    cards.forEach(function (c) {
      var hit = !t || c.textContent.toLowerCase().indexOf(t) >= 0;
      c.classList.toggle('hidden-by-search', !hit);
      if (hit) any = true;
    });
    $$('.lsec').forEach(function (s) { s.hidden = !!t && !$$('.card:not(.hidden-by-search)', s).length; });
    $('#no-results').hidden = any;
    $('.path').hidden = !!t;
  });
  document.addEventListener('keydown', function (e) {
    if (e.key === '/' && !/INPUT|TEXTAREA|SELECT/.test(document.activeElement.tagName)) { e.preventDefault(); input.focus(); }
    if (e.key === 'Escape') hide();
  });

  // section nav highlight
  var links = $$('.lnav a');
  if ('IntersectionObserver' in window) {
    var obs = new IntersectionObserver(function (en) {
      en.forEach(function (x) {
        if (x.isIntersecting) links.forEach(function (l) { l.classList.toggle('active', l.getAttribute('href') === '#' + x.target.id); });
      });
    }, { rootMargin: '-30% 0px -60% 0px' });
    $$('.lsec').forEach(function (s) { obs.observe(s); });
  }

  // flash the card a link points to; open the methodology for its anchors
  function focusHash() {
    var id = decodeURIComponent(location.hash.slice(1)); if (!id) return;
    var el = document.getElementById(id); if (!el) return;
    var d = el.closest('details'); if (d) d.open = true;
    if (el.classList.contains('card')) { el.classList.add('flash'); setTimeout(function () { el.classList.remove('flash'); }, 2200); }
  }
  window.addEventListener('hashchange', focusHash); focusHash();

  // source pop-ups for [G1] and methodology [n] tags
  var pop = $('#pop');
  function hide() { pop.hidden = true; }
  document.addEventListener('click', function (e) {
    var a = e.target.closest('a.cite');
    if (!a) { if (!e.target.closest('#pop')) hide(); return; }
    var li = null, label = '';
    if (a.dataset.c) { li = $('#method [data-src="' + a.dataset.c + '"]'); label = 'Methodology source ' + a.dataset.c; }
    else { li = document.getElementById(a.getAttribute('href').slice(1)); label = 'Source ' + a.textContent; }
    if (!li) return;
    e.preventDefault();
    pop.innerHTML = '<span class="pl">' + label + '</span>' + li.innerHTML;
    pop.hidden = false;
    var r = a.getBoundingClientRect(), w = pop.offsetWidth;
    pop.style.left = Math.min(window.scrollX + window.innerWidth - w - 12, Math.max(window.scrollX + 12, r.left + window.scrollX - 20)) + 'px';
    pop.style.top = (r.bottom + window.scrollY + 8) + 'px';
  });
})();
