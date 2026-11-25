#!/usr/bin/perl
# List AcroForm field names and values (/T, /V, /AS) from a PDF, inflating Flate streams and object streams.
# Usage: perl pdf-fields.pl <file.pdf> [name-regex]
use strict; use warnings; use Compress::Zlib;
my ($file, $filter) = @ARGV; $filter //= '.';
open(my $fh, '<:raw', $file) or die "cannot open $file"; local $/; my $pdf = <$fh>; close $fh;
my $bs = chr(92);
my @objs;
while ($pdf =~ /(\d+)\s+0\s+obj(.*?)endobj/sg) {
  my ($num, $body) = ($1, $2);
  if ($body =~ /^(.*?)stream\r?\n(.*?)\r?\n?endstream/s) {
    my ($dict, $data) = ($1, $2);
    if ($dict =~ /FlateDecode/) {
      my $out = uncompress($data);
      if (!defined $out) { my ($i) = inflateInit(); ($out) = $i->inflate($data) if $i; }
      if (defined $out && $dict =~ m{/Type\s*/ObjStm}) {
        my ($first) = $dict =~ m{/First\s+(\d+)};
        my @hdr = grep { length } split /\s+/, substr($out, 0, $first);
        for (my $k = 0; $k < @hdr - 1; $k += 2) {
          my $start = $first + $hdr[$k+1];
          my $end = ($k + 3 < @hdr) ? $first + $hdr[$k+3] : length($out);
          push @objs, [$hdr[$k], substr($out, $start, $end - $start)];
        }
        next;
      }
    }
    push @objs, [$num, $dict];
  } else { push @objs, [$num, $body]; }
}
my $count = 0;
for my $o (@objs) {
  my $b = $o->[1];
  next unless $b =~ m{/T\s*\((.*?)\)}s;
  my $name = $1;
  my $v = '';
  if ($b =~ m{/V\s*(/[A-Za-z0-9_#.\-]+)}s) { $v = $1; }
  elsif ($b =~ m{/V\s*\(([^)]*)\)}s) { $v = "($1)"; }
  my ($as) = $b =~ m{/AS\s*(/[A-Za-z0-9_#.\-]+)}s;
  next unless $name =~ /$filter/i;
  $count++;
  printf "%s\tV=%s\tAS=%s\n", $name, $v, $as // '';
}
print STDERR "objects: ", scalar(@objs), " fields matched: $count\n";
