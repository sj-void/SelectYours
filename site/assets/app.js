/* SelectYours Explore — one table, advanced filters, profile drawer, compare.
   Data: window.SY from assets/data.js (built by tools/build-site.pl). Profiles load on demand from p/<slug>.js. */
(function () {
  'use strict';
  var SY = window.SY;
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  var esc = function (s) { return String(s == null ? '' : s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); };

  /* ------------------------------------------------------------ theme */
  $('#theme-btn').addEventListener('click', function () {
    var t = document.documentElement.dataset.theme === 'light' ? 'dark' : 'light';
    document.documentElement.dataset.theme = t;
    try { localStorage.setItem('sy-theme', t); } catch (e) {}
  });
  if (!SY || !$('#grid')) return;

  /* ------------------------------------------------------------ data prep */
  var FIELDS = SY.fields, F = {};
  FIELDS.forEach(function (f) { F[f.key] = f; });
  var S = SY.schools, BY = {};
  S.forEach(function (s) { BY[s.slug] = s; });
  var GROUP_ICON = { Basics: '◎', Money: '$', Admissions: '✦', Testing: '✎', International: '◍', Outcomes: '↗', Rankings: '★', Climate: '☁' };
  var ORDER = {
    policy: ['Need-blind', 'Need-aware', 'Full-cost model'],
    testPolicy: ['Required', 'Optional', 'Test-free', 'See profile'],
    prestigeTier: ['Tier 1, world-renowned', 'Tier 2, elite', 'Tier 3, highly regarded', 'Tier 4, respected'],
    difficultyTier: ['Extreme', 'Very high', 'High', 'Competitive'],
    type: ['University', 'Liberal arts college'],
    setting: ['City · large', 'City · midsize', 'City · small', 'Suburb · large', 'Suburb · midsize', 'Suburb · small', 'Town · fringe', 'Town · distant', 'Town · remote', 'Rural · fringe', 'Rural · distant', 'Rural · remote'],
    rounds: ['Early Decision', 'Early Decision II', 'Early Action', 'Restrictive Early Action', 'Regular Decision']
  };
  var TAGC = {
    'Need-blind': 'good', 'Need-aware': 'warn', 'Full-cost model': 'vio',
    Required: 'hot', Optional: 'good', 'Test-free': 'blue',
    'Tier 1, world-renowned': 'vio', 'Tier 2, elite': 'blue', 'Tier 3, highly regarded': 'good', 'Tier 4, respected': '',
    Extreme: 'hot', 'Very high': 'warn', High: 'blue', Competitive: 'good'
  };
  var ABBR = { 'Early Decision': 'ED', 'Early Decision II': 'ED II', 'Early Action': 'EA', 'Restrictive Early Action': 'REA', 'Regular Decision': 'RD',
    'Ivy League': 'Ivy', 'Ivy-Plus': 'Ivy+', 'R1 research + AAU': 'R1 · AAU', 'UK HPI visa list': 'UK HPI', 'Top-25 PhD producer': 'PhD top 25' };

  function cell(s, k) { return s.v[k]; }
  function raw(s, k) { var c = s.v[k]; return c ? c.v : null; }
  function num(s, k) {
    var v = raw(s, k);
    if (v == null || v === '' || typeof v !== 'number') return null;
    var f = F[k].fmt;
    if (f === 'temp') return Math.round((v - 32) * 5 / 9 * 10) / 10;
    if (f === 'in') return Math.round(v * 2.54);
    return v;
  }
  function arr(s, k) { var v = raw(s, k); return Array.isArray(v) ? v : []; }
  function compact(n) {
    if (n >= 1e9) return '$' + (n / 1e9).toFixed(1) + 'B';
    if (n >= 1e6) return '$' + (n / 1e6).toFixed(n >= 1e7 ? 0 : 1) + 'M';
    if (n >= 1e4) return '$' + (n / 1e3).toFixed(1).replace(/\.0$/, '') + 'k';
    return '$' + Math.round(n).toLocaleString('en-US');
  }
  function fmtNum(k, n, long) {
    if (n == null) return '—';
    var f = F[k].fmt;
    if (f === 'pct') return (Math.round(n * 10) / 10) + '%';
    if (f === 'usd') return long ? '$' + Math.round(n).toLocaleString('en-US') : compact(n);
    if (f === 'idx') return n.toFixed(1);
    if (f === 'rank') return '#' + Math.round(n);
    if (f === 'ratio') return n + ':1';
    if (f === 'temp') return n.toFixed(1).replace(/\.0$/, '') + '°C';
    if (f === 'in') return n + ' cm';
    return Math.round(n).toLocaleString('en-US');
  }
  function display(s, k, long) {
    var f = F[k], c = cell(s, k);
    if (!c || c.v == null || c.v === '') return null;
    if (c.t) return c.t;
    if (f.kind === 'num') return fmtNum(k, num(s, k), long);
    if (f.kind === 'bool') return c.v ? 'Yes' : 'Not stated';
    if (f.kind === 'multi') return c.v.join(', ');
    if (f.kind === 'list') return c.v.map(function (x) { return x[0] + ' ' + x[1] + '%'; }).join(', ');
    return String(c.v);
  }
  function hue(slug) { var h = 0; for (var i = 0; i < slug.length; i++) h = (h * 31 + slug.charCodeAt(i)) % 360; return h; }
  function monoStyle(s) { var h = hue(s.slug); return 'background:hsl(' + h + ' 32% 36%)'; }
  function initials(s) {
    var n = s.short || s.name;
    var w = n.replace(/[^A-Za-z&\s-]/g, '').split(/[\s-]+/).filter(function (x) { return x && !/^(of|and|the|in|at|St)$/i.test(x); });
    if (n.length <= 4 && n === n.toUpperCase()) return n;
    return (w.length > 1 ? w[0][0] + w[1][0] : n[0]).toUpperCase();
  }
  function mono(s, cls) { return '<span class="mono ' + (cls || '') + '" style="' + monoStyle(s) + '">' + esc(initials(s)) + '</span>'; }
  function placeOf(s) { var c = raw(s, 'city'); return (c ? c + ', ' : '') + raw(s, 'state'); }
  function srcLink(c, cls) {
    if (!c || !c.s) return '';
    return '<a class="' + (cls || 'sl') + '" href="' + esc(c.s) + '" target="_blank" rel="noopener" title="Open the source">↗</a>';
  }

  // numeric domains
  var DOM = {};
  FIELDS.forEach(function (f) {
    if (f.kind !== 'num') return;
    var vals = S.map(function (s) { return num(s, f.key); }).filter(function (v) { return v != null; });
    if (!vals.length) return;
    var lo = Math.min.apply(null, vals), hi = Math.max.apply(null, vals);
    var step = f.fmt === 'pct' ? 0.1 : f.fmt === 'idx' ? 0.1 : f.fmt === 'temp' ? 0.1 : f.fmt === 'ratio' ? 0.5 : f.fmt === 'usd' ? Math.max(1, Math.pow(10, Math.floor(Math.log10(hi - lo || 1)) - 2)) : 1;
    lo = Math.floor(lo / step) * step; hi = Math.ceil(hi / step) * step;
    DOM[f.key] = { lo: +lo.toFixed(2), hi: +hi.toFixed(2), step: step, n: vals.length };
  });
  var LIST_OPTS = (function () { var m = {}; S.forEach(function (s) { arr(s, 'fields').forEach(function (x) { m[x[0]] = (m[x[0]] || 0) + 1; }); }); return Object.keys(m).sort(function (a, b) { return m[b] - m[a]; }); })();
  function catValues(k) {
    var seen = {};
    S.forEach(function (s) { var f = F[k]; if (f.kind === 'multi') arr(s, k).forEach(function (x) { seen[x] = 1; }); else { var v = raw(s, k); if (v != null && v !== '') seen[v] = 1; } });
    var vals = Object.keys(seen);
    var o = ORDER[k];
    vals.sort(function (a, b) { if (o) { var ia = o.indexOf(a), ib = o.indexOf(b); if (ia < 0) ia = 99; if (ib < 0) ib = 99; if (ia !== ib) return ia - ib; } return a < b ? -1 : 1; });
    return vals;
  }

  /* ------------------------------------------------------------ state */
  var VIEWS = [
    { id: 'essentials', label: 'Essentials', cols: ['policy', 'admit', 'intlAdmit', 'aided', 'award', 'coa', 'testPolicy', 'intl', 'grad6', 'prestige', 'difficulty'] },
    { id: 'money', label: 'Money', cols: ['policy', 'noLoans', 'coa', 'tuition', 'aided', 'seats', 'award', 'awardShare', 'totalAid', 'endowPer'] },
    { id: 'admissions', label: 'Admissions', cols: ['admit', 'intlAdmit', 'edAdmit', 'admit2030', 'yield', 'applicants', 'intlApplicants', 'rounds', 'appFee', 'testPolicy', 'sat25', 'sat75', 'act25', 'act75', 'duolingo', 'toefl'] },
    { id: 'students', label: 'Outcomes', cols: ['type', 'undergrads', 'intl', 'intlShare', 'women', 'sfr', 'retention', 'grad4', 'grad6', 'intlGrad', 'earnings', 'fields'] },
    { id: 'rankings', label: 'Rankings', cols: ['prestige', 'prestigeTier', 'difficulty', 'difficultyTier', 'usnews', 'forbes', 'qs', 'the', 'markers', 'endowPer'] },
    { id: 'place', label: 'Place', cols: ['setting', 'city', 'state', 'winterLow', 'summerHigh', 'tempAvg', 'snow', 'type'] },
    { id: 'custom', label: 'Custom', cols: null }
  ];
  var DEFAULT = { f: {}, sort: { k: 'prestige', d: -1 }, view: 'essentials', custom: FIELDS.filter(function (f) { return f.col; }).map(function (f) { return f.key; }), keepMissing: false };
  var st = JSON.parse(JSON.stringify(DEFAULT));
  try { var saved = JSON.parse(localStorage.getItem('sy-state') || 'null'); if (saved && saved.f) { st.f = saved.f; st.sort = saved.sort || st.sort; st.view = saved.view || st.view; st.custom = saved.custom || st.custom; st.keepMissing = !!saved.keepMissing; } } catch (e) {}
  // drop stale filters
  Object.keys(st.f).forEach(function (k) { if (!F[k]) delete st.f[k]; });
  var q = '';
  var picked = [];
  function save() { try { localStorage.setItem('sy-state', JSON.stringify({ f: st.f, sort: st.sort, view: st.view, custom: st.custom, keepMissing: st.keepMissing })); } catch (e) {} }

  function isActive(k) {
    var v = st.f[k], f = F[k];
    if (v == null) return false;
    if (f.kind === 'num') { var d = DOM[k]; return d && (v[0] > d.lo + 1e-9 || v[1] < d.hi - 1e-9); }
    if (f.kind === 'cat' || f.kind === 'multi') return v.length > 0;
    if (f.kind === 'bool') return v === 'yes' || v === 'no';
    if (f.kind === 'list') return !!v.field;
    return false;
  }
  function activeKeys() { return Object.keys(st.f).filter(isActive); }

  function passOne(s, k, missingFlag) {
    var v = st.f[k], f = F[k];
    if (f.kind === 'num') {
      var x = num(s, k);
      if (x == null) { if (missingFlag) missingFlag.m = true; return st.keepMissing; }
      return x >= v[0] - 1e-9 && x <= v[1] + 1e-9;
    }
    if (f.kind === 'cat') { var r = raw(s, k); if (r == null) { if (missingFlag) missingFlag.m = true; return st.keepMissing; } return v.indexOf(r) >= 0; }
    if (f.kind === 'multi') { var a = arr(s, k); return v.every(function (x) { return a.indexOf(x) >= 0; }); }
    if (f.kind === 'bool') { var b = raw(s, k); if (b == null) { if (missingFlag) missingFlag.m = true; return st.keepMissing; } return v === 'yes' ? b === true : b !== true; }
    if (f.kind === 'list') { var hit = arr(s, k).filter(function (x) { return x[0] === v.field; })[0]; return !!hit && hit[1] >= (v.min || 0); }
    return true;
  }
  function matchesQuery(s) {
    if (!q) return true;
    var hay = (s.name + ' ' + (s.short || '') + ' ' + placeOf(s) + ' ' + raw(s, 'type')).toLowerCase();
    return q.toLowerCase().split(/\s+/).every(function (w) { return hay.indexOf(w) >= 0; });
  }
  function filtered(except) {
    var keys = activeKeys().filter(function (k) { return k !== except; });
    var missing = 0;
    var out = S.filter(function (s) {
      if (!matchesQuery(s)) return false;
      var flag = { m: false };
      var ok = keys.every(function (k) { return passOne(s, k, flag); });
      if (!ok && flag.m && !except) {
        // would it pass if missing data were allowed?
        var keep = st.keepMissing; st.keepMissing = true;
        if (keys.every(function (k) { return passOne(s, k); })) missing++;
        st.keepMissing = keep;
      }
      return ok;
    });
    if (!except) out.missing = missing;
    return out;
  }

  /* ------------------------------------------------------------ filters UI */
  var groupsEl = $('#filter-groups');
  var groups = [];
  FIELDS.forEach(function (f) { if (f.filter && groups.indexOf(f.group) < 0) groups.push(f.group); });
  var openGroups = { Money: 1, Admissions: 1 };
  groupsEl.innerHTML = groups.map(function (g) {
    var fs = FIELDS.filter(function (f) { return f.filter && f.group === g && (f.kind !== 'num' || DOM[f.key]); });
    return '<details class="fgroup" data-g="' + g + '"' + (openGroups[g] ? ' open' : '') + '><summary><span class="gi">' + (GROUP_ICON[g] || '•') + '</span>' + g + ' <span class="badge" hidden></span><svg class="chev" viewBox="0 0 24 24"><path d="m6 9 6 6 6-6"/></svg></summary><div class="fbody">' +
      fs.map(filterHtml).join('') + '</div></details>';
  }).join('');
  function learnLink(f) { return f.learn ? '<a href="learn.html#' + f.learn + '" title="What is this?" target="_blank" rel="noopener">ⓘ</a>' : ''; }
  function filterHtml(f) {
    var k = f.key, top = '<div class="f-top"><span class="f-label">' + esc(f.label) + learnLink(f) + '</span><span class="f-val" data-val="' + k + '"></span></div>';
    if (f.kind === 'num') {
      var d = DOM[k];
      return '<div class="f" data-k="' + k + '" data-label="' + esc(f.label.toLowerCase()) + '">' + top +
        '<div class="hist" data-h="' + k + '"></div><div class="dual"><div class="track"></div><div class="fill"></div>' +
        '<input type="range" min="' + d.lo + '" max="' + d.hi + '" step="' + d.step + '" value="' + d.lo + '" data-r="lo" aria-label="' + esc(f.label) + ' minimum">' +
        '<input type="range" min="' + d.lo + '" max="' + d.hi + '" step="' + d.step + '" value="' + d.hi + '" data-r="hi" aria-label="' + esc(f.label) + ' maximum"></div>' +
        '<div class="range-ends"><span>' + fmtNum(k, d.lo) + '</span><span>' + d.n + ' of ' + S.length + ' have data</span><span>' + fmtNum(k, d.hi) + '</span></div></div>';
    }
    if (f.kind === 'cat' || f.kind === 'multi') {
      return '<div class="f" data-k="' + k + '" data-label="' + esc(f.label.toLowerCase()) + '">' + top + '<div class="optset">' +
        catValues(k).map(function (v) { return '<button type="button" class="opt" data-v="' + esc(v) + '">' + esc(ABBR[v] && k === 'markers' ? v : v) + ' <em></em></button>'; }).join('') +
        '</div>' + (f.kind === 'multi' ? '<p class="f-note">Shows schools that have all the selected options.</p>' : '') + '</div>';
    }
    if (f.kind === 'bool') {
      return '<div class="f" data-k="' + k + '" data-label="' + esc(f.label.toLowerCase()) + '">' + top +
        '<div class="seg"><button type="button" data-b="">Any</button><button type="button" data-b="yes">Yes</button><button type="button" data-b="no">No / not stated</button></div></div>';
    }
    if (f.kind === 'list') {
      return '<div class="f" data-k="' + k + '" data-label="' + esc(f.label.toLowerCase()) + ' major subject computer engineering">' + top +
        '<select class="fsel" data-list="field"><option value="">Any field of study</option>' + LIST_OPTS.map(function (o) { return '<option>' + esc(o) + '</option>'; }).join('') + '</select>' +
        '<div class="f-top" style="margin-top:10px"><span class="f-label">At least this share of degrees</span><span class="f-val" data-minshare></span></div>' +
        '<div class="dual"><div class="track"></div><div class="fill" style="left:0"></div><input type="range" min="0" max="30" step="1" value="0" data-list="min" aria-label="Minimum share"></div>' +
        '<p class="f-note">Based on each school\'s five most common fields (IPEDS).</p></div>';
    }
    return '';
  }

  groupsEl.addEventListener('input', function (e) {
    var t = e.target, box = t.closest('.f'); if (!box) return;
    var k = box.dataset.k, f = F[k];
    if (f.kind === 'num' && t.dataset.r) {
      var lo = +$('[data-r=lo]', box).value, hi = +$('[data-r=hi]', box).value;
      if (lo > hi) { if (t.dataset.r === 'lo') { hi = lo; $('[data-r=hi]', box).value = hi; } else { lo = hi; $('[data-r=lo]', box).value = lo; } }
      st.f[k] = [lo, hi];
      if (!isActive(k)) delete st.f[k];
      update();
    }
    if (f.kind === 'list') {
      var v = st.f[k] || { field: '', min: 0 };
      if (t.dataset.list === 'field') v.field = t.value;
      if (t.dataset.list === 'min') v.min = +t.value;
      st.f[k] = v;
      if (!v.field && !v.min) delete st.f[k];
      update();
    }
  });
  groupsEl.addEventListener('change', function (e) { if (e.target.dataset.list === 'field') e.target.dispatchEvent(new Event('input', { bubbles: true })); });
  groupsEl.addEventListener('click', function (e) {
    var b = e.target.closest('button'); if (!b) return;
    var box = b.closest('.f'); if (!box) return;
    var k = box.dataset.k, f = F[k];
    if (b.classList.contains('f-clear')) { delete st.f[k]; update(); return; }
    if (b.dataset.v != null) {
      var cur = (st.f[k] || []).slice(), i = cur.indexOf(b.dataset.v);
      if (i >= 0) cur.splice(i, 1); else cur.push(b.dataset.v);
      if (cur.length) st.f[k] = cur; else delete st.f[k];
      update();
    }
    if (b.dataset.b != null) { if (b.dataset.b) st.f[k] = b.dataset.b; else delete st.f[k]; update(); }
  });
  $('#filter-find').addEventListener('input', function () {
    var t = this.value.trim().toLowerCase();
    $$('.f', groupsEl).forEach(function (el) { el.classList.toggle('hidden-by-find', !!t && el.dataset.label.indexOf(t) < 0); });
    $$('.fgroup', groupsEl).forEach(function (g) { if (t) g.open = $$('.f:not(.hidden-by-find)', g).length > 0; });
  });

  function syncFilters(res) {
    groups.forEach(function (g) {
      var n = FIELDS.filter(function (f) { return f.group === g && isActive(f.key); }).length;
      var b = $('.fgroup[data-g="' + g + '"] summary .badge'); if (b) { b.hidden = !n; b.textContent = n; }
    });
    $$('.f', groupsEl).forEach(function (box) {
      var k = box.dataset.k, f = F[k], on = isActive(k), v = st.f[k];
      box.classList.toggle('active', on);
      var lab = $('[data-val="' + k + '"]', box);
      var others = filtered(k);
      if (f.kind === 'num') {
        var d = DOM[k], lo = on ? v[0] : d.lo, hi = on ? v[1] : d.hi;
        $('[data-r=lo]', box).value = lo; $('[data-r=hi]', box).value = hi;
        var span = d.hi - d.lo || 1;
        var fill = $('.fill', box); fill.style.left = ((lo - d.lo) / span * 100) + '%'; fill.style.right = ((d.hi - hi) / span * 100) + '%';
        lab.innerHTML = on ? fmtNum(k, lo) + ' – ' + fmtNum(k, hi) + ' <button type="button" class="f-clear" aria-label="Clear">✕</button>' : 'Any';
        // histogram: bar = all schools, bright part = schools passing the other filters and inside the range
        var bins = 22, all = new Array(bins).fill(0), pass = new Array(bins).fill(0);
        var bin = function (x) { return Math.min(bins - 1, Math.max(0, Math.floor((x - d.lo) / span * bins))); };
        S.forEach(function (s) { var x = num(s, k); if (x != null) all[bin(x)]++; });
        others.forEach(function (s) { var x = num(s, k); if (x != null && x >= lo - 1e-9 && x <= hi + 1e-9) pass[bin(x)]++; });
        var mx = Math.max.apply(null, all) || 1;
        $('.hist', box).innerHTML = all.map(function (c, i) {
          var h = c ? Math.max(8, c / mx * 100) : 0;
          return '<span style="height:' + h + '%;' + (pass[i] ? 'background:linear-gradient(0deg,var(--accent) ' + (pass[i] / c * 100) + '%,var(--line-2) ' + (pass[i] / c * 100) + '%)' : '') + '" title="' + c + ' schools"></span>';
        }).join('');
      } else if (f.kind === 'cat' || f.kind === 'multi') {
        $$('.opt', box).forEach(function (o) {
          var val = o.dataset.v, sel = on && v.indexOf(val) >= 0;
          var cnt = others.filter(function (s) { return f.kind === 'multi' ? arr(s, k).indexOf(val) >= 0 : raw(s, k) === val; }).length;
          o.classList.toggle('on', sel); o.classList.toggle('zero', !cnt && !sel);
          $('em', o).textContent = cnt;
        });
        lab.innerHTML = on ? v.length + ' selected <button type="button" class="f-clear" aria-label="Clear">✕</button>' : 'Any';
      } else if (f.kind === 'bool') {
        $$('.seg button', box).forEach(function (b) { b.classList.toggle('on', (b.dataset.b || '') === (on ? v : '')); });
        var yes = others.filter(function (s) { return raw(s, k) === true; }).length;
        lab.textContent = yes + ' say yes';
      } else if (f.kind === 'list') {
        var vv = v || { field: '', min: 0 };
        $('[data-list=field]', box).value = vv.field || '';
        $('[data-list=min]', box).value = vv.min || 0;
        $('.fill', box).style.right = (100 - (vv.min || 0) / 30 * 100) + '%';
        $('[data-minshare]', box).textContent = (vv.min || 0) + '%';
        lab.innerHTML = on ? 'On <button type="button" class="f-clear" aria-label="Clear">✕</button>' : 'Any';
      }
    });
    var n = activeKeys().length;
    ['#filter-count', '#filter-count-m'].forEach(function (id) { $(id).hidden = !n; $(id).textContent = n; });
  }

  /* ------------------------------------------------------------ presets */
  var PRESETS = [
    { id: 'blind', icon: '🛡️', label: 'Need-blind', f: { policy: ['Need-blind'] } },
    { id: 'noloans', icon: '🚫', label: 'No loans', f: { noLoans: 'yes' } },
    { id: 'testopt', icon: '✏️', label: 'Test-optional', f: { testPolicy: ['Optional', 'Test-free'] } },
    { id: 'aid100', icon: '🎓', label: '100+ internationals on aid', f: { aided: [100, null] } },
    { id: 'reach', icon: '🎯', label: 'Admit rate above 15%', f: { admit: [15, null] } },
    { id: 'global', icon: '🌍', label: 'Large international share', f: { intlShare: [12, null] } },
    { id: 'cs', icon: '💻', label: 'Strong in computer science', f: { fields: { field: 'Computer and information sciences', min: 10 } } },
    { id: 'eng', icon: '⚙️', label: 'Strong in engineering', f: { fields: { field: 'Engineering', min: 10 } } },
    { id: 'city', icon: '🏙️', label: 'Big-city campus', f: { setting: ['City · large', 'City · midsize'] } },
    { id: 'mild', icon: '☀️', label: 'Mild winters', f: { winterLow: [-1, null] } },
    { id: 'lac', icon: '🏛️', label: 'Liberal arts colleges', f: { type: ['Liberal arts college'] } },
    { id: 'tier1', icon: '★', label: 'World-renowned (Tier 1)', f: { prestigeTier: ['Tier 1, world-renowned'] } }
  ].filter(function (p) { return Object.keys(p.f).every(function (k) { return F[k] && (F[k].kind !== 'num' || DOM[k]); }) && (!p.f.fields || LIST_OPTS.indexOf(p.f.fields.field) >= 0); });
  function presetVal(k, v) { if (F[k].kind === 'num') { var d = DOM[k]; return [v[0] == null ? d.lo : Math.max(d.lo, v[0]), v[1] == null ? d.hi : Math.min(d.hi, v[1])]; } return v; }
  function presetOn(p) { return Object.keys(p.f).every(function (k) { return JSON.stringify(st.f[k]) === JSON.stringify(presetVal(k, p.f[k])); }); }
  $('#presets').innerHTML = PRESETS.map(function (p) { return '<button type="button" class="preset" data-p="' + p.id + '"><i>' + p.icon + '</i>' + esc(p.label) + '</button>'; }).join('');
  $('#presets').addEventListener('click', function (e) {
    var b = e.target.closest('.preset'); if (!b) return;
    var p = PRESETS.filter(function (x) { return x.id === b.dataset.p; })[0];
    var on = presetOn(p);
    Object.keys(p.f).forEach(function (k) { if (on) delete st.f[k]; else st.f[k] = presetVal(k, JSON.parse(JSON.stringify(p.f[k]))); });
    update();
    if (!on) document.getElementById('explore').scrollIntoView({ behavior: 'smooth', block: 'start' });
  });

  /* ------------------------------------------------------------ chips */
  function chipText(k) {
    var f = F[k], v = st.f[k];
    if (f.kind === 'num') { var d = DOM[k]; if (v[0] > d.lo && v[1] < d.hi) return fmtNum(k, v[0]) + '–' + fmtNum(k, v[1]); return v[0] > d.lo ? '≥ ' + fmtNum(k, v[0]) : '≤ ' + fmtNum(k, v[1]); }
    if (f.kind === 'cat' || f.kind === 'multi') return v.map(function (x) { return ABBR[x] && f.kind === 'multi' ? ABBR[x] : x; }).join(' or ').replace(/ or /g, f.kind === 'multi' ? ' + ' : ' or ');
    if (f.kind === 'bool') return v === 'yes' ? 'Yes' : 'No / not stated';
    if (f.kind === 'list') return v.field + (v.min ? ' ≥ ' + v.min + '%' : '');
  }
  function renderChips() {
    var keys = activeKeys();
    $('#active-chips').innerHTML = keys.map(function (k) { return '<span class="chip">' + esc(F[k].label) + ': <b>' + esc(chipText(k)) + '</b><button type="button" data-x="' + k + '" aria-label="Remove filter">✕</button></span>'; }).join('') +
      (keys.length > 1 ? '<button type="button" class="link-btn" data-x="*">Clear all</button>' : '');
    $$('.preset').forEach(function (b) { b.classList.toggle('on', presetOn(PRESETS.filter(function (p) { return p.id === b.dataset.p; })[0])); });
  }
  $('#active-chips').addEventListener('click', function (e) { var b = e.target.closest('[data-x]'); if (!b) return; if (b.dataset.x === '*') st.f = {}; else delete st.f[b.dataset.x]; update(); });
  function resetAll() { st.f = {}; q = ''; $('#q').value = ''; update(); }
  $('#reset-filters').addEventListener('click', resetAll);
  $('#empty-reset').addEventListener('click', resetAll);

  /* ------------------------------------------------------------ table */
  var viewsEl = $('#views');
  viewsEl.innerHTML = VIEWS.map(function (v) { return '<button type="button" role="tab" data-view="' + v.id + '">' + v.label + '</button>'; }).join('');
  viewsEl.addEventListener('click', function (e) { var b = e.target.closest('[data-view]'); if (!b) return; st.view = b.dataset.view; update(); });
  function columns() { var v = VIEWS.filter(function (x) { return x.id === st.view; })[0] || VIEWS[0]; return (v.cols || st.custom).filter(function (k) { return F[k]; }); }

  // column picker
  var colsMenu = $('#cols-menu');
  function renderColsMenu() {
    var cur = columns(), html = '';
    groups.concat(['Basics']).filter(function (g, i, a) { return a.indexOf(g) === i; }).forEach(function (g) {
      var fs = FIELDS.filter(function (f) { return f.group === g; }); if (!fs.length) return;
      html += '<h4>' + g + '</h4>' + fs.map(function (f) { return '<label><input type="checkbox" value="' + f.key + '"' + (cur.indexOf(f.key) >= 0 ? ' checked' : '') + '> ' + esc(f.label) + '</label>'; }).join('');
    });
    colsMenu.innerHTML = html;
  }
  $('#cols-btn').addEventListener('click', function (e) { e.stopPropagation(); var open = colsMenu.hidden; renderColsMenu(); colsMenu.hidden = !open; this.setAttribute('aria-expanded', open); });
  colsMenu.addEventListener('click', function (e) { e.stopPropagation(); });
  colsMenu.addEventListener('change', function () {
    st.custom = $$('input:checked', colsMenu).map(function (i) { return i.value; });
    st.custom.sort(function (a, b) { return FIELDS.indexOf(F[a]) - FIELDS.indexOf(F[b]); });
    st.view = 'custom'; update();
  });
  document.addEventListener('click', function () { colsMenu.hidden = true; });

  function sortVal(s, k) {
    if (k === 'name') return s.name;
    var f = F[k];
    if (f.kind === 'num') return num(s, k);
    if (f.kind === 'bool') { var b = raw(s, k); return b == null ? null : b ? 1 : 0; }
    if (f.kind === 'multi' || f.kind === 'list') { var a = raw(s, k); return a && a.length ? a.length : null; }
    var r = raw(s, k); if (r == null) return null;
    var o = ORDER[k]; return o && o.indexOf(r) >= 0 ? o.indexOf(r) : String(r);
  }
  function cellHtml(s, k) {
    var f = F[k], c = cell(s, k);
    if (!c || c.v == null || c.v === '' || (Array.isArray(c.v) && !c.v.length)) {
      return '<span class="na cv" data-k="' + k + '" data-s="' + s.slug + '">—</span>';
    }
    var inner;
    if (f.kind === 'num') {
      var n = num(s, k), t = c.t || fmtNum(k, n);
      if (f.fmt === 'idx') {
        inner = '<span class="idx"><b>' + t + '</b><span class="meter"><i style="width:' + Math.max(3, n) + '%"></i></span></span>';
      } else if (f.fmt === 'pct' && DOM[k]) {
        var d = DOM[k]; inner = '<span class="bar">' + t + '<i style="width:' + Math.max(4, (n - d.lo) / ((d.hi - d.lo) || 1) * 100) + '%"></i></span>';
      } else inner = esc(t);
    } else if (f.kind === 'cat') {
      inner = k === 'state' || k === 'type' ? esc(c.v) : '<span class="tag ' + (TAGC[c.v] || 'plain') + '">' + esc(c.v) + '</span>';
    } else if (f.kind === 'bool') {
      inner = c.v ? '<span class="yes">✓ Yes</span>' : '<span class="na">Not stated</span>';
    } else if (f.kind === 'multi') {
      inner = c.v.map(function (x) { return '<span class="mini">' + esc(ABBR[x] || x) + '</span>'; }).join('');
    } else if (f.kind === 'list') {
      inner = esc(c.v[0][0]) + ' <span class="muted">' + c.v[0][1] + '%</span>' + (c.v.length > 1 ? ' <span class="mini">+' + (c.v.length - 1) + '</span>' : '');
    } else inner = esc(c.v);
    return '<span class="cv" data-k="' + k + '" data-s="' + s.slug + '">' + inner + '</span>' + srcLink(c);
  }
  function renderTable(rows) {
    var cols = columns();
    var sk = st.sort.k, sd = st.sort.d;
    rows.sort(function (a, b) {
      var x = sortVal(a, sk), y = sortVal(b, sk);
      if (x == null && y == null) return a.name < b.name ? -1 : 1;
      if (x == null) return 1; if (y == null) return -1;
      return x < y ? -sd : x > y ? sd : (a.name < b.name ? -1 : 1);
    });
    var arrow = function (k) { return '<span class="sort">' + (sk === k ? (sd > 0 ? '↑' : '↓') : '') + '</span>'; };
    $('#grid thead').innerHTML = '<tr><th class="c-sel" title="Select to compare"></th><th class="c-no" title="Row number in the current view">#</th><th class="c-name" data-sort="name">School' + arrow('name') + '</th>' +
      cols.map(function (k) { return '<th data-sort="' + k + '" class="' + (F[k].kind === 'num' ? 'num' : '') + '" title="' + esc(F[k].label) + ' — click to sort">' + esc(F[k].label) + arrow(k) + '</th>'; }).join('') + '</tr>';
    $('#grid tbody').innerHTML = rows.map(function (s, i) {
      var sel = picked.indexOf(s.slug) >= 0;
      return '<tr data-slug="' + s.slug + '"' + (sel ? ' class="picked"' : '') + '><td class="c-sel"><input type="checkbox" class="cb" aria-label="Compare ' + esc(s.name) + '"' + (sel ? ' checked' : '') + '></td><td class="c-no">' + (i + 1) + '</td>' +
        '<td class="c-name"><div class="nm">' + mono(s) + '<div class="nm-t"><strong>' + esc(s.name) + '</strong><span>' + esc(placeOf(s)) + ' · ' + esc(raw(s, 'type') === 'University' ? 'University' : 'Liberal arts') + '</span></div></div></td>' +
        cols.map(function (k) { return '<td class="' + (F[k].kind === 'num' ? 'num' : '') + '" data-l="' + esc(F[k].label) + '">' + cellHtml(s, k) + '</td>'; }).join('') + '</tr>';
    }).join('');
    // phone-only sort control (CSS hides it on wider screens, where the column headers sort)
    var sortKeys = ['name'].concat(cols); if (sortKeys.indexOf(sk) < 0) sortKeys.push(sk);
    $('#sort-m-k').innerHTML = sortKeys.map(function (k) { return '<option value="' + k + '"' + (k === sk ? ' selected' : '') + '>' + esc(k === 'name' ? 'School name' : F[k].label) + '</option>'; }).join('');
    $('#sort-m-d').textContent = sd > 0 ? '↑' : '↓';
    $('#sort-m-d').setAttribute('aria-label', sd > 0 ? 'Ascending; switch to descending' : 'Descending; switch to ascending');
    $('#empty').hidden = rows.length > 0;
    $('#grid').hidden = rows.length === 0;
  }
  function setSort(k) {
    if (st.sort.k === k) st.sort.d = -st.sort.d; else { st.sort.k = k; st.sort.d = k === 'name' || (F[k] && (F[k].better === 'low' || F[k].kind !== 'num')) ? 1 : -1; }
    update();
  }
  $('#grid thead').addEventListener('click', function (e) {
    var th = e.target.closest('th[data-sort]'); if (!th) return;
    setSort(th.dataset.sort);
  });
  $('#sort-m-k').addEventListener('change', function () { setSort(this.value); });
  $('#sort-m-d').addEventListener('click', function () { st.sort.d = -st.sort.d; update(); });
  $('#grid tbody').addEventListener('click', function (e) {
    if (e.target.closest('a')) return;
    var tr = e.target.closest('tr[data-slug]'); if (!tr) return;
    if (e.target.closest('.c-sel')) { if (e.target.classList.contains('cb')) togglePick(tr.dataset.slug); else { var cb = $('.cb', tr); cb.checked = !cb.checked; togglePick(tr.dataset.slug); } return; }
    openDrawer(tr.dataset.slug);
  });

  /* ------------------------------------------------------------ update loop */
  var firstRender = true;
  function update() {
    save();
    var rows = filtered();
    $('#count').textContent = rows.length;
    $('#filters-done').textContent = 'Show ' + rows.length + (rows.length === 1 ? ' school' : ' schools');
    $('#count-label').textContent = rows.length === 1 ? 'school' : 'schools' + (rows.length === S.length ? '' : ' of ' + S.length);
    var mn = $('#missing-note');
    if (rows.missing && !st.keepMissing) { mn.hidden = false; mn.innerHTML = rows.missing + ' more ' + (rows.missing === 1 ? 'school has' : 'schools have') + ' no data for a filter. <button type="button" class="link-btn" id="show-missing">Show them</button>'; }
    else if (st.keepMissing && activeKeys().length) { mn.hidden = false; mn.innerHTML = 'Including schools with missing data. <button type="button" class="link-btn" id="show-missing">Hide them</button>'; }
    else mn.hidden = true;
    $$('[data-view]', viewsEl).forEach(function (b) { b.setAttribute('aria-selected', b.dataset.view === st.view); });
    syncFilters(rows);
    renderChips();
    renderTable(rows);
    firstRender = false;
  }
  $('#missing-note').addEventListener('click', function (e) { if (e.target.id === 'show-missing') { st.keepMissing = !st.keepMissing; update(); } });
  var qEl = $('#q');
  qEl.addEventListener('input', function () { q = this.value.trim(); update(); });
  qEl.addEventListener('keydown', function (e) { if (e.key === 'Enter') { document.getElementById('explore').scrollIntoView({ behavior: 'smooth' }); } });

  /* ------------------------------------------------------------ hover popover */
  var pop = $('#pop'), popTimer;
  function showPop(target, html) {
    pop.innerHTML = html; pop.hidden = false;
    var r = target.getBoundingClientRect(), w = pop.offsetWidth, h = pop.offsetHeight;
    var left = Math.min(window.scrollX + window.innerWidth - w - 12, Math.max(window.scrollX + 12, r.left + window.scrollX + r.width / 2 - w / 2));
    var top = r.bottom + window.scrollY + 8;
    if (r.bottom + h + 16 > window.innerHeight) top = r.top + window.scrollY - h - 8;
    pop.style.left = left + 'px'; pop.style.top = top + 'px';
  }
  function hidePop() { pop.hidden = true; }
  function valuePopHtml(s, k) {
    var c = cell(s, k), f = F[k];
    var h = '<span class="pl">' + esc(f.label) + ' · ' + esc(s.short || s.name) + '</span>';
    if (!c || c.v == null || c.v === '' || (Array.isArray(c.v) && !c.v.length)) {
      return h + '<span class="pv">Not available</span><p>' + esc(c && c.n ? c.n : 'Not published on the pages we checked, or not in our data file.') + '</p>';
    }
    var shown = display(s, k, true);
    if (f.fmt === 'temp') shown += ' (' + c.v + '°F)';
    if (f.fmt === 'in') shown += ' (' + c.v + ' in)';
    h += '<span class="pv">' + esc(shown) + '</span>';
    if (c.a) h += '<p>' + esc(c.a) + '</p>';
    if (c.n && c.n !== shown) h += '<p class="muted">' + esc(c.n.length > 280 ? c.n.slice(0, 277) + '…' : c.n) + '</p>';
    if (c.s) h += '<p>Source: ' + esc(c.s.replace(/^https?:\/\/(www\.)?/, '').split('/')[0]) + ' ↗</p>';
    return h;
  }
  // Touch taps fire emulated mouseover events; ignore those so a tap opens the profile without a stray popover.
  var lastPointer = 'mouse';
  document.addEventListener('pointerdown', function (e) { lastPointer = e.pointerType; }, true);
  document.addEventListener('pointerover', function (e) { lastPointer = e.pointerType; }, true);
  document.addEventListener('mouseover', function (e) {
    var t = e.target.closest('.cv[data-k]');
    if (!t || lastPointer === 'touch') return;
    clearTimeout(popTimer);
    popTimer = setTimeout(function () { showPop(t, valuePopHtml(BY[t.dataset.s], t.dataset.k)); }, 180);
  });
  document.addEventListener('mouseout', function (e) { if (e.target.closest('.cv[data-k]')) { clearTimeout(popTimer); if (!pop.dataset.sticky) hidePop(); } });

  /* ------------------------------------------------------------ compare */
  function togglePick(slug) {
    var i = picked.indexOf(slug);
    if (i >= 0) picked.splice(i, 1);
    else { if (picked.length >= 4) { flashTray(); var cb = $('tr[data-slug="' + slug + '"] .cb'); if (cb) cb.checked = false; return; } picked.push(slug); }
    renderTray();
    $$('#grid tbody tr').forEach(function (tr) { var on = picked.indexOf(tr.dataset.slug) >= 0; tr.classList.toggle('picked', on); $('.cb', tr).checked = on; });
    var db = $('#d-compare'); if (db) db.textContent = picked.indexOf(db.dataset.slug) >= 0 ? '✓ In compare' : '+ Compare';
  }
  function flashTray() { var t = $('#tray'); t.animate && t.animate([{ transform: 'translate(-50%,0)' }, { transform: 'translate(-50%,-6px)' }, { transform: 'translate(-50%,0)' }], { duration: 300 }); }
  function renderTray() {
    var t = $('#tray'); t.hidden = !picked.length;
    $('#tray-items').innerHTML = picked.map(function (slug) { var s = BY[slug]; return '<span class="tray-item">' + mono(s) + esc(s.short || s.name) + '<button type="button" data-rm="' + slug + '" aria-label="Remove">✕</button></span>'; }).join('') +
      (picked.length < 4 ? '<span class="muted" style="font-size:12.5px;align-self:center;padding:0 6px">' + (picked.length < 2 ? 'Pick at least 2' : 'Up to 4') + '</span>' : '');
    $('#tray-compare').disabled = picked.length < 2;
    $('#tray-compare').style.opacity = picked.length < 2 ? .5 : 1;
  }
  $('#tray-items').addEventListener('click', function (e) { var b = e.target.closest('[data-rm]'); if (b) togglePick(b.dataset.rm); });
  $('#tray-clear').addEventListener('click', function () { picked.slice().forEach(togglePick); });
  $('#tray-compare').addEventListener('click', openCompare);
  function openCompare() {
    if (picked.length < 2) return;
    var ss = picked.map(function (x) { return BY[x]; });
    var h = '<div class="modal-card"><div class="modal-head"><h2>Comparing ' + ss.length + ' schools</h2><span class="muted" style="font-size:12.5px">Best value in each row is highlighted</span><button type="button" class="icon-btn" data-close aria-label="Close"><svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6 6 18"/></svg></button></div><div class="modal-body"><table class="cmp"><thead><tr><th></th>' +
      ss.map(function (s) { return '<th><div class="nm">' + mono(s) + '<div class="nm-t"><strong>' + esc(s.name) + '</strong><span>' + esc(placeOf(s)) + '</span></div></div></th>'; }).join('') + '</tr></thead><tbody>';
    var lastG = '';
    FIELDS.forEach(function (f) {
      if (!ss.some(function (s) { return display(s, f.key) != null; })) return;
      if (f.group !== lastG) { h += '<tr class="grp"><th colspan="' + (ss.length + 1) + '">' + f.group + '</th></tr>'; lastG = f.group; }
      var best = null;
      if (f.kind === 'num' && f.better) {
        var vals = ss.map(function (s) { return num(s, f.key); }).filter(function (v) { return v != null; });
        if (vals.length > 1) best = f.better === 'high' ? Math.max.apply(null, vals) : Math.min.apply(null, vals);
      }
      h += '<tr><th>' + esc(f.label) + (f.learn ? ' <a href="learn.html#' + f.learn + '" target="_blank" rel="noopener" title="What is this?">ⓘ</a>' : '') + '</th>' + ss.map(function (s) {
        var c = cell(s, f.key), d = display(s, f.key, true);
        var isBest = best != null && num(s, f.key) === best;
        return '<td class="' + (isBest ? 'best' : '') + '">' + (d == null ? '<span class="na">—</span>' : '<span class="cv">' + (f.kind === 'cat' && TAGC[c.v] != null ? '<span class="tag ' + (TAGC[c.v] || 'plain') + '">' + esc(d) + '</span>' : esc(d)) + '</span>' + srcLink(c)) +
          (c && c.a ? '<span class="sub">' + esc(c.a) + '</span>' : '') + '</td>';
      }).join('') + '</tr>';
    });
    h += '</tbody></table></div></div>';
    var m = $('#compare-modal'); m.innerHTML = h; m.hidden = false;
  }
  $('#compare-modal').addEventListener('click', function (e) { if (e.target === this || e.target.closest('[data-close]')) this.hidden = true; });

  /* ------------------------------------------------------------ drawer */
  var drawer = $('#drawer'), scrim = $('#scrim'), profiles = {}, current = null, tab = 'overview';
  var TABS = [
    { id: 'overview', label: 'Overview', secs: ['key-points', 'quick-facts', 'snapshot'] },
    { id: 'admissions', label: 'Admissions', secs: ['admission-difficulty', 'how-to-apply'] },
    { id: 'money', label: 'Aid & cost', secs: ['financial-aid', 'cost-of-attendance'] },
    { id: 'academics', label: 'Academics & outcomes', secs: ['academics', 'outcomes'] },
    { id: 'life', label: 'Life & campus', secs: ['international-student-life', 'campus-location', 'health', 'notable-alumni'] },
    { id: 'rankings', label: 'Rankings', secs: ['prestige'] },
    { id: 'data', label: 'All data' },
    { id: 'sources', label: 'Sources', secs: ['sources'] }
  ];
  window.SY_PROFILE = function (slug, data) {
    var box = document.createElement('div');
    box.innerHTML = (data.sections.sources || {}).html || '';
    data.src = {};
    $$('[data-src]', box).forEach(function (li) { data.src[li.dataset.src] = li.innerHTML; });
    profiles[slug] = data;
    if (current === slug) renderTab();
  };
  function loadProfile(slug) {
    if (profiles[slug] || $('script[data-p="' + slug + '"]')) return;
    var sc = document.createElement('script'); sc.src = 'p/' + slug + '.js'; sc.dataset.p = slug; document.body.appendChild(sc);
  }
  function tile(s, k, label, val) {
    var c = cell(s, k), d = val != null ? val : display(s, k, false);
    return '<div class="tile"><div class="tl">' + esc(label || F[k].label) + '</div><div class="tv">' + (d == null ? '<span class="na">—</span>' : esc(d)) + '</div>' +
      '<div class="ta">' + esc(c && (c.a || c.n) ? (c.a || c.n) : (d == null ? 'Not published' : '')) + '</div>' + srcLink(c, 'ts') + '</div>';
  }
  function openDrawer(slug, keepTab) {
    var s = BY[slug]; if (!s) return;
    current = slug; if (!keepTab) tab = 'overview';
    clearTimeout(popTimer); if (!pop.dataset.sticky) hidePop();
    loadProfile(slug);
    var h = hue(slug);
    var tags = ['policy', 'testPolicy', 'prestigeTier', 'difficultyTier', 'setting'].map(function (k) { var v = raw(s, k); return v ? '<span class="tag ' + (TAGC[v] != null ? TAGC[v] || 'plain' : 'plain') + '">' + esc(k === 'testPolicy' ? 'Tests: ' + v : k === 'prestigeTier' ? 'Prestige ' + v.replace(/,.*/, '') : k === 'difficultyTier' ? 'Difficulty: ' + v : v) + '</span>' : ''; }).join('');
    var sat = num(s, 'sat25') && num(s, 'sat75') ? num(s, 'sat25') + '–' + num(s, 'sat75') : null;
    var site = s.url ? (/^https?:/.test(s.url) ? s.url : 'https://' + s.url) : null;
    var subj = encodeURIComponent('SelectYours correction: ' + s.name);
    drawer.innerHTML =
      '<div class="d-cover" style="--cover:hsl(' + h + ' 32% 40%)">' +
        '<div class="d-top"><button type="button" class="btn-ghost" id="d-compare" data-slug="' + slug + '">' + (picked.indexOf(slug) >= 0 ? '✓ In compare' : '+ Compare') + '</button>' +
        (site ? '<a class="btn-ghost" href="' + esc(site) + '" target="_blank" rel="noopener">Official site ↗</a>' : '') +
        '<a class="btn-ghost" href="mailto:' + SY.email + '?subject=' + subj + '">Report a correction</a><span class="sp"></span>' +
        '<button type="button" class="icon-btn" id="d-close" aria-label="Close profile"><svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6 6 18"/></svg></button></div>' +
        '<div class="d-head">' + mono(s) + '<div><h2>' + esc(s.name) + '</h2><p class="d-sub">' + esc(placeOf(s)) + ' · ' + esc(raw(s, 'type')) + (s.verified ? ' · verified ' + esc(s.verified) : '') + '</p></div></div>' +
        (s.lede ? '<p class="d-lede prose">' + s.lede + '</p>' : '') +
        '<div class="d-tags">' + tags + '</div></div>' +
      '<div class="d-tiles">' + tile(s, 'admit') + tile(s, 'intlAdmit') + tile(s, 'aided') + tile(s, 'award') + tile(s, 'coa', 'Cost of attendance') + tile(s, 'intl', 'International undergrads') + tile(s, 'grad6') + tile(s, 'sat25', 'SAT middle 50%', sat) + '</div>' +
      '<div class="d-tabs" role="tablist">' + TABS.map(function (t) { return '<button type="button" role="tab" data-tab="' + t.id + '">' + t.label + '</button>'; }).join('') + '</div>' +
      '<div class="d-body prose" id="d-body"></div>';
    renderTab();
    drawer.classList.add('open'); drawer.setAttribute('aria-hidden', 'false'); scrim.hidden = false;
    document.body.style.overflow = 'hidden';
    if (location.hash !== '#school=' + slug) history.replaceState(null, '', '#school=' + slug);
    drawer.scrollTop = 0; drawer.focus({ preventScroll: true });
  }
  function renderTab() {
    var s = BY[current], body = $('#d-body'); if (!body) return;
    $$('.d-tabs button', drawer).forEach(function (b) { b.setAttribute('aria-selected', b.dataset.tab === tab); });
    var t = TABS.filter(function (x) { return x.id === tab; })[0];
    if (t.id === 'data') {
      var gs = []; FIELDS.forEach(function (f) { if (gs.indexOf(f.group) < 0) gs.push(f.group); });
      body.innerHTML = '<p class="muted" style="margin:18px 0">Every field in our data for ' + esc(s.name) + '. Hover a value for its data year, and use ↗ to open the source.</p><div class="alldata">' + gs.map(function (g) {
        return '<div class="ad-group"><h4>' + g + '</h4>' + FIELDS.filter(function (f) { return f.group === g; }).map(function (f) {
          var d = display(s, f.key, true), c = cell(s, f.key);
          return '<div class="ad-row"><span>' + esc(f.label) + '</span><span>' + (d == null ? '<span class="na cv" data-k="' + f.key + '" data-s="' + s.slug + '">—</span>' : '<span class="cv" data-k="' + f.key + '" data-s="' + s.slug + '">' + esc(d) + '</span>' + srcLink(c)) + '</span></div>';
        }).join('') + '</div>';
      }).join('') + '</div>';
      $$('.sl', body).forEach(function (a) { a.style.opacity = 1; });
      return;
    }
    var p = profiles[current];
    if (!p) { body.innerHTML = '<p class="loading">Loading the full profile…</p>'; return; }
    var html = '';
    if (t.id === 'overview' && p.note) html += '<div class="callout">' + p.note + '</div>';
    var ids = Object.keys(p.sections);
    t.secs.forEach(function (pre) {
      ids.filter(function (id) { return id.indexOf(pre) === 0; }).forEach(function (id) {
        html += '<h3>' + esc(p.sections[id].title) + '</h3>' + p.sections[id].html;
      });
    });
    body.innerHTML = html || '<p class="muted">Nothing in this section.</p>';
  }
  drawer.addEventListener('click', function (e) {
    var tb = e.target.closest('[data-tab]'); if (tb) { tab = tb.dataset.tab; renderTab(); var tabs = $('.d-tabs', drawer); if (drawer.scrollTop > tabs.offsetTop) drawer.scrollTop = tabs.offsetTop; return; }
    if (e.target.closest('#d-close')) { closeDrawer(); return; }
    var cb = e.target.closest('#d-compare'); if (cb) { togglePick(cb.dataset.slug); return; }
    var ci = e.target.closest('a.cite');
    if (ci) {
      e.preventDefault(); e.stopPropagation();
      var p = profiles[current], id = ci.dataset.c, src = p && p.src[id];
      if (!src) { showPop(ci, '<span class="pl">Source ' + esc(id) + '</span><p>Open the Sources tab to see the full list.</p>'); }
      else showPop(ci, '<span class="pl">Source ' + esc(id) + '</span>' + src);
      pop.dataset.sticky = '1';
    }
  });
  document.addEventListener('click', function (e) { if (pop.dataset.sticky && !e.target.closest('#pop') && !e.target.closest('a.cite')) { delete pop.dataset.sticky; hidePop(); } });
  function closeDrawer() {
    drawer.classList.remove('open'); drawer.setAttribute('aria-hidden', 'true'); scrim.hidden = true; current = null;
    document.body.style.overflow = ''; delete pop.dataset.sticky; hidePop();
    if (/^#school=/.test(location.hash)) history.replaceState(null, '', location.pathname + location.search);
  }
  scrim.addEventListener('click', function () { closeDrawer(); $('#filters').classList.remove('open'); });

  /* ------------------------------------------------------------ mobile filters, keys */
  $('#open-filters').addEventListener('click', function () { $('#filters').classList.add('open'); scrim.hidden = false; });
  $('#close-filters').addEventListener('click', function () { $('#filters').classList.remove('open'); if (!current) scrim.hidden = true; });
  $('#filters-done').addEventListener('click', function () { $('#filters').classList.remove('open'); if (!current) scrim.hidden = true; document.getElementById('explore').scrollIntoView(); });
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') {
      if (!$('#compare-modal').hidden) { $('#compare-modal').hidden = true; return; }
      if (current) { closeDrawer(); return; }
      colsMenu.hidden = true; $('#filters').classList.remove('open'); scrim.hidden = true;
    }
    if (e.key === '/' && !/INPUT|TEXTAREA|SELECT/.test(document.activeElement.tagName)) { e.preventDefault(); qEl.focus(); qEl.scrollIntoView({ block: 'center', behavior: 'smooth' }); }
  });

  /* ------------------------------------------------------------ export */
  $('#export-btn').addEventListener('click', function () {
    var rows = filtered(), cols = columns();
    var cell2 = function (x) { x = x == null ? '' : String(x); return /[",\n]/.test(x) ? '"' + x.replace(/"/g, '""') + '"' : x; };
    var lines = [['School', 'State'].concat(cols.reduce(function (a, k) { return a.concat([F[k].label, F[k].label + ' (source)']); }, [])).map(cell2).join(',')];
    rows.forEach(function (s) {
      lines.push([s.name, raw(s, 'state')].concat(cols.reduce(function (a, k) { var c = cell(s, k); return a.concat([display(s, k, true), c && c.s ? c.s : '']); }, [])).map(cell2).join(','));
    });
    var blob = new Blob(['﻿' + lines.join('\n')], { type: 'text/csv;charset=utf-8' });
    var a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = 'selectyours-' + st.view + '.csv'; document.body.appendChild(a); a.click(); a.remove();
  });

  /* ------------------------------------------------------------ hash routes (#school=, #view=, #filter=) */
  function route() {
    var h = decodeURIComponent(location.hash.slice(1)), m;
    if ((m = h.match(/^school=([\w-]+)/))) openDrawer(m[1]);
    else if ((m = h.match(/^view=(\w+)/))) { st.view = m[1]; update(); document.getElementById('explore').scrollIntoView(); }
    else if ((m = h.match(/^preset=(\w+)/))) { var b = $('.preset[data-p="' + m[1] + '"]'); if (b && !b.classList.contains('on')) b.click(); }
  }
  window.addEventListener('hashchange', route);

  /* ------------------------------------------------------------ go */
  var points = 0; S.forEach(function (s) { Object.keys(s.v).forEach(function (k) { var c = s.v[k]; if (c && c.v != null && c.v !== '' && c.s) points++; }); });
  var sp = $('#stat-points'); sp.dataset.count = points; sp.textContent = points.toLocaleString('en-US');
  $$('[data-count]').forEach(function (el) {
    var n = +el.dataset.count, t0 = null;
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    function step(ts) { if (!t0) t0 = ts; var p = Math.min(1, (ts - t0) / 900); el.textContent = Math.round(n * (1 - Math.pow(1 - p, 3))).toLocaleString('en-US'); if (p < 1) requestAnimationFrame(step); }
    requestAnimationFrame(step);
  });
  renderTray();
  update();
  route();
})();
