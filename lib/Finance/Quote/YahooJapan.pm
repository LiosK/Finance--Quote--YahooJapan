#!/usr/bin/perl -w

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
    return (yahoo_japan => []);
}

sub yahoo_japan {
    my $quoter = shift;
    my @symbols = @_;
    return unless @symbols; # Nothing if no symbols.

    my %info = ();
    my $ua = $quoter->user_agent;

    # A request can contain less than 51 symbols.
    while (my @syms = splice @symbols, 0, 50) {
        my $url = $YAHOO_JAPAN_URL . '?s=' . join '+', @syms;
        my $reply = $ua->request(GET $url);
        if ($reply->is_success) {
            _scrape(\%info, decode 'euc-jp', $reply->content);
        }
    }

    return %info if wantarray;
    return \%info;
}

sub _scrape {
    my $info = shift;
    $info->{'hello'} = encode 'sjis', shift;
}

1;
