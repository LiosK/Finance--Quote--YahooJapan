#!/usr/bin/env perl

use utf8;
use strict;
use warnings;
use Finance::Quote;

# receive target securities from command line arguments
my @symbols = ();
my $appends_defaults = !@ARGV;
for my $arg (@ARGV) {
    if ($arg eq '--defaults') {
        $appends_defaults = 1;
    } else {
        push @symbols, $arg;
    }
}

# append default ones if necessary
push @symbols, list_target_securities() if ($appends_defaults);

# fetch and print quotes
my $q = Finance::Quote->new('-defaults', 'YahooJapan')->yahoo_japan(@symbols);

my @fields = qw/success currency method name isodate time price errormsg/;
for my $sym (@symbols) {
  print join("\t", $sym, map { $q->{$sym, $_} // 'N/A' } @fields), "\n";
}

sub list_target_securities {
    return qw/
        50_stocks
        2914 3382 4063 4452 4502 4503 4661 4901 5108 5401 6301 6326 6367 6501
        6502 6503 6594 6752 6758 6861 6902 6954 6981 7011 7201 7203 7261 7267
        7270 7751 8001 8031 8058 8306 8316 8411 8591 8604 8766 8801 8802 8830
        9020 9022 9432 9433 9437 9501 9983 9984
        50_funds
        01311142 0131211B 0131410A 01314114 01317114 0131E099 02311038 02311056
        02312038 02312052 02313043 03313046 04311035 04311036 0431109C 04312045
        04312047 04312066 0431212B 0431508B 06311049 06312044 0631A102 0931105A
        10311112 11311047 1131197C 22311034 29311066 3231203C 32315984 42311052
        42311081 44311096 45313131 4731103C 47311066 47311988 4931710B 4931810B
        5131109A 58311061 58312083 5831211A 64311051 79311118 8331106B 83311085
        9I31111B 9R31106C
        50_ETFs_REITs_etc
        1305 1306 1308 1320 1321 1330 1343 1346 1348 1568 1570 1591 3226 3234
        3240 3249 3263 3269 3278 3279 3281 3283 3285 3292 3295 3309 8951 8952
        8953 8954 8955 8956 8957 8958 8959 8960 8961 8963 8964 8966 8967 8968
        8972 8973 8975 8976 8984 8985 8986 8987
        6_currency_pairs
        USDJPY=X EURJPY=X GBPJPY=X CNYJPY=X EURUSD=X GBPUSD=X
    /;
}
