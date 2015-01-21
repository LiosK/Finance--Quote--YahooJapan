use utf8;
use strict;
use warnings;
use Test::More;
use Finance::Quote;


if (!$ENV{ONLINE_TEST}) {
    plan(skip_all => 'Set $ENV{ONLINE_TEST} to run this test');
}


my $q = Finance::Quote->new('-defaults', 'YahooJapan');
my @xs = qw/2914 3382 4063 4502 4503 5401 6301 6501 6752 6758 6902 6954 7201 7203 7267 7751 8031 8058 8306 8316 8411 8604 8766 8801 8802 9020 9432 9433 9437 9984/;

for my $x (@xs) {
    subtest "single ticker query: $x", sub { test_quote($x, $q->fetch('yahoo_japan', $x)); };
}

my %quotes = $q->fetch('yahoo_japan', @xs);
for my $x (@xs) {
    subtest "multi ticker query: $x", sub { test_quote($x, %quotes); };
}


done_testing;


sub test_quote {
    my ($sym, %info) = @_;
    plan(tests => 8);
    ok($info{$sym, 'success'},                            "success: $info{$sym, 'success'}");
    is($info{$sym, 'symbol'},    $sym,                    "symbol:  $info{$sym, 'symbol'}");
    is($info{$sym, 'method'},    'yahoo_japan',           "method:  $info{$sym, 'method'}");
    unlike($info{$sym, 'name'},  qr/^\s*$/,               "name:    $info{$sym, 'name'}");
    like($info{$sym, 'date'},    qr|^\d{2}/\d{2}/\d{4}$|, "date:    $info{$sym, 'date'}");
    like($info{$sym, 'isodate'}, qr/^\d{4}-\d{2}-\d{2}$/, "isodate: $info{$sym, 'isodate'}");
    like($info{$sym, 'time'},    qr/^\d{2}:\d{2}:\d{2}$/, "time:    $info{$sym, 'time'}");
    like($info{$sym, 'price'},   qr/^\d+(?:\.\d+)?$/,     "price:   $info{$sym, 'price'}");
}
