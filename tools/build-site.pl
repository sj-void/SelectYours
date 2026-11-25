#!/usr/bin/perl
# Builds the SelectYours website (two pages: Explore and Learn) into site/.
# Usage (Git Bash, from the project root):  perl tools/build-site.pl
# Inputs: docs/ (profiles, _data JSON, CSVs, methodology) and site-src/ (page shells, CSS, JS).
# Re-run after any change to either. Never hand-edit site/.
use strict;
use warnings;
use utf8;
use open qw(:std :encoding(UTF-8));
use JSON::PP;
use File::Path qw(make_path remove_tree);
use File::Copy qw(copy);
use File::Basename qw(basename);

my $ROOT = shift // '.';
my $DOCS = "$ROOT/docs";
my $UNI  = "$DOCS/universities";
my $SRC  = "$ROOT/site-src";
my $OUT  = "$ROOT/site";
my $EMAIL = 'shivamjoshi.bios@gmail.com';
# GoatCounter site code (the "xxx" in xxx.goatcounter.com). Empty = no analytics, no privacy note.
my $GOATCOUNTER = $ENV{SY_GOATCOUNTER} // 'selectyours';   # env var overrides, for testing
my @t = localtime; my $BUILT = sprintf('%04d-%02d-%02d', $t[5]+1900, $t[4]+1, $t[3]);

# ================================================================ helpers
sub slurp { my $f = shift; open my $h, '<:encoding(UTF-8)', $f or die "$f: $!"; local $/; my $s = <$h>; $s =~ s/^\x{FEFF}//; $s =~ s/\r\n/\n/g; $s }
sub spew  { my ($f, $s) = @_; open my $h, '>:encoding(UTF-8)', $f or die "$f: $!"; print $h $s; close $h }
sub esc   { my $s = shift // ''; $s =~ s/&/&amp;/g; $s =~ s/</&lt;/g; $s =~ s/>/&gt;/g; $s =~ s/"/&quot;/g; $s }
sub slugify { my $s = lc shift; $s =~ s/<[^>]+>//g; $s =~ s/&[a-z]+;//g; $s =~ s/[*`\[\]()]//g; $s =~ s/[^a-z0-9]+/-/g; $s =~ s/^-|-$//g; $s }
sub read_json { my $f = shift; open my $h, '<:raw', $f or die "$f: $!"; local $/; my $r = <$h>; $r =~ s/^\xEF\xBB\xBF//; decode_json($r) }
sub read_csv {
    my $t = slurp(shift);
    my (@rows, @row); my ($f, $q, $pq) = ('', 0, 0);
    for my $c (split //, $t) {
        if ($q) { if ($c eq '"') { $q = 0; $pq = 1 } else { $f .= $c } next }
        if ($c eq '"') { $f .= '"' if $pq; $q = 1; $pq = 0; next }
        $pq = 0;
        if    ($c eq ',')  { push @row, $f; $f = '' }
        elsif ($c eq "\n") { push @row, $f; push @rows, [@row]; @row = (); $f = '' }
        else { $f .= $c }
    }
    if (length $f || @row) { push @row, $f; push @rows, [@row] }
    my $h = shift @rows;
    return map { my %r; @r{@$h} = @$_; \%r } grep { @$_ > 1 } @rows;
}
sub first_url { my ($u) = (shift // '') =~ m{(https?://[^\s;<>"]+)}; return undef unless $u; $u =~ s/[.,;:)\]]+$//; $u }

# ================================================================ markdown
sub inline {
    my ($s) = @_;
    my @ph; my $hold = sub { push @ph, shift; "\x{1}" . $#ph . "\x{2}" };
    $s = esc($s);
    $s =~ s{&lt;br\s*/?&gt;}{$hold->('<br>')}ge;
    $s =~ s{`([^`]+)`}{$hold->("<code>$1</code>")}ge;
    $s =~ s{\[([^\[\]]+)\]\(([^)\s]+)\)}{
        my ($txt, $u) = ($1, $2); $u =~ s/&amp;/&/g;
        if ($u =~ m{^https?://}) { $hold->('<a href="' . esc($u) . '" target="_blank" rel="noopener">' . inline_simple($txt) . '</a>') }
        else { $hold->('<span class="xref">' . inline_simple($txt) . '</span>') }   # internal doc links: plain text
    }ge;
    $s =~ s{(https?://[^\s<>"\x{1}\x{2}]+)}{
        my $u = $1; my $tail = '';
        while ($u =~ s/([.,;:)\]]|&gt;)$//) { $tail = $1 . $tail }
        my $raw = $u; $raw =~ s/&amp;/&/g;
        $hold->('<a class="url" href="' . esc($raw) . '" target="_blank" rel="noopener">' . $u . '</a>') . $tail
    }ge;
    $s =~ s{\[(\d{1,3}|[A-Z]\d{1,3}|[A-Z]-[A-Za-z]+)\]}{$hold->('<a class="cite" href="#" data-c="' . $1 . '">' . $1 . '</a>')}ge;
    $s =~ s{(?<![\w/.])(?:\.\./)?(?:universities/)?([a-z0-9_-]+\.(?:md|csv))\b}{$hold->('<span class="xref">' . $1 . '</span>')}ge;
    $s = inline_simple($s);
    1 while $s =~ s{\x{1}(\d+)\x{2}}{$ph[$1]}g;
    $s;
}
sub inline_simple { my $s = shift; $s =~ s{\*\*(.+?)\*\*}{<strong>$1</strong>}g; $s =~ s{(?<![\w*])\*(?!\s)([^*]+?)\*(?![\w*])}{<em>$1</em>}g; $s }
sub is_li { $_[0] =~ /^(\s*)([-*]|\d+\.)\s+/ }
sub md2html {
    my ($md, $ctx) = @_;
    $md =~ s/<!--.*?-->//gs;
    my @L = split /\n/, $md; my @o; my $i = 0;
    while ($i < @L) {
        my $l = $L[$i];
        if ($l =~ /^\s*$/) { $i++; next }
        if ($l =~ /^(#{1,6})\s+(.+?)\s*$/) {
            my ($n, $txt) = (length $1, $2);
            $ctx->{sources} = ($txt =~ /sources/i) ? 1 : 0;
            my $lv = $n + ($ctx->{shift} // 0); $lv = 6 if $lv > 6;
            push @o, "<h$lv id=\"" . ($ctx->{idp} // '') . slugify($txt) . "\">" . inline($txt) . "</h$lv>"; $i++; next;
        }
        if ($l =~ /^\s*---+\s*$/) { push @o, '<hr>'; $i++; next }
        if ($l =~ /^\s*\|/) { my @t; push @t, $L[$i++] while $i < @L && $L[$i] =~ /^\s*\|/; push @o, table_html(\@t); next }
        if ($l =~ /^\s*>/) {
            my @q; while ($i < @L && $L[$i] =~ /^\s*>/) { (my $x = $L[$i++]) =~ s/^\s*> ?//; push @q, $x }
            push @o, '<div class="callout">' . md2html(join("\n", @q), {%$ctx}) . '</div>'; next;
        }
        if (is_li($l)) {
            my @b;
            while ($i < @L) {
                my $x = $L[$i];
                if ($x =~ /^\s*$/) { my $j = $i; $j++ while $j < @L && $L[$j] =~ /^\s*$/; last unless $j < @L && (is_li($L[$j]) || $L[$j] =~ /^\s+\S/); $i = $j; next }
                last if !is_li($x) && $x =~ /^(#|\||>|---)/;
                push @b, $x; $i++;
            }
            push @o, list_html(\@b, $ctx); next;
        }
        my @p; push @p, $L[$i++] while $i < @L && $L[$i] !~ /^\s*$/ && $L[$i] !~ /^(#{1,6}\s|\s*\||\s*>|\s*---+\s*$)/ && !is_li($L[$i]);
        push @o, '<p>' . inline(join(' ', @p)) . '</p>';
    }
    join "\n", @o;
}
sub split_row { my $r = shift; $r =~ s/^\s*\|//; $r =~ s/\|\s*$//; my @c = split /\|/, $r, -1; s/^\s+|\s+$//g for @c; @c }
sub table_html {
    my @r = map { [split_row($_)] } @{$_[0]};
    my $head = shift @r; shift @r if @r && join('', @{$r[0]}) =~ /^[\s:\-]+$/;
    my $kv = !grep { length } @$head;
    my $h = '<div class="tw"><table' . ($kv ? ' class="kv"' : '') . '>';
    $h .= '<thead><tr>' . join('', map { '<th>' . inline($_) . '</th>' } @$head) . '</tr></thead>' unless $kv;
    $h .= '<tbody>';
    for my $row (@r) { my @c = @$row; my $f = shift @c // ''; $h .= '<tr><th>' . inline($f) . '</th>' . join('', map { '<td>' . inline($_) . '</td>' } @c) . '</tr>' }
    $h . '</tbody></table></div>';
}
sub list_html {
    my ($lines, $ctx) = @_;
    my ($base) = $lines->[0] =~ /^(\s*)/; $base = length $base;
    my @items;
    for my $l (@$lines) {
        if ($l =~ /^(\s*)([-*]|(\d+)\.)\s+(.*)$/ && length($1) <= $base + 1) { push @items, { num => $3, text => $4, sub => [] } }
        elsif (@items) { push @{$items[-1]{sub}}, $l }
    }
    my $ol = defined $items[0]{num};
    my $h = $ol ? '<ol>' : '<ul>';
    for my $it (@items) {
        my $attr = '';
        if ($ol) { $attr = " value=\"$it->{num}\""; $attr .= " data-src=\"$it->{num}\" class=\"src-item\"" if $ctx->{sources} }
        elsif ($it->{text} =~ /^\[([A-Z]\d{1,3}|[A-Z]-[A-Za-z]+)\]\s/) { $attr = " data-src=\"$1\" class=\"src-item\"" }
        my $body = inline($it->{text});
        if (my @sub = @{$it->{sub}}) {
            my ($m) = sort { $a <=> $b } map { /^(\s*)\S/ ? length $1 : 999 } @sub;
            my @d = map { length($_) >= $m ? substr($_, $m) : $_ } @sub;
            $body .= (grep { is_li($_) || /^\s*\|/ } @d) ? md2html(join("\n", @d), {%$ctx}) : ' ' . inline(join(' ', map { s/^\s+//r } @sub));
        }
        $h .= "<li$attr>$body</li>";
    }
    $h . ($ol ? '</ol>' : '</ul>');
}

# ================================================================ load data
my @metrics  = read_csv("$DOCS/university-metrics.csv");
my %fullneed = map { lc($_->{school}) => $_ } read_csv("$DOCS/us-full-need-schools-international.csv");
my $SC       = read_json("$UNI/_data/_scorecard_site.json");
my $ENDOW    = read_json("$UNI/_data/_endowments.json");

my %LOCALE = (11 => 'City · large', 12 => 'City · midsize', 13 => 'City · small', 21 => 'Suburb · large', 22 => 'Suburb · midsize', 23 => 'Suburb · small',
              31 => 'Town · fringe', 32 => 'Town · distant', 33 => 'Town · remote', 41 => 'Rural · fringe', 42 => 'Rural · distant', 43 => 'Rural · remote');
my $NCES_LOCALE = 'https://nces.ed.gov/programs/edge/Geographic/LocaleBoundaries';

# ---------------------------------------------------------------- field catalogue
# key, label, group, kind (num|cat|bool|multi|list|text), fmt, better (high|low|''), learn anchor, filter?, default column?
my @F = (
  # Basics
  ['type',        'Type',                        'Basics',     'cat',  'text', '',     'type',              1, 1],
  ['state',       'State',                       'Basics',     'cat',  'text', '',     '',                  1, 0],
  ['city',        'City',                        'Basics',     'text', 'text', '',     '',                  0, 0],
  ['setting',     'Setting',                     'Basics',     'cat',  'text', '',     'setting',           1, 0],
  ['undergrads',  'Undergraduates',              'Basics',     'num',  'int',  '',     'size',              1, 1],
  ['total',       'Total students',              'Basics',     'num',  'int',  '',     'size',              1, 0],
  ['women',       'Women among undergraduates',  'Basics',     'num',  'pct',  '',     '',                  1, 0],
  # Money
  ['policy',      'Aid admission policy',        'Money',      'cat',  'text', '',     'need-blind',        1, 1],
  ['noLoans',     'States no loans in aid',      'Money',      'bool', 'bool', '',     'loans',             1, 0],
  ['coa',         'Cost of attendance 2026–27',  'Money',      'num',  'usd',  'low',  'coa',               1, 1],
  ['tuition',     'Tuition 2026–27',             'Money',      'num',  'usd',  'low',  'coa',               1, 0],
  ['aided',       'Internationals on aid',       'Money',      'num',  'int',  'high', 'h6',                1, 1],
  ['seats',       'Aided international seats / class', 'Money','num',  'int',  'high', 'h6',                1, 0],
  ['award',       'Average international award', 'Money',      'num',  'usd',  'high', 'h6',                1, 1],
  ['totalAid',    'Total international aid',     'Money',      'num',  'usd',  'high', 'h6',                1, 0],
  ['awardShare',  'Avg award ÷ cost',            'Money',      'num',  'pct',  'high', 'h6',                1, 0],
  ['endowPer',    'Endowment per student',       'Money',      'num',  'usd',  'high', 'endowment',         1, 0],
  # Admissions
  ['admit',       'Admit rate',                  'Admissions', 'num',  'pct',  'high', 'admit-rate',        1, 1],
  ['intlAdmit',   'International admit rate',    'Admissions', 'num',  'pct',  'high', 'intl-admit-rate',   1, 1],
  ['edAdmit',     'Early Decision admit rate',   'Admissions', 'num',  'pct',  'high', 'early-rounds',      1, 0],
  ['admit2030',   'Admit rate, Class of 2030',   'Admissions', 'num',  'pct',  'high', 'admit-rate',        1, 0],
  ['yield',       'Yield',                       'Admissions', 'num',  'pct',  '',     'yield',             1, 0],
  ['applicants',  'Applicants',                  'Admissions', 'num',  'int',  '',     'admit-rate',        1, 0],
  ['intlApplicants','International applicants',  'Admissions', 'num',  'int',  '',     'intl-admit-rate',   1, 0],
  ['rounds',      'Application rounds',          'Admissions', 'multi','list', '',     'early-rounds',      1, 0],
  ['appFee',      'Application fee',             'Admissions', 'num',  'usd',  'low',  'fees',              1, 0],
  # Testing
  ['testPolicy',  'Testing, Fall 2027',          'Testing',    'cat',  'text', '',     'test-policy',       1, 1],
  ['satMid',      'SAT midpoint',                'Testing',    'num',  'int',  '',     'sat',               1, 0],
  ['sat25',       'SAT 25th percentile',         'Testing',    'num',  'int',  '',     'sat',               1, 1],
  ['sat75',       'SAT 75th percentile',         'Testing',    'num',  'int',  '',     'sat',               1, 0],
  ['act25',       'ACT 25th percentile',         'Testing',    'num',  'int',  '',     'sat',               1, 0],
  ['act75',       'ACT 75th percentile',         'Testing',    'num',  'int',  '',     'sat',               1, 0],
  ['pctSat',      'Enrolled who sent the SAT',   'Testing',    'num',  'pct',  '',     'sat',               1, 0],
  ['duolingo',    'Accepts Duolingo English Test','Testing',   'bool', 'bool', '',     'english',           1, 0],
  ['toefl',       'TOEFL score cited',           'Testing',    'num',  'int',  'low',  'english',           1, 0],
  # International
  ['intl',        'International undergrads',    'International','num','int',  'high', 'intl-students',     1, 1],
  ['intlShare',   'International share',         'International','num','pct',  'high', 'intl-students',     1, 0],
  ['intlGrad',    'Completion rate, internationals','International','num','pct','high', 'grad-rates',        1, 0],
  # Outcomes
  ['retention',   'First-year retention',        'Outcomes',   'num',  'pct',  'high', 'retention',         1, 0],
  ['grad4',       '4-year graduation rate',      'Outcomes',   'num',  'pct',  'high', 'grad-rates',        1, 0],
  ['grad6',       '6-year graduation rate',      'Outcomes',   'num',  'pct',  'high', 'grad-rates',        1, 1],
  ['earnings',    'Median earnings, 10 years',   'Outcomes',   'num',  'usd',  'high', 'earnings',          1, 0],
  ['sfr',         'Student–faculty ratio',       'Outcomes',   'num',  'ratio','low',  'sfr',               1, 0],
  ['fields',      'Most common fields',          'Outcomes',   'list', 'list', '',     'fields',            1, 0],
  # Rankings
  ['prestige',    'Prestige Index',              'Rankings',   'num',  'idx',  'high', 'prestige-index',    1, 1],
  ['prestigeTier','Prestige tier',               'Rankings',   'cat',  'text', '',     'prestige-index',    1, 0],
  ['difficulty',  'Difficulty Index',            'Rankings',   'num',  'idx',  'low',  'difficulty-index',  1, 1],
  ['difficultyTier','Difficulty tier',           'Rankings',   'cat',  'text', '',     'difficulty-index',  1, 0],
  ['usnews',      'U.S. News 2027 rank',         'Rankings',   'num',  'rank', 'low',  'rankings',          1, 0],
  ['forbes',      'Forbes 2027 rank',            'Rankings',   'num',  'rank', 'low',  'rankings',          1, 0],
  ['qs',          'QS World 2027 rank',          'Rankings',   'num',  'rank', 'low',  'rankings',          1, 0],
  ['the',         'THE World 2027 rank',         'Rankings',   'num',  'rank', 'low',  'rankings',          1, 0],
  ['markers',     'Distinctions',                'Rankings',   'multi','list', '',     'markers',           1, 0],
  # Climate
  ['tempAvg',     'Average temperature',         'Climate',    'num',  'temp', '',     'climate',           1, 0],
  ['winterLow',   'Winter average low',          'Climate',    'num',  'temp', 'high', 'climate',           1, 0],
  ['summerHigh',  'Summer average high',         'Climate',    'num',  'temp', '',     'climate',           1, 0],
  ['snow',        'Snowfall per year',           'Climate',    'num',  'in',   'low',  'climate',           1, 0],
);
my @FIELDS = map { { key => $_->[0], label => $_->[1], group => $_->[2], kind => $_->[3], fmt => $_->[4], better => $_->[5], learn => $_->[6], filter => $_->[7], col => $_->[8] } } @F;

# ---------------------------------------------------------------- per-school extraction
sub sources_of {   # cite id -> first URL, from a profile's source lists
    my $md = shift; my %s;
    my ($src) = $md =~ /\n## Sources\n(.*)$/s; $src //= '';
    while ($src =~ /^(\d+)\.\s+(.*)$/mg) { my ($n, $t) = ($1, $2); my $u = first_url($t); $s{$n} = $u if $u }
    while ($md =~ /^-\s+\[([A-Z][\w-]*)\]\s+(.*)$/mg) { my ($n, $t) = ($1, $2); my $u = first_url($t); $s{$n} = $u if $u }
    \%s;
}
sub cite_url { my ($txt, $src) = @_; while (($txt // '') =~ /\[(\d{1,3}|[A-Z][\w-]*)\]/g) { return $src->{$1} if $src->{$1} } undef }
sub qf_row { my ($md, $label) = @_; my ($v) = $md =~ /^\|\s*\Q$label\E\s*\|\s*(.*?)\s*\|\s*$/m; $v }
sub bullet { my ($md, $re) = @_; my ($v) = $md =~ /^\s*-\s+\*\*$re[^*]*\*\*\s*(.*)$/m; $v }
sub section { my ($md, $re) = @_; my ($v) = $md =~ /\n## $re[^\n]*\n(.*?)(?=\n## |\z)/s; $v // '' }
sub plain { my $s = shift // ''; $s =~ s/\[(\d+|[A-Z][\w-]*)\]//g; $s =~ s/\*\*//g; $s =~ s/\s+/ /g; $s =~ s/^\s+|\s+$//g; $s }

sub mv {   # JSON metric -> cell
    my ($j, $k) = @_; my $x = $j->{metrics}{$k};
    return undef unless ref $x eq 'HASH';
    my %c; my $v = $x->{value};
    if (defined $v && $v =~ /^\s*(\d+(?:\.\d+)?)\s*(?::|to)\s*1\s*$/) { $v = $1 + 0 }
    $c{v} = (defined $v && $v =~ /^-?\d+(?:\.\d+)?$/) ? $v + 0 : $v;
    $c{a} = $x->{as_of} if defined $x->{as_of};
    my $u = first_url($x->{source}); $c{s} = $u if $u;
    $c{n} = $x->{note} if defined $x->{note} && length $x->{note};
    \%c;
}
sub cellv { my ($v, $s, $a, $n) = @_; my %c = (v => $v); $c{s} = $s if $s; $c{a} = $a if defined $a; $c{n} = $n if defined $n; \%c }
sub has { my $c = shift; $c && defined $c->{v} && $c->{v} =~ /^-?\d+(?:\.\d+)?$/ }

my (@schools, %PROFILE);
for my $r (sort { $a->{school} cmp $b->{school} } @metrics) {
    my $slug = $r->{slug};
    my $j   = read_json("$UNI/_data/$slug.json");
    my $md  = slurp("$UNI/$slug.md");
    my $src = sources_of($md);
    my $fn  = $fullneed{lc $r->{school}} // {};
    my $sc  = $SC->{schools}{$slug} // {};
    my $scu = $sc->{id} ? "https://collegescorecard.ed.gov/school/?$sc->{id}" : undef;
    my $sca = "IPEDS via College Scorecard, latest data (retrieved $SC->{retrieved_on})";
    my %v;

    # basics
    my $methodUrl = 'learn.html#method';
    $v{type}  = cellv($r->{type}, cite_url(qf_row($md, 'Type'), $src), undef, plain(qf_row($md, 'Type')));
    $v{state} = cellv($r->{state}, cite_url(qf_row($md, 'Location'), $src), undef, plain(qf_row($md, 'Location')));
    $v{city}  = cellv($sc->{'school.city'}, $scu, $sca) if $sc->{'school.city'};
    $v{setting} = cellv($LOCALE{$sc->{'school.locale'}}, $scu, "IPEDS locale code $sc->{'school.locale'} (NCES definitions: $NCES_LOCALE)") if $sc->{'school.locale'};
    $v{undergrads} = mv($j, 'total_undergrad');
    $v{total}      = mv($j, 'total_enrollment');
    $v{women} = cellv(sprintf('%.1f', $sc->{'latest.student.demographics.women'} * 100) + 0, $scu, $sca) if defined $sc->{'latest.student.demographics.women'};

    # money
    my $cat = $fn->{category} // '';
    my $pol = $cat =~ /^A_/ ? 'Need-blind' : $cat =~ /^B_/ ? 'Need-aware' : 'Full-cost model';
    $v{policy} = cellv($pol, $fn->{official_source}, "Verified $fn->{checked_on}, confidence: $fn->{confidence}", join(' — ', grep { length } $r->{need_policy_intl}, $fn->{key_conditions}));
    my $aidrow = qf_row($md, 'Aid policy for internationals') // '';
    my $nl = ($aidrow . ' ' . ($fn->{key_conditions} // '')) =~ /\bno[- ]loans?\b|loan-free|without (?:requiring )?loans|no loans|loans? (?:are )?not (?:included|part|offered)|grants? (?:only|instead of loans)|replac\w+ loans/i;
    $v{noLoans} = cellv($nl ? JSON::PP::true : JSON::PP::false, $nl ? (cite_url($aidrow, $src) // $fn->{official_source}) : undef, undef,
                        $nl ? plain($aidrow) : 'No explicit no-loan statement found in the aid policy line; check the profile.');
    $v{coa}     = mv($j, 'coa_total_2026_27');
    $v{tuition} = mv($j, 'tuition_2026_27');
    $v{aided}   = mv($j, 'intl_aided_count');
    $v{award}   = mv($j, 'intl_avg_award');
    $v{totalAid}= mv($j, 'intl_total_aid');
    $v{seats}   = cellv(int($v{aided}{v} / 4 + 0.5), $v{aided}{s}, 'International undergraduates on aid ÷ 4 (our calculation)') if has($v{aided});
    $v{awardShare} = cellv(sprintf('%.0f', $v{award}{v} / $v{coa}{v} * 100) + 0, $v{award}{s}, 'Average H6 award ÷ cost of attendance (our calculation)') if has($v{award}) && has($v{coa});
    my $en = $ENDOW->{schools}{$slug};
    $v{endowPer} = cellv($r->{endowment_per_student_usd} + 0, ($en ? first_url($en->{source}) : undef) // $src->{R7},
                         "Endowment FY2025 ($r->{endowment_fy2025_usd}) ÷ total enrollment (our calculation)") if length $r->{endowment_per_student_usd};

    # admissions
    $v{admit}     = mv($j, 'admit_rate');
    $v{intlAdmit} = mv($j, 'intl_admit_rate');
    $v{admit2030} = mv($j, 'admit_rate_class_of_2030');
    $v{applicants}= mv($j, 'applicants');
    $v{intlApplicants} = mv($j, 'intl_applicants');
    my ($eda, $edx) = (mv($j, 'ed_applicants'), mv($j, 'ed_admits'));
    $v{edAdmit} = cellv(sprintf('%.1f', $edx->{v} / $eda->{v} * 100) + 0, $edx->{s} // $eda->{s}, 'ED admits ÷ ED applicants (CDS C21, our calculation)') if has($eda) && has($edx) && $eda->{v} > 0;
    my ($adm, $enr) = (mv($j, 'admits'), mv($j, 'enrolled_first_year'));
    $v{yield} = cellv(sprintf('%.1f', $enr->{v} / $adm->{v} * 100) + 0, $enr->{s} // $adm->{s}, 'Enrolled ÷ admitted first-years (CDS C1, our calculation)') if has($adm) && has($enr) && $adm->{v} > 0;
    my $dl = join ' ', grep { defined } qf_row($md, 'Deadlines'), bullet(section($md, '6\.'), 'Deadlines');
    if ($dl) {
        (my $t = $dl) =~ s/Restrictive Early Action|Single[- ]Choice Early Action/REA/gi;
        $t =~ s/Regular Action/RD/gi;
        my $R = qr/(?:ED ?II|ED ?2|ED|EA|REA|Early Decision(?: II| 2)?|Early Action)/i;
        $t =~ s/\bno\s+$R(?:\s*(?:,|or|and|nor)\s*(?:no\s+)?$R)*(?:\s+(?:is|are)?\s*listed)?//gi;
        $t =~ s/$R\s*:\s*(?:none|not offered)\b//gi;
        my @rd;
        push @rd, 'Early Decision'    if $t =~ /\bED\b|Early Decision|\bED ?I\b|Fall ED/i;
        push @rd, 'Early Decision II' if $t =~ /ED ?II\b|ED ?2\b|Early Decision (?:II|2)\b|Winter ED/i;
        push @rd, 'Early Action'      if $t =~ /\bEA\b|Early Action/;
        push @rd, 'Restrictive Early Action' if $t =~ /\bREA\b/;
        push @rd, 'Regular Decision'  if $t =~ /\bRD\b|Regular Decision/i;
        $v{rounds} = cellv(\@rd, cite_url($dl, $src), 'Fall 2027 entry', plain($dl)) if @rd;
    }
    my $s6 = section($md, '6\.');
    my $fee = bullet($s6, 'Fee');
    if ($fee) {
        my %amts = map { $_ => 1 } ($fee =~ /\$(\d{2,3})\b/g);
        my $amt; if (keys %amts == 1) { ($amt) = keys %amts; $amt += 0 } elsif (!%amts && $fee =~ /no (?:application )?fee|free to apply|\$0\b/i) { $amt = 0 }
        $v{appFee} = cellv($amt, cite_url($fee, $src) // cite_url($s6, $src), 'Fall 2027 application', plain($fee)) if defined $amt;
    }

    # testing
    my $tp = mv($j, 'test_policy_fall_2027');
    my $tpb = bullet(section($md, '3\.'), 'Test policy');
    my $tpt = (has_text($tp) ? $tp->{v} : '') || plain(qf_row($md, 'Testing, Fall 2027')) || plain($tpb);
    my $tps = ($tp && $tp->{s}) || cite_url(qf_row($md, 'Testing, Fall 2027'), $src) || cite_url($tpb, $src);
    if ($tpt) {
        my %pos; for my $k (['Test-free', qr/test[- ]free|test[- ]blind|not consider/i], ['Optional', qr/optional/i], ['Required', qr/required|requires/i]) { $pos{$k->[0]} = $-[0] if $tpt =~ $k->[1] }
        my ($cls) = sort { $pos{$a} <=> $pos{$b} } keys %pos;
        $v{testPolicy} = cellv($cls // 'See profile', $tps, 'Fall 2027 entry', $tpt);
    }
    for (['sat25', 'sat_25'], ['sat75', 'sat_75'], ['act25', 'act_25'], ['act75', 'act_75'], ['pctSat', 'pct_submitting_sat']) { $v{$_->[0]} = mv($j, $_->[1]) }
    $v{satMid} = cellv(($v{sat25}{v} + $v{sat75}{v}) / 2, $v{sat25}{s}, 'Midpoint of the 25th–75th percentiles (our calculation)') if has($v{sat25}) && has($v{sat75});
    my ($eng) = grep { /TOEFL|IELTS|Duolingo|English/ } ($s6 =~ /^\s*-\s+(.*)$/mg);
    if ($eng) {
        my $no = $eng =~ /Duolingo[^.;]{0,40}not (?:accepted|considered)|(?:not|no longer) accept[^.;]{0,40}Duolingo/i;
        $v{duolingo} = cellv(($eng =~ /Duolingo/i && !$no) ? JSON::PP::true : JSON::PP::false, cite_url($eng, $src) // cite_url($s6, $src), undef, plain($eng));
        if ($eng =~ /TOEFL[^.;\d]{0,40}?(\d{2,3})\b/) { my $n = $1; $v{toefl} = cellv($n + 0, cite_url($eng, $src) // cite_url($s6, $src), 'Minimum or recommended score as the school states it', plain($eng)) if $n >= 60 && $n <= 120 }
    }

    # international
    $v{intl} = mv($j, 'intl_undergrad_count');
    $v{intlShare} = cellv(sprintf('%.1f', $v{intl}{v} / $v{undergrads}{v} * 100) + 0, $v{intl}{s}, 'International ÷ all undergraduates (CDS B1/B2, our calculation)') if has($v{intl}) && has($v{undergrads}) && $v{undergrads}{v};
    $v{intlGrad} = cellv(sprintf('%.1f', $sc->{'latest.completion.completion_rate_4yr_150_nonresident.alien'} * 100) + 0, $scu, "$sca; completion within 6 years, nonresident students") if defined $sc->{'latest.completion.completion_rate_4yr_150_nonresident.alien'};

    # outcomes
    $v{retention} = mv($j, 'retention_rate');
    $v{grad4} = mv($j, 'grad_rate_4yr');
    $v{grad6} = mv($j, 'grad_rate_6yr');
    $v{sfr}   = mv($j, 'student_faculty_ratio');
    $v{earnings} = cellv($sc->{'latest.earnings.10_yrs_after_entry.median'}, $scu, $sca, 'Covers students who received US federal aid only, so it excludes international students') if $sc->{'latest.earnings.10_yrs_after_entry.median'};
    my $mf = bullet(section($md, '7\.'), 'Most common fields');
    if ($mf) {
        my @fl; (my $t = $mf) =~ s/\[\d+\]//g;
        for my $chunk (split /%/, $t) { $chunk =~ s/^[\s,.;]+//; $chunk =~ s/^and\s+//; if ($chunk =~ /^(.*\S)\s+(\d{1,2})$/) { push @fl, [ucfirst $1, $2 + 0] } }
        $v{fields} = cellv(\@fl, cite_url($mf, $src), "Share of bachelor's degrees (IPEDS via College Scorecard)") if @fl;
    }

    # rankings
    $v{prestige}   = cellv($r->{prestige_index} + 0, $methodUrl, "#$r->{prestige_rank} of 62 · US standing $r->{us_standing}, global $r->{global_recognition}, wealth $r->{wealth_per_student}");
    $v{prestigeTier} = cellv($r->{prestige_tier}, $methodUrl);
    $v{difficulty} = cellv($r->{difficulty_index} + 0, $methodUrl, "#$r->{difficulty_rank} hardest of 62") if length $r->{difficulty_index};
    $v{difficultyTier} = cellv($r->{difficulty_tier}, $methodUrl) if length $r->{difficulty_tier};
    my %rk = (usnews => ['usnews_2027_rank', 'R1', "U.S. News Best Colleges 2027, $r->{usnews_category}"], forbes => ['forbes_2027_rank', 'R2', "Forbes America's Top Colleges 2027"],
              qs => ['qs_2027', 'R4', 'QS World University Rankings 2027'], the => ['the_2027', 'R5', 'THE World University Rankings 2027']);
    for my $k (keys %rk) {
        my $raw = $r->{$rk{$k}[0]} // ''; next unless length $raw;
        my ($a, $b) = $raw =~ /^(\d+)(?:\s*[-–]\s*(\d+))?/ or next;
        $v{$k} = cellv(defined $b ? ($a + $b) / 2 : $a + 0, $src->{$rk{$k}[1]}, $rk{$k}[2], defined $b ? "Band $raw (midpoint used)" : undef);
        $v{$k}{t} = $raw if defined $b;
    }
    my (@mk, @mks);
    my $addm = sub { my ($l, $c) = @_; push @mk, $l; push @mks, "$l: " . ($src->{$c} // 'see methodology') };
    $addm->('Ivy League', 'R-IvyPlus') if $r->{ivy_league} eq 'True';
    $addm->('Ivy-Plus', 'R-IvyPlus') if $r->{ivy_plus} eq 'True';
    $addm->('R1 research + AAU', 'R-Carnegie') if $r->{carnegie_r1_and_aau} eq 'True';
    $addm->('UK HPI visa list', 'R-HPI') if $r->{uk_hpi_2026} eq 'True';
    $addm->("Top-25 PhD producer", "R-PhD") if length $r->{nsf_phd_top25_rank};
    $v{markers} = cellv(\@mk, $methodUrl, 'Shown on the profile, not scored', join(' · ', @mks)) if @mk;

    # climate
    my $cl = bullet(section($md, '10\.'), 'Climate') // '';
    if ($cl =~ /average temperature ([\d.]+)°F/) {
        my $u = cite_url($cl, $src); my $a = 'NOAA 1991–2020 normals, nearest station';
        $v{tempAvg} = cellv($1 + 0, $u, $a, plain($cl));
        $v{winterLow}  = cellv($1 + 0, $u, $a) if $cl =~ /winter \(Dec–Feb\) average low (-?[\d.]+)°F/;
        $v{summerHigh} = cellv($1 + 0, $u, $a) if $cl =~ /summer \(Jun–Aug\) average high ([\d.]+)°F/;
        $v{snow}       = cellv($1 + 0, $u, $a) if $cl =~ /([\d.]+) inches of snowfall/;
        $v{snow}     //= cellv(0, $u, $a, 'No snowfall normal given') if $cl =~ /inches of precipitation/;
    }

    delete $v{$_} for grep { !defined $v{$_} } keys %v;
    my ($lede) = $md =~ /^# .*\n\n(.+?)\n/;
    my ($verified) = $md =~ /\*\*Last verified:\*\*\s*([^.*]+)/;
    my $kp = section($md, 'Key points');
    push @schools, {
        slug => $slug, name => ($r->{school} =~ s/\s*\(.*\)//r), short => short_name($r->{school}), unitid => $sc->{id},
        lat => $sc->{'location.lat'}, lon => $sc->{'location.lon'}, url => $sc->{'school.school_url'},
        verified => $verified, lede => inline($lede // ''), v => \%v,
    };

    # profile, split into sections for the school panel
    (my $body = $md) =~ s/^# .*\n//; $body =~ s/^\*\*Last verified:\*\*.*\n//m;
    $body =~ s/\A\s*.+?\n\n//s;                          # lede, shown in header
    my ($note) = $body =~ /\A\s*((?:>.*\n)+)/; $body =~ s/\A\s*(?:>.*\n)+// if $note;
    my %sec;
    for my $part (split /(?=^## )/m, $body) {
        my ($h) = $part =~ /^## (.+)$/m or next;
        my $id = slugify($h); $id =~ s/^\d+-//;
        (my $content = $part) =~ s/^## .+\n//;
        my $ctx = { sources => ($h =~ /^Sources/ ? 1 : 0), shift => 1, idp => "$slug--" };
        $sec{$id} = { title => ($h =~ s/^\d+\.\s*//r), html => md2html($content, $ctx) };
    }
    $PROFILE{$slug} = { note => ($note ? md2html($note, {}) : ''), sections => \%sec };
}
sub has_text { my $c = shift; $c && defined $c->{v} && length $c->{v} }
sub short_name {
    my $n = shift; $n =~ s/\s*\(.*\)//;
    my %m = ('Massachusetts Institute of Technology' => 'MIT', 'California Institute of Technology' => 'Caltech', 'University of Pennsylvania' => 'Penn',
             'Washington University in St. Louis' => 'WashU', 'Johns Hopkins University' => 'Johns Hopkins', 'University of Chicago' => 'UChicago',
             'New York University' => 'NYU', 'Claremont McKenna College' => 'Claremont McKenna', 'Washington and Lee University' => 'Washington and Lee',
             'Franklin and Marshall College' => 'F&M', 'College of the Holy Cross' => 'Holy Cross');
    return $m{$n} if $m{$n};
    $n =~ s/^University of //; $n =~ s/ (University|College)$//; $n;
}

# ================================================================ output
remove_tree($OUT) if -d $OUT;
make_path("$OUT/assets", "$OUT/p", "$OUT/data/universities");
copy($_, "$OUT/assets/" . basename($_)) or die "copy $_: $!" for grep { -f } glob "$SRC/assets/*";
copy("$DOCS/$_", "$OUT/data/$_") for qw(university-metrics.csv us-full-need-schools-international.csv);
copy($_, "$OUT/data/universities/" . basename($_)) for glob "$UNI/_data/*.json";

my $J = JSON::PP->new->canonical->utf8(0);
my %counts = (n => scalar @schools,
    blind => scalar(grep { $_->{v}{policy}{v} eq 'Need-blind' } @schools),
    aware => scalar(grep { $_->{v}{policy}{v} eq 'Need-aware' } @schools));
spew("$OUT/assets/data.js", 'window.SY=' . $J->encode({ built => $BUILT, email => $EMAIL, counts => \%counts, fields => \@FIELDS, schools => \@schools }) . ";\n");
for my $slug (keys %PROFILE) { spew("$OUT/p/$slug.js", 'SY_PROFILE(' . $J->encode($slug) . ',' . $J->encode($PROFILE{$slug}) . ");\n") }

# Learn page: shell + full methodology rendered from markdown
my $meth = slurp("$DOCS/methodology-prestige-difficulty.md"); $meth =~ s/^# .*\n//;
my $methHtml = md2html($meth, { shift => 1, idp => 'm-' });
my %T = (EMAIL => $EMAIL, BUILT => $BUILT, N => $counts{n}, N_BLIND => $counts{blind}, N_AWARE => $counts{aware}, METHODOLOGY => $methHtml,
    ANALYTICS => $GOATCOUNTER ? qq{<script data-goatcounter="https://$GOATCOUNTER.goatcounter.com/count" async src="https://gc.zgo.at/count.js"></script>
<script src="assets/visit.js"></script>} : '',
    PRIVACY => $GOATCOUNTER ? '<p class="muted">We count visits anonymously with GoatCounter: no cookies, no IP addresses or personal data stored. Your browser keeps one "visited before" flag so you are counted only once.</p>' : '');
for my $p (qw(index.html learn.html)) {
    my $h = slurp("$SRC/$p");
    $h =~ s/\{\{(\w+)\}\}/exists $T{$1} ? $T{$1} : die "unknown token $1 in $p"/ge;
    spew("$OUT/$p", $h);
}
printf "Built %s: %d schools, %d fields, 2 pages (%s)\n", $OUT, scalar @schools, scalar @FIELDS, $BUILT;
