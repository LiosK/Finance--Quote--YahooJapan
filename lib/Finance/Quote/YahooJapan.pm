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

our $VERSION = '0.4';

# The maximum number of symbols a search query can contain.
our $N_Symbols_Per_Query = 30;

# The maximum number of pages to follow.
our $N_Pages_Per_Query = 3;

sub methods {
    return (yahoo_japan => \&yahoo_japan);
}

sub labels {
    return (yahoo_japan => ['method', 'success', 'symbol', 'name',
                            'date', 'time', 'currency', 'price', 'errormsg']);
}

sub yahoo_japan {
    my ($quoter, @symbols) = @_;
    return unless @symbols; # do nothing if no symbols.

    my $ua = $quoter->user_agent;
    my $url_base = 'http://info.finance.yahoo.co.jp/search/?ei=UTF-8&view=l1';

    my %info = ();
    my @retry_later = ();

    # initial trial loop: ignore page links.
    while (my @syms = splice @symbols, 0, $N_Symbols_Per_Query) {
        my $url = $url_base . '&query=' . join '+', @syms;
        my $reply = $ua->request(GET $url);
        if ($reply->is_success) {
            my $tree = HTML::TreeBuilder->new_from_content($reply->content);
            my %quotes = _scrape($tree);
            my $has_next_page = _has_next_page($tree, 1);
            $tree = $tree->delete;  # detach memory

            for my $sym (@syms) {
                next if ($info{$sym, 'success'});
                if (exists $quotes{$sym}) {
                    %info = (%info, _convert_quote($sym, $quotes{$sym}));
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
    while (my @syms = splice @retry_later, 0, $N_Symbols_Per_Query) {
        my %quotes = ();
        my $url = $url_base . '&query=' . join '+', @syms;
        for (my $page = 1; $page <= $N_Pages_Per_Query; $page++) {
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
                %info = (%info, _convert_quote($sym, $quotes{$sym}));
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
    my ($sym, $quote) = @_;
    my %info = ();
    $info{$sym, 'symbol'}   = $sym;
    $info{$sym, 'currency'} = 'JPY';
    $info{$sym, 'method'}   = 'yahoo_japan';
    $info{$sym, 'name'}     = $quote->{'name'};
    $info{$sym, 'date'}     = $quote->{'date'};
    $info{$sym, 'time'}     = $quote->{'time'};
    $info{$sym, 'price'}    = $quote->{'price'};

    # validate quote.
    my @errors = ();
    push @errors, 'Invalid name.' if ($info{$sym, 'name'} =~ /^\s*$/);
    push @errors, 'Invalid price.' if ($info{$sym, 'price'} eq '');

    $info{$sym, 'errormsg'} = join ' / ', @errors;
    $info{$sym, 'success'}  = $info{$sym, 'errormsg'} ? 0 : 1;

    return %info;
}

sub _scrape {
    my $tree = shift;

    # determine whether it is a single page or list page.
    my $elm_single_marker = $tree->look_down('class', 'stocksDtl');
    return (defined $elm_single_marker) ? _scrape_single_page($tree)
                                        : _scrape_list_page($tree);
}

sub _scrape_single_page {
    my $tree = shift;

    $tree = $tree->look_down('class', 'stocksDtl');
    my $elm_code     = $tree->look_down('class', 'stocksInfo')->find('dt');
    my $elm_price    = $tree->look_down('class', 'stoksPrice');
    my $elm_name     = $tree->look_down('class', 'symbol')->find('h1');
    my $elm_datetime = $tree->look_down('class', 'yjSb real')->find('span');

    my $sym = $elm_code->as_text;
    my $stock_info = {
        name  => $elm_name->as_text,
        price => $elm_price->as_text,
        date  => _parse_date($elm_datetime->as_text),
        time  => _parse_time($elm_datetime->as_text)
    };
    $stock_info->{'price'} =~ tr/0-9//cd;
    return ($sym => $stock_info);
}

sub _scrape_list_page {
    my $tree = shift;
    my %quotes = ();

    my $elm_table = $tree->look_down('class', 'selectLine');    # XXX
    if (defined $elm_table) {
        for my $tr ($elm_table->find('tr')) {
            if (my @row = $tr->find('td')) {
                my $sym = $row[0]->as_text;
                $quotes{$sym} = {
                    name  => $row[2]->as_text,
                    price => $row[4]->as_text,
                    date  => _parse_date($row[3]->as_text),
                    time  => _parse_time($row[3]->as_text)
                };
                $quotes{$sym}->{'price'} =~ tr/0-9//cd;
            }
        }
    }

    return %quotes;
}

# Determines the date of a quote.
sub _parse_date($;) {
    my $date = shift;
    my @now = localtime;
    my ($yyyy, $mm, $dd) = ($now[5] + 1900, $now[4] + 1, $now[3]);  # XXX

    if ($date =~ /(\d{1,2})\/(\d{1,2})/) {
        # MM/DD
        ($mm, $dd) = ($1, $2);
        $yyyy-- if ($now[4] + 1 < $mm); # MM may point last December in January.
    }

    return sprintf '%04d-%02d-%02d', $yyyy, $mm, $dd;
}

# Determines the time of a quote.
sub _parse_time($;) {
    my $time = shift;
    my ($hh, $mm) = (15, 0);  # XXX return 15:00:00 on error.

    if ($time =~ /(\d{1,2}):(\d{1,2})/) {
        # HH:MM
        ($hh, $mm) = ($1, $2);
    }

    return sprintf '%02d:%02d:00', $hh, $mm;
}

1;
