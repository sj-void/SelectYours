#!/usr/bin/perl
# Find CDS I3 class-section counts: 7 size bands (2-9 ... 100+) whose sum equals the total.
# Prints: file  b1 b2 b3 b4 b5 b6 b7 total  (first verified match after the I3 heading)
use strict; use warnings;
for my $f (@ARGV) {
  open(my $fh, '<', $f) or next; my @l = <$fh>; close $fh;
  my $start = -1;
  for my $i (0..$#l) { if ($l[$i] =~ /2-9\s+10-19/) { $start = $i; last } }
  if ($start < 0) { print "$f\tNO-I3\n"; next }
  my $block = join(' ', @l[$start .. ($start + 14 > $#l ? $#l : $start + 14)]);
  $block =~ s/2-9|10-19|20-29|30-39|40-49|50-99|100\+//g;
  my @n = map { s/,//gr } ($block =~ /\b\d[\d,]*\b/g);
  my $found = 0;
  # sliding window
  for my $s (0 .. $#n - 7) {
    my $sum = 0; $sum += $n[$_] for $s .. $s + 6;
    if ($sum == $n[$s + 7] && $sum > 20) { print "$f\t", join(' ', @n[$s .. $s + 7]), "\n"; $found = 1; last }
  }
  print "$f\tNO-MATCH\t@n[0..($#n<20?$#n:20)]\n" unless $found;
}
