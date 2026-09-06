package Finance::Quote::YahooJapan;

use utf8;
use 5.018;
use warnings;
use HTML::TreeBuilder 5 -weak;
use URI::Escape;
use JSON::PP;

our $VERSION = 'v1.2.5';

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
    return (yahoo_japan => [qw(method success symbol name date isodate time currency price last nav errormsg)]);
}

sub yahoo_japan {
    my ($quoter, @symbols) = @_;
    return if (!@symbols);

    my $ua = $quoter->get_user_agent;

    my $url_base = 'https://finance.yahoo.co.jp/search/';
    my %info = ();
    my @retry_later = ();

    # Initial trial loop: ignore page links.
    while (my @syms = splice @symbols, 0, $n_symbols_per_query) {
        my $url = $url_base . '?query=' . join '+', map { uri_escape($_) } @syms;
        # Avoid single-item auto-redirect pages
        $url .= '+%5EDJI' if (@syms < 3 && @syms < $n_symbols_per_query);

        my $reply = $ua->get($url);
        if ($reply->is_success) {
            my $content = $reply->decoded_content;
            my $tree = HTML::TreeBuilder->new;
            $tree->ignore_unknown(0);
            $tree->parse_content($content);

            my %quotes = _scrape($tree, $content);
            my $has_next_page = _has_next_page($tree, 1);

            for my $sym (@syms) {
                next if ($info{$sym, 'success'});
                my $match = _lookup_quote(\%quotes, $sym);
                if ($match) {
                    %info = (%info, _convert_quote($quoter, $sym, $match));
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

    # Retry loop: follow page links.
    while (my @syms = splice @retry_later, 0, $n_symbols_per_query) {
        my %quotes = ();
        my $url = $url_base . '?query=' . join '+', map { uri_escape($_) } @syms;
        $url .= '+%5EDJI' if (@syms < 3 && @syms < $n_symbols_per_query);

        for (my $page = 1; $page <= $n_pages_per_query; $page++) {
            select undef, undef, undef, $delay_per_request;
            my $reply = $ua->get($url . '&page=' . $page);
            if ($reply->is_success) {
                my $content = $reply->decoded_content;
                my $tree = HTML::TreeBuilder->new;
                $tree->ignore_unknown(0);
                $tree->parse_content($content);

                my %scraped = _scrape($tree, $content);
                %quotes = (%quotes, %scraped);
                my $has_next_page = _has_next_page($tree, $page);

                last if (!$has_next_page);
            }
        }
        for my $sym (@syms) {
            next if ($info{$sym, 'success'});
            my $match = _lookup_quote(\%quotes, $sym);
            if ($match) {
                %info = (%info, _convert_quote($quoter, $sym, $match));
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

sub _lookup_quote {
    my ($quotes, $sym) = @_;
    return $quotes->{$sym} if exists $quotes->{$sym};
    return $quotes->{lc $sym} if exists $quotes->{lc $sym};
    return $quotes->{uc $sym} if exists $quotes->{uc $sym};

    (my $base = $sym) =~ s/\.[A-Za-z]+$//;
    return $quotes->{$base} if exists $quotes->{$base};
    return $quotes->{lc $base} if exists $quotes->{lc $base};
    return undef;
}

sub _has_next_page {
    my ($tree, $current_page) = @_;

    my $elm_paging = $tree->look_down('id', 'pagerbtm');
    if (defined $elm_paging) {
        for my $btn ($elm_paging->find('button')) {
            my $txt = $btn->as_text // '';
            return 1 if ($txt =~ /^[0-9]+$/ && $txt == $current_page + 1);
            return 1 if ($txt =~ /次へ/ && !$btn->attr('disabled'));
        }
    }

    return 0;
}

sub _convert_quote {
    my ($quoter, $sym, $quote) = @_;
    my %info = ();

    # Base metadata
    $info{$sym, 'symbol'}   = $sym;
    $info{$sym, 'currency'} = 'JPY';
    $info{$sym, 'method'}   = 'yahoo_japan';
    $info{$sym, 'name'}     = $sym; # Keep ASCII to avoid JSON serializer crashes

    my $raw_price = $quote->{'price'} // '';
    $raw_price =~ tr/.0-9//cd;

    if ($raw_price eq '') {
        $info{$sym, 'success'}  = 0;
        $info{$sym, 'errormsg'} = 'Invalid price.';
        return %info;
    }

    # Mutual fund divisor handling
    my $num_price = 0 + $raw_price;
    if ($sym =~ /^[0-9]{8}$/ || ($quote->{'is_fund'} // 0)) {
        $num_price = $num_price / 10000;
    }

    # Set numeric price across all GnuCash price aliases
    $info{$sym, 'price'} = $num_price;
    $info{$sym, 'last'}  = $num_price;
    $info{$sym, 'nav'}   = $num_price;

    # Date normalization
    my $date_str = $quote->{'date'};
    if (!defined $date_str || $date_str !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/) {
        my @now = localtime;
        $date_str = sprintf('%04d-%02d-%02d', $now[5] + 1900, $now[4] + 1, $now[3]);
    }

    $info{$sym, 'date'}    = $date_str;
    $info{$sym, 'isodate'} = $date_str;
    $info{$sym, 'time'}    = $quote->{'time'} || '15:00:00';

    # Populate standard Finance::Quote date keys
    eval {
        $quoter->store_date(\%info, $sym, { isodate => $date_str });
    };

    $info{$sym, 'success'}  = 1;
    $info{$sym, 'errormsg'} = '';

    return %info;
}

sub _scrape {
    my ($tree, $raw_html) = @_;
    my %quotes = ();

    # Strategy 1: Extract __PRELOADED_STATE__ directly using JSON::PP
    if (defined $raw_html && $raw_html =~ m{window\.__PRELOADED_STATE__\s*=\s*(\{.*?\});?\s*</script>}s) {
        my $json_text = $1;
        my $json_parser = JSON::PP->new->utf8(0);
        my $data = eval { $json_parser->decode($json_text) };
        if ($data && ref $data eq 'HASH' && exists $data->{mainSearchList}{results}) {
            for my $item (@{ $data->{mainSearchList}{results} }) {
                my $code = $item->{code};
                next unless defined $code;

                my ($date, $time) = _parse_datetime($item->{latestPriceTime} // '');
                my $price = $item->{price} // '';
                $price =~ tr/.0-9//cd;
                next if $price eq '';

                my $quote = {
                    name    => $item->{name} // '',
                    price   => $price,
                    date    => $date,
                    time    => $time,
                    is_fund => ($item->{marketName} && $item->{marketName} =~ /投資信託/) ? 1 : 0,
                };

                $quotes{$code} = $quote;
                $quotes{lc $code} = $quote;

                if ($item->{detailLink} && $item->{detailLink} =~ m{(?:quote/|code=)([^/\?]+)}) {
                    my $full_ticker = $1;
                    $quotes{$full_ticker} = $quote;
                    $quotes{lc $full_ticker} = $quote;
                    (my $root = $full_ticker) =~ s/\.[A-Za-z]+$//;
                    $quotes{$root} = $quote;
                    $quotes{lc $root} = $quote;
                }
            }
            return %quotes if %quotes;
        }
    }

    # Strategy 2: DOM fallback
    my $container = $tree->look_down('id', 'sr') // $tree->look_down('id', 'root');
    if (defined $container) {
        for my $e ($container->find('article')) {
            my $sym_elem  = $e->look_down('class', qr/SearchItem__supplement/)
                         // $e->look_down('class', qr/SearchItem__code/);
            my $name_elem = $e->look_down('class', qr/SearchItem__name/);
            my $price_elem = $e->look_down('class', qr/SearchItem__price\b/);
            my $time_elem = $e->find('time');

            next unless ($sym_elem && $price_elem);

            my $sym = $sym_elem->as_text;
            $sym =~ s/^\s+|\s+$//g;

            my $price = $price_elem->as_text;
            $price =~ tr/.0-9//cd;
            next if $price eq '';

            my ($date, $time) = $time_elem ? _parse_datetime($time_elem->as_text) : ('', '');

            my $quote = {
                name    => $name_elem ? $name_elem->as_text : '',
                price   => $price,
                date    => $date,
                time    => $time,
                is_fund => 0,
            };

            $quotes{$sym} = $quote;
            $quotes{lc $sym} = $quote;

            my $link = $e->look_down('_tag', 'a', 'href', qr/quote\//);
            if ($link && $link->attr('href') =~ m{quote/([^/\?]+)}) {
                my $full_ticker = $1;
                $quotes{$full_ticker} = $quote;
                $quotes{lc $full_ticker} = $quote;
                (my $root = $full_ticker) =~ s/\.[A-Za-z]+$//;
                $quotes{$root} = $quote;
                $quotes{lc $root} = $quote;
            }
        }
    }

    return %quotes;
}

sub _parse_datetime($;) {
    my $datetime = shift // '';
    my @now = localtime;
    my ($year, $mon, $mday, $time) = ($now[5] + 1900, 0, 0, '15:00:00');

    if ($datetime =~ /([0-9]{1,2}):([0-9]{1,2})/) {
        $time = sprintf '%02d:%02d:00', $1, $2;
        ($mon, $mday) = ($now[4] + 1, $now[3]);
    }
    if ($datetime =~ /([0-9]{1,2})\/([0-9]{1,2})/) {
        ($mon, $mday) = ($1, $2);
        $year-- if ($now[4] + 1 < $mon);
    }

    my $date = ($mon && $mday) ? sprintf('%04d-%02d-%02d', $year, $mon, $mday) : sprintf('%04d-%02d-%02d', $now[5] + 1900, $now[4] + 1, $now[3]);
    return ($date, $time);
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

Install and setup Finance::Quote module as explained in the GnuCash Help Manual: L<https://www.gnucash.org/docs/v5/C/gnucash-manual/acct-create.html#accts-online-quotes>

=head2 2. Install Finance::Quote::YahooJapan

a. Type C<cpanm https://github.com/LiosK/Finance--Quote--YahooJapan.git> in the terminal. Or, if you don't prefer to use C<cpanm>, locate the directory where F<Finance::Quote::*> are installed, and then put F<lib/Finance/Quote/YahooJapan.pm> in the directory.

b. Set the C<FQ_LOAD_QUOTELET> environment variable to C<-defaults YahooJapan> in order to load Finance::Quote::YahooJapan.

=head2 3. Setup GnuCash Online Quote Feature

Launch GnuCash and setup your securities as explained in the Manual: L<https://www.gnucash.org/docs/v5/C/gnucash-manual/acct-create.html#accts-online-quotes>

=head1 LICENSE

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

Quotations fetched through this module are bound by Yahoo!'s terms and conditions. See L<https://finance.yahoo.co.jp/> for more details.

=head1 AUTHOR

LiosK E<lt>contact@mail.liosk.netE<gt>

=head1 SEE ALSO

Finance::Quote

=cut
