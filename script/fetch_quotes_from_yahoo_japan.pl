#!/usr/bin/env perl

use utf8;
use 5.018;
use warnings;
use Finance::Quote;


=head1 NAME

fetch_quotes_from_yahoo_japan.pl - Fetch quotes from Yahoo! Finance JAPAN.

=head1 SYNOPSIS

    fetch_quotes_from_yahoo_japan.pl [--defaults] [ticker_symbol ...]

=head1 DESCRIPTION

fetch_quotes_from_yahoo_japan.pl is a trivial script to try Finance::Quote::YahooJapan.

=head1 EXAMPLE

    fetch_quotes_from_yahoo_japan.pl 2914 7267 8316

=head1 AUTHOR

LiosK E<lt>contact@mail.liosk.netE<gt>

=cut


# receive target securities from command line arguments
my @symbols = ();
my $appends_defaults = !@ARGV;
my $appends_random   = 0;
for my $arg (@ARGV) {
    if ($arg eq '--defaults') {
        $appends_defaults = 1;
    } elsif ($arg eq '--random') {
        $appends_random   = 1;
        print STDERR "WARNING: --random is deprecated and will be removed in the future\n";
    } else {
        push @symbols, $arg;
    }
}

# append default and/or random ones if necessary
push @symbols, list_default_securities() if ($appends_defaults);
push @symbols, list_random_securities(10) if ($appends_random);

# fetch and print quotes
my $q = Finance::Quote->new('-defaults', 'YahooJapan')->fetch('yahoo_japan', @symbols);

my @fields = qw/success currency method name isodate time price errormsg/;
for my $sym (@symbols) {
  print join("\t", $sym, map { $q->{$sym, $_} // 'N/A' } @fields), "\n";
}

sub list_default_securities {
    return qw/
        50_stocks
        2413 2914 3382 4063 4502 4503 4519 4543 4568 4661 4689 4901 5108 6098
        6178 6273 6367 6501 6503 6594 6702 6752 6758 6861 6902 6954 6981 7182
        7203 7267 7733 7741 7751 7974 8001 8031 8035 8058 8306 8316 8411 8591
        8766 9022 9432 9433 9434 9613 9983 9984
        50_funds
        01312022 01312056 0131316A 01314178 02311158 02311207 02311214 02312038
        02312137 02312158 02312196 02313043 03311187 0331397C 0331418A 03315177
        03319172 04311045 04312047 0431207B 0431307B 0431407B 2931113C 32311984
        3231203C 32315984 35312202 3531299B 39311149 39312065 39312149 42311052
        4231113C 47311029 47311049 47311207 4731312A 47316169 4931112B 64311051
        6431117C 71311998 79311169 7931417A 7931419A 89311199 96311073 9C311125
        9I312179 AW31119C
        50_ETFs_REITs_etc
        1305 1306 1308 1320 1321 1330 1343 1346 1348 1568 1570 1591 3226 3234
        3240 3249 3263 3269 3278 3279 3281 3283 3285 3292 3295 3309 8951 8952
        8953 8954 8955 8956 8957 8958 8959 8960 8961 8963 8964 8966 8967 8968
        8972 8973 8975 8976 8984 8985 8986 8987
        6_currency_pairs
        USDJPY=X EURJPY=X GBPJPY=X CNYJPY=X EURUSD=X GBPUSD=X
        7_indices
        ^DJI ^GSPC 998407 998405 000001.SS ^GDAXI ^TNX
    /;
}

sub list_random_securities {
    my $count = shift;
    my @symbol_pool = list_default_securities();
    my @indices = ();
    push @indices, int rand @symbol_pool for (1..$count);
    return @symbol_pool[@indices];
}
