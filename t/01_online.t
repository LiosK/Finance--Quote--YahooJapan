use utf8;
use 5.018;
use warnings;
use Test::More;
use Finance::Quote;


if (!$ENV{ONLINE_TEST}) {
    plan(skip_all => 'Set $ENV{ONLINE_TEST} to run this test');
}


my $q = Finance::Quote->new('-defaults', 'YahooJapan');
my @xs = qw/2914 4063 4502 4519 4568 4661 6098 6367 6501 6594 6758 6861 6902 6981 7203 7267 7741 7974 8001 8031 8035 8058 8306 8316 8766 9432 9433 9434 9983 9984/;


plan(tests => @xs * 2);


my %quotes = $q->fetch('yahoo_japan', @xs);
for my $x (@xs) {
    subtest "multi ticker query: $x", sub { test_quote($x, %quotes); };
    subtest "single ticker query: $x", sub { test_quote($x, $q->fetch('yahoo_japan', $x)); };
}


done_testing;


sub test_quote {
    my ($sym, %info) = @_;
    plan(tests => 8);
    ok($info{$sym, 'success'},                                     "success: $info{$sym, 'success'}");
    is($info{$sym, 'symbol'},    $sym,                             "symbol:  $info{$sym, 'symbol'}");
    is($info{$sym, 'method'},    'yahoo_japan',                    "method:  $info{$sym, 'method'}");
    unlike($info{$sym, 'name'},  qr/^\s*$/,                        "name:    $info{$sym, 'name'}");
    like($info{$sym, 'date'},    qr|^[0-9]{2}/[0-9]{2}/[0-9]{4}$|, "date:    $info{$sym, 'date'}");
    like($info{$sym, 'isodate'}, qr/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/, "isodate: $info{$sym, 'isodate'}");
    like($info{$sym, 'time'},    qr/^[0-9]{2}:[0-9]{2}:[0-9]{2}$/, "time:    $info{$sym, 'time'}");
    like($info{$sym, 'price'},   qr/^[0-9]+(?:\.[0-9]+)?$/,        "price:   $info{$sym, 'price'}");
}
