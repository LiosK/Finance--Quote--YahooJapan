#!/usr/bin/perl

use utf8;
use strict;
use warnings;
use Finance::Quote;

# list of target securities
my @symbols = qw/30_stocks
                 2914 3382 4063 4502 4503 5401 6301 6502 6752 6758
                 7201 7203 7267 7751 7974 8031 8058 8306 8316 8411
                 8604 8766 8802 9020 9432 9433 9437 9501 9503 9984
                 60_funds
                 02316097 42311066 32312965 01313068 02315097 45311065
                 01311969 0131100B 17313073 0931106C 50311083 50314087
                 50315087 01317095 01312095 01318088 0131B091 01314091
                 01312099 01316064 35311074 0431206B 49311059 0331306B
                 47311076 09312075 03313073 4431307B 0431105B 79311059
                 5131109A 35312066 01318887 1231199B 01319887 3231199B
                 0631299C 7531103B 75311057 06311093 58311069 4731207C
                 45318007 17311093 08311052 08311046 2231E072 0431307B
                 22311983 29311069 49318019 2931401B 79313009 22317019
                 0331298C 7831101C 0231802C 6431406A 0331302B 01317079
                 50_ETFs
                 1305 1306 1308 1310 1311 1313 1314 1316 1317 1318
                 1319 1322 1325 1326 1327 1329 1330 1343 1344 1345
                 1347 1348 1349 1540 1541 1542 1543 1544 1610 1612
                 1613 1615 1617 1618 1619 1620 1621 1622 1623 1624
                 1625 1626 1627 1628 1629 1630 1631 1632 1633 1634
                 /;

# target securities passed as command line arguments
if (@ARGV) {
    my ($head, @tail) = @ARGV;
    if ($head eq '--replace') {
        @symbols = @tail;
    } elsif ($head eq '--append') {
        push @symbols, @tail;
    } else {
        push @symbols, @ARGV;
    }
}

# fetch and print quotes
my $q = Finance::Quote->new('-defaults', 'YahooJapan')->yahoo_japan(@symbols);

my @fields = qw/success currency method name date time price errormsg/;
print join("\t", 'symbol', @fields), "\n";
for my $sym (@symbols) {
  print join("\t", $sym, map { $q->{$sym, $_} // 'N/A' } @fields), "\n";
}
