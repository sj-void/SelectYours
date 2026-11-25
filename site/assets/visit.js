/* All-time unique visitors, without cookies or IDs.
   GoatCounter (count.js) records page views. This file adds one
   "new-visitor" event the first time a browser opens the site, then
   stores a plain flag (sy_seen = "1", identical for everyone) in
   localStorage so the browser is never counted as new again.
   The all-time total of the "new-visitor" event in GoatCounter is the
   number of unique browsers. Included only when $GOATCOUNTER is set in
   tools/build-site.pl. */
window.addEventListener('load', function () {
  try {
    if (localStorage.getItem('sy_seen')) return;
    var gc = window.goatcounter;
    if (!gc || !gc.count) return;               // blocked or not loaded: try again next visit
    if (gc.filter && gc.filter()) return;       // GoatCounter would skip this (localhost, bot, prerender...)
    gc.count({ path: 'new-visitor', title: 'New visitor (first visit from this browser)', event: true });
    localStorage.setItem('sy_seen', '1');
  } catch (e) { /* storage unavailable: site works normally */ }
});
