#!/usr/bin/perl -w

# Author:   LiosK <contact@mail.liosk.net>
# License:  The GNU General Public License
#
# Information obtained by this module may be covered by Yahoo's terms
# and conditions. See http://finance.yahoo.co.jp/ for more details.

package Finance::Quote::YahooJapan;

use strict;
use warnings;
use utf8;
use HTML::TreeBuilder;
use HTTP::Request::Common;

our $VERSION = '0.5';

# The maximum number of symbols a search query can contain.
my $n_symbols_per_query = 30;

# The maximum number of pages to follow.
my $n_pages_per_query = 3;

sub methods {
    return (yahoo_japan => \&yahoo_japan);
}

sub labels {
    return (yahoo_japan => ['method', 'success', 'symbol', 'name', 'date',
                            'isodate', 'time', 'currency', 'price', 'errormsg']);
}

sub yahoo_japan {
    my ($quoter, @symbols) = @_;
    return unless @symbols; # do nothing if no symbols.

    my $ua = $quoter->user_agent;
    my $url_base = 'http://info.finance.yahoo.co.jp/search/';

    my %info = ();
    my @retry_later = ();

    # initial trial loop: ignore page links.
    while (my @syms = splice @symbols, 0, $n_symbols_per_query) {
        my $url = $url_base . '?query=' . join '+', @syms;
        # a trick to avoid single-item pages.
        $url .= '+%5EDJI' if (@syms < 3 && @syms < $n_symbols_per_query);

        my $reply = $ua->request(GET $url);
        if ($reply->is_success) {
            my $tree = HTML::TreeBuilder->new_from_content($reply->content);
            my %quotes = _scrape($tree);
            my $has_next_page = _has_next_page($tree, 1);
            $tree = $tree->delete;  # detach memory

            for my $sym (@syms) {
                next if ($info{$sym, 'success'});
                if (exists $quotes{$sym}) {
                    %info = (%info, _convert_quote($quoter, $sym, $quotes{$sym}));
                } elsif ($has_next_page) {
                    push @retry_later, $sym;
                } else {
                    $info{$sym, 'success'}  = 0;
                    $info{$sym, 'symbol'}   = $sym;
                    $info{$sym, 'method'}   = 'yahoo_japan';
                    $info{$sym, 'errormsg'} = 'Requested quote not found.';
                }
            }
        }
    }

    # retry loop: follow page links.
    while (my @syms = splice @retry_later, 0, $n_symbols_per_query) {
        my %quotes = ();
        my $url = $url_base . '?query=' . join '+', @syms;
        # a trick to avoid single-item pages.
        $url .= '+%5EDJI' if (@syms < 3 && @syms < $n_symbols_per_query);

        for (my $page = 1; $page <= $n_pages_per_query; $page++) {
            my $reply = $ua->request(GET $url . '&p=' . $page);
            if ($reply->is_success) {
                my $tree = HTML::TreeBuilder->new_from_content($reply->content);
                %quotes = (%quotes, _scrape($tree));
                my $has_next_page = _has_next_page($tree, $page);
                $tree = $tree->delete;  # detach memory

                last if (!$has_next_page);
            }
        }
        for my $sym (@syms) {
            next if ($info{$sym, 'success'});
            if (exists $quotes{$sym}) {
                %info = (%info, _convert_quote($quoter, $sym, $quotes{$sym}));
            } else {
                $info{$sym, 'success'}  = 0;
                $info{$sym, 'symbol'}   = $sym;
                $info{$sym, 'method'}   = 'yahoo_japan';
                $info{$sym, 'errormsg'} = 'Requested quote not found.';
            }
        }
    }

    return %info if wantarray;
    return \%info;
}

sub n_symbols_per_query {
    my $class = shift;
    return $n_symbols_per_query if (!@_);
    $n_symbols_per_query = shift;
    return $class;
}

sub n_pages_per_query {
    my $class = shift;
    return $n_pages_per_query if (!@_);
    $n_pages_per_query = shift;
    return $class;
}

# Tests if a list page has the next page of it.
sub _has_next_page {
    my ($tree, $current_page) = @_;

    my $elm_paging = $tree->look_down('class', 'ymuiPagingBottom clearFix');
    if (defined $elm_paging) {
        for my $page_link ($elm_paging->find('a')) {
            my $num = $page_link->as_text;
            return 1 if ($num =~ /^\d+$/ && $num == $current_page + 1);
        }
    }

    return 0;
}

# Converts an internal quote data to Finance::Quote-style one.
sub _convert_quote {
    my ($quoter, $sym, $quote) = @_;
    my %info = ();
    $info{$sym, 'symbol'}   = $sym;
    $info{$sym, 'currency'} = 'JPY';
    $info{$sym, 'method'}   = 'yahoo_japan';
    $info{$sym, 'name'}     = $quote->{'name'};
    $info{$sym, 'date'}     = $quote->{'date'};
    $info{$sym, 'isodate'}  = $quote->{'date'};
    $info{$sym, 'time'}     = $quote->{'time'};
    $info{$sym, 'price'}    = $quote->{'price'};

    # validate quote.
    my @errors = ();
    push @errors, 'Invalid name.' if ($info{$sym, 'name'} =~ /^\s*$/);
    push @errors, 'Invalid price.' if ($info{$sym, 'price'} eq '');
    if ($info{$sym, 'date'} eq '') {
        push @errors, 'Invalid datetime.';
    } else {
        $quoter->store_date(\%info, $sym, { isodate => $info{$sym, 'date'} });
    }

    $info{$sym, 'errormsg'} = join ' / ', @errors;
    $info{$sym, 'success'}  = $info{$sym, 'errormsg'} ? 0 : 1;

    return %info;
}

sub _scrape {
    my $tree = shift;
    my %quotes = ();

    my $container = $tree->look_down('id', 'sr');
    if (defined $container) {
        for my $e ($container->look_down('class', 'stocks')) {
            my $sym = substr $e->look_down('class', 'code highlight')->as_text, 1, -1;
            my ($date, $time) = _parse_datetime($e->look_down('class', 'time')->as_text);
            my $quote = {
                name  => $e->look_down('class', 'name highlight')->as_text,
                price => $e->look_down('class', 'price yjXXL')->as_text,
                date  => $date,
                time  => $time
            };
            $quote->{'price'} =~ tr/.0-9//cd;   # strip commas, etc.

            # for a stock code, register a duplicate quote with market letter
            if ($sym =~ /^[0-9A-Z]{2}\d[0-9A-Z]\d?$/) {
                my $pat = qr/code=($sym\.[A-Z])/;
                $e->look_down('_tag', 'a', 'href', $pat)->attr('href') =~ $pat;
                $quotes{lc $1} = $quote if (defined $1);
            }

            # XXX destructive when a stock quote from other market already exists
            $quotes{$sym} = $quote;
        }
    }

    return %quotes;
}

# Determines the date and time of a quote.
sub _parse_datetime($;) {
    my $datetime = shift;
    my @now = localtime;
    my ($year, $mon, $mday, $time) = ($now[5] + 1900, 0, 0, '15:00:00');

    if ($datetime =~ /(\d{1,2}):(\d{1,2})/) {
        # HH:MM
        $time = sprintf '%02d:%02d:00', $1, $2;
        ($mon, $mday) = ($now[4] + 1, $now[3]);
    }
    if ($datetime =~ /(\d{1,2})\/(\d{1,2})/) {
        # MM/DD
        ($mon, $mday) = ($1, $2);
        $year-- if ($now[4] + 1 < $mon); # MM may point last December in January.
    }

    my $date = sprintf '%04d-%02d-%02d', $year, $mon, $mday;
    return ($mon && $mday) ? ($date, $time) : ('', '');
}

1;
