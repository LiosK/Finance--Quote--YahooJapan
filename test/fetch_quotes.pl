#!/usr/bin/perl

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
        30_stocks
        2914 3382 4063 4502 4503 5401 6301 6502 6752 6758 7201 7203 7267 7751
        7974 8031 8058 8306 8316 8411 8604 8766 8802 9020 9432 9433 9437 9501
        9503 9984
        60_funds
        02316097 42311066 32312965 01313068 02315097 45311065 01311969 0131100B
        17313073 0931106C 50311083 50314087 50315087 01317095 01312095 01318088
        0131B091 01314091 01312099 01316064 35311074 0431206B 49311059 0331306B
        47311076 09312075 03313073 4431307B 0431105B 79311059 5131109A 35312066
        01318887 1231199B 01319887 3231199B 0631299C 7931603B 79313057 06311093
        58311069 4731207C 45318007 17311093 08311052 08311046 2231E072 0431307B
        22311983 29311069 49318019 2931401B 79313009 22317019 0331298C 7831101C
        0231802C 6431406A 0331302B 01317079
        50_ETFs
        1305.t 1306.t 1308.t 1310.t 1311.t 1313.t 1314.t 1316.t 1317.t 1318.t 1319.t 1322.t 1325.t 1326.t
        1327.t 1329.t 1330.t 1343.t 1344.t 1345.t 1347.t 1348.t 1349.t 1540.t 1541.t 1542.t 1543.t 1544.t
        1610.t 1612.t 1613.t 1615.t 1617.t 1618.t 1619.t 1620.t 1621.t 1622.t 1623.t 1624.t 1625.t 1626.t
        1627.t 1628.t 1629.t 1630.t 1631.t 1632.t 1633.t 1634.t
    /;
}
