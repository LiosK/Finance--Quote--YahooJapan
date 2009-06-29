#!/usr/bin/perl -w

# Author:   LiosK <contact@mail.liosk.net>
# License:  The GNU General Public License
#
# Information obtained by this module may be covered by Yahoo's terms
# and conditions. See http://quote.yahoo.co.jp/ for more details.

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
    return (yahoo_japan => ['method', 'success', 'name', 'date', 'currency', 'price']);
}

sub yahoo_japan {
    my ($quoter, @symbols) = @_;
    return unless @symbols; # Nothing if no symbols.

    my %info = ();
    my $ua = $quoter->user_agent;

    # A request can contain less than 51 symbols.
    while (my @syms = splice @symbols, 0, 50) {
        my $url = $YAHOO_JAPAN_URL . '?s=' . join '+', @syms;
        my $reply = $ua->request(GET $url);
        if ($reply->is_success) {
            # The way to extract quotes from a HTTP response is defined in
            # another subroutine because it is quite likely to be modified.
            %info = (%info, _scrape($reply->content, @syms));
        }
    }

    return %info if wantarray;
    return \%info;
}

# Scrapes quotes from a HTML text.
sub _scrape($;@) {
    my ($content, @symbols) = @_;
    my %info = ();

    # Extracts price list table.
    # XXX: Using an ugly, inflexible and unsophisticated algorithm.
    ($content) = $content =~ /<tr class=chartbg>(.+?)<\/table>/s;
    my @table = grep /^<td/, split /\x0D?\x0A/, $content;

    foreach my $row (@table) {
        $row =~ s/&nbsp;|<[^>]+?>/ /g;  # Stripping tags and NBSPs.
        my (undef, $sym, undef, $name, $date, $price) = split /\s+/, $row;

        # Formats data.
        $price =~ s/,//g;   # TODO
        $date = _determine_date($date);

        # Validates data.
        # TODO

        $info{$sym, 'success'}  = 1;
        $info{$sym, 'currency'} = 'JPY';
        $info{$sym, 'method'}   = 'yahoo_japan';
        $info{$sym, 'name'}     = $name;
        $info{$sym, 'date'}     = $date;
        $info{$sym, 'price'}    = $price;
    }

    return %info;
}

# Determines the date of a quote.
sub _determine_date($;) {
    my ($date, @now) = (shift, localtime);
    if ($date =~ /\d{1,2}\/\d{1,2}/) {
        # MM/DD
        return $date . '/' . ($now[5] + 1900);
    } else {
        return '0000-00-00';
    }
}

1;
