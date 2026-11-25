#!/usr/bin/perl
# CDS I3 class sections: find a total T and 7 band counts that sum to it.
# Handles pdftotext scrambling where some bands print before the total and 2-9, 10-19 ... follow it.
# Output: file  total  under20  method
use strict; use warnings;
for my $f (@ARGV) {
  open(my $fh, '<', $f) or next; my @l = <$fh>; close $fh;
  my $start = -1;
  for my $i (0..$#l) { if ($l[$i] =~ /2-9\s+10-19/) { $start = $i; last } }
  if ($start < 0) { print "$f\tNO-I3\n"; next }
  my $block = join(' ', @l[$start .. ($start + 14 > $#l ? $#l : $start + 14)]);
  $block =~ s/2-9|10-19|20-29|30-39|40-49|50-99|100\+//g;
  my @n = map { s/,//gr } ($block =~ /\b\d[\d,]*\b/g);
  my $out = '';
  # 1) in-order window: b1..b7 total
  for my $s (0 .. $#n - 7) { my $sum = 0; $sum += $n[$_] for $s .. $s + 6; if ($sum == $n[$s + 7] && $sum >= 40) { $out = "$n[$s+7]\t" . ($n[$s] + $n[$s+1]) . "\tinorder"; last } }
  # 2) scrambled: k bands, TOTAL, then 2-9, 10-19, ... (7-k bands)
  unless ($out) {
    for my $t (0 .. ($#n < 12 ? $#n : 12)) {
      next unless $n[$t] >= 40;
      for my $b (0 .. 4) {
        my $a = 7 - $b; next if $t - $b < 0 || $t + $a > $#n;
        my $sum = 0; $sum += $n[$_] for ($t - $b) .. ($t - 1); $sum += $n[$_] for ($t + 1) .. ($t + $a);
        if ($sum == $n[$t]) { $out = "$n[$t]\t" . ($n[$t+1] + $n[$t+2]) . "\tscrambled(b=$b)"; last }
      }
      last if $out;
    }
  }
  print "$f\t", ($out || "NO-MATCH\t@n[0..($#n<16?$#n:16)]"), "\n";
}
