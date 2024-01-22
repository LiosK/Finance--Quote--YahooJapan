package Finance::Quote::YahooJapan;

use utf8;
use 5.018;
use warnings;
use HTML::TreeBuilder 5 -weak;
use URI::Escape;

our $VERSION = 'v1.2.0';

# Maximum number of symbols that a search query can contain.
my $n_symbols_per_query = 4;

# Maximum number of page links to follow per query.
my $n_pages_per_query = 3;

# Delay in seconds between HTTP requests.
my $delay_per_request = 0.25;

sub methods {
    return (yahoo_japan => \&yahoo_japan);
}

sub labels {
    return (yahoo_japan => ['method', 'success', 'symbol', 'name', 'date',
                            'isodate', 'time', 'currency', 'price', 'errormsg']);
}

sub yahoo_japan {
    my ($quoter, @symbols) = @_;
    return if (!@symbols); # do nothing if no symbols.

    my $ua = $quoter->get_user_agent;
    my $url_base = 'https://finance.yahoo.co.jp/search/';

    my %info = ();
    my @retry_later = ();

    # initial trial loop: ignore page links.
    while (my @syms = splice @symbols, 0, $n_symbols_per_query) {
        my $url = $url_base . '?query=' . join '+', map { uri_escape($_) } @syms;
        # trick to avoid single-item pages
        $url .= '+%5EDJI' if (@syms < 3 && @syms < $n_symbols_per_query);

        my $reply = $ua->get($url);
        if ($reply->is_success) {
            my $tree = HTML::TreeBuilder->new;
            $tree->ignore_unknown(0);
            $tree->parse_content($reply->content);
            my %quotes = _scrape($tree);
            my $has_next_page = _has_next_page($tree, 1);

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

        if (@symbols) { select undef, undef, undef, $delay_per_request; }
    }

    # retry loop: follow page links.
    while (my @syms = splice @retry_later, 0, $n_symbols_per_query) {
        my %quotes = ();
        my $url = $url_base . '?query=' . join '+', map { uri_escape($_) } @syms;
        # trick to avoid single-item pages
        $url .= '+%5EDJI' if (@syms < 3 && @syms < $n_symbols_per_query);

        for (my $page = 1; $page <= $n_pages_per_query; $page++) {
            select undef, undef, undef, $delay_per_request;
            my $reply = $ua->get($url . '&page=' . $page);
            if ($reply->is_success) {
                my $tree = HTML::TreeBuilder->new;
                $tree->ignore_unknown(0);
                $tree->parse_content($reply->content);
                %quotes = (%quotes, _scrape($tree));
                my $has_next_page = _has_next_page($tree, $page);

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

sub delay_per_request {
    my $class = shift;
    return $delay_per_request if (!@_);
    $delay_per_request = shift;
    return $class;
}

# Tests if a list page has the next page of it.
sub _has_next_page {
    my ($tree, $current_page) = @_;

    my $elm_paging = $tree->look_down('id', 'pagerbtm');
    if (defined $elm_paging) {
        for my $page_link ($elm_paging->find('button')) {
            my $num = $page_link->as_text;
            return 1 if ($num =~ /^[0-9]+$/ && $num == $current_page + 1);
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
        # process each <article> that represents a single item
        for my $e ($container->find('article')) {
            my $sym = $e->look_down('class', '_2QwBsxBs')->as_text;
            my ($date, $time) = _parse_datetime($e->find('time')->as_text);
            my $tmp = $e->look_down('class', '_1ApM7LhG');
            if (!defined $tmp){
		$tmp = $e->find('h1');
            };
            my $quote = {
		name  => $tmp->as_text,
                price => $e->look_down('class', '_3rXWJKZF')->as_text,
                date  => $date,
                time  => $time
            };
            $quote->{'price'} =~ tr/.0-9//cd;   # strip commas, etc.

            # for a stock code, register a duplicate quote with market letter
            if ($sym =~ /^[0-9A-Z]{2}[0-9][0-9A-Z][0-9]?$/) {
                my $pat = qr/(?:quote\/|code=)($sym\.[A-Z])/;
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

    if ($datetime =~ /([0-9]{1,2}):([0-9]{1,2})/) {
        # HH:MM
        $time = sprintf '%02d:%02d:00', $1, $2;
        ($mon, $mday) = ($now[4] + 1, $now[3]);
    }
    if ($datetime =~ /([0-9]{1,2})\/([0-9]{1,2})/) {
        # MM/DD
        ($mon, $mday) = ($1, $2);
        $year-- if ($now[4] + 1 < $mon); # MM may point last December in January.
    }

    my $date = sprintf '%04d-%02d-%02d', $year, $mon, $mday;
    return ($mon && $mday) ? ($date, $time) : ('', '');
}

1;
__END__

=head1 NAME

Finance::Quote::YahooJapan - A Perl module that enables GnuCash to get quotes of Japanese stocks and mutual funds from Yahoo! Finance JAPAN.

=head1 SYNOPSIS

    use Finance::Quote;
    my $q = Finance::Quote->new('-defaults', 'YahooJapan');
    my %quotes = $q->fetch('yahoo_japan', '6758', '6861', '7203');

=head1 DESCRIPTION

Finance::Quote::YahooJapan is a submodule of Finance::Quote, and adds support for Japanese stock and mutual fund quotes. This module extracts these quotes from the result pages of Yahoo! Finance JAPAN's stock price search service. Thus this module enables GnuCash to obtain Japanese quotes through its online price update feature.

=head1 SETUP

=head2 1. Install Finance::Quote

Install and setup Finance::Quote module as explained in the GnuCash Help Manual: L<https://code.gnucash.org/docs/C/gnucash-help/acct-create.html#accts-online-quotes>

=head2 2. Install Finance::Quote::YahooJapan

a. Type C<cpanm https://github.com/LiosK/Finance--Quote--YahooJapan.git> in the terminal. Or, if you don't prefer to use C<cpanm>, locate the directory where F<Finance::Quote::*> are installed, and then put F<lib/Finance/Quote/YahooJapan.pm> in the directory.

b. Set the C<FQ_LOAD_QUOTELET> environment variable to C<-defaults YahooJapan> in order to load Finance::Quote::YahooJapan.

=head2 3. Setup GnuCash Online Quote Feature

Launch GnuCash and setup your securities as explained in the Manual: L<https://code.gnucash.org/docs/C/gnucash-help/acct-create.html#accts-online-quotes>

=head1 LICENSE

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

Quotations fetched through this module are bound by Yahoo!'s terms and conditions. See L<https://finance.yahoo.co.jp/> for more details.

=head1 AUTHOR

LiosK E<lt>contact@mail.liosk.netE<gt>

=head1 SEE ALSO

Finance::Quote

=cut
