#!/usr/bin/perl -w

# Author:   LiosK <contact@mail.liosk.net>
# License:  The GNU General Public License

package Finance::Quote::YahooJapan;

use strict;
use warnings;
use utf8;
use HTTP::Request::Common;
use Encode qw/encode decode/;

our $VERSION = '0.1';

our $YAHOO_JAPAN_URL = 'http://quote.yahoo.co.jp/q';

sub methods {
    return (yahoo_japan => \&yahoo_japan);
}

sub labels {
    return (yahoo_japan => ['method', 'success', 'date', 'currency', 'price']);
}

sub yahoo_japan {
    my $quoter = shift;
    my @symbols = @_;
    return unless @symbols; # Nothing if no symbols.

    my %info = ();
    my $ua = $quoter->user_agent;

    # my $sym = shift @symbols;
    # $info{$sym, 'price'} = 5000;
    # $info{$sym, 'currency'} = 'JPY';
    # $info{$sym, 'date'} = '2009-06-20';
    # $info{$sym, 'success'} = 1;
    # $info{$sym, 'method'} = 'yahoo_japan';

    # A request can contain less than 51 symbols.
    while (my @syms = splice @symbols, 0, 50) {
        my $url = $YAHOO_JAPAN_URL . '?s=' . join '+', @syms;
        my $reply = $ua->request(GET $url);
        if ($reply->is_success) {
            _scrape(\%info, $reply->content, @syms);
        }
    }

    return %info if wantarray;
    return \%info;
}

sub _scrape {
    my ($info, $content, @symbols) = @_;

    # Extracting price list table.
    ($content) = $content =~ /<tr class=chartbg>(.+?)<\/table>/s;
    my @list = grep /^<td/, split /\x0D?\x0A/, $content;
}

1;
