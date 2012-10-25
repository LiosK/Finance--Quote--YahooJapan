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
use Web::Scraper;
use YAML;

our $VERSION = '0.4';

our	$YAHOO_JAPAN_URL = 'http://info.finance.yahoo.co.jp/search';
our $_ERROR_DATE = '0000-00-00';

sub methods {
    return (yahoo_japan => \&yahoo_japan);
}

sub labels {
    return (yahoo_japan => ['method', 'success', 'name', 'date', 'time', 'currency', 'price']);
}

sub yahoo_japan {
    my ($quoter, @symbols) = @_;
    return unless @symbols; # Nothing if no symbols.
	my ($url, $page, $paging);
    my %info = ();
    my $ua = $quoter->user_agent;
	my @syms = ();

	$page = 1;
    # A request can contain less than 51 symbols.
	while (my @syms = splice @symbols, 0, 50) {
		$paging = 1;
		for ($page = 1; $paging == 1; $page++) {
			$url = $YAHOO_JAPAN_URL . '/?ei=UTF-8&view=l1&p=' . $page . '&query=' . join '+', @syms;
			my $reply = $ua->request(GET $url);
			if ($reply->is_success) {
				my $attrs = _get_page_attrs($reply->content, $page);
				if ($attrs->{single} ne '') {
					%info = (%info, _web_scrape_single($reply->content, @syms));
				} else {
					%info = (%info, _web_scrape($reply->content, @syms));
				}
				if ($attrs->{next} ne 'next') {
					$paging = 0;
				}
			} else {
				$paging = 0;
			}
		} 
	}
	
    return %info if wantarray;
    return \%info;
}

sub _get_page_attrs($;@) {
    my ($content, $current_page) = @_;
    my ($single, $next) = ('', '');

#	my $scraper = scraper {
#		process '//*[@id="divAddPortfolio"', 'add' => 'TEXT';
#		process '/html/body/div/div[2]/div[2]/div/div[2]/div/div', 'add' => '@id';
#	};
	
#	return defined($result->{add});

    my $tree = HTML::TreeBuilder->new;
    $tree->utf8_mode(1);
    $tree->parse($content);
    $tree->eof();

#	my $value = $tree->look_down('id', 'divAddPortfolio');
    my $single_element = $tree->look_down('id', 'divAddPortfolio');
    if (defined  $single_element) {
        $single = 'single';
    }
    my $next_element = $tree->look_down('class', 'ymuiPagingBottom clearFix');

    # when find next page link, go next page.
    my @pagination = $next_element->find('a') if (defined $next_element);
    foreach my $pageNum (@pagination) {
        if ($pageNum->as_text =~ /^\d+$/) {
            if ($pageNum->as_text == $current_page + 1) {
                $next = 'next';
                last;
            } else {
                $next = '';
            }
        }
    }

    my $attrs = {
        single => $single,
        next => $next
    };
    $tree->delete();
    return $attrs;
}

# scarpe single 
sub _web_scrape_single($;@) {
	my ($content, $symbol) = @_;
	my %info = ();
	my %stocks = ();
	
print "web_scrape_single" . "\n";
#	%stocks = _web_scrape_single_by_scraper($content, $symbol);	
	%stocks = _web_scrape_single_by_parse($content, $symbol);

	$info{$symbol, 'symbol'} = $symbol;
	$info{$symbol, 'success'} = 1;
	$info{$symbol, 'currency'} = 'JPY';
	$info{$symbol, 'method'} = 'yahoo_japan';
	$info{$symbol, 'name'} = $stocks{$symbol}->{name};
	$info{$symbol, 'date'} = $stocks{$symbol}->{date};
	$info{$symbol, 'time'} = $stocks{$symbol}->{time};
	my $price = $stocks{$symbol}->{price};
	$price =~ s/,//g;
	$info{$symbol, 'price'} = $price;
	$info{$symbol, 'errormsg'} = '';

	return %info;
}

sub _web_scrape_single_by_scraper($;@) {
	my ($content, $symbol) = @_;
	my %stocks = ();

	my $scraper = scraper {
		process '//dl[@class="stocksInfo"]//dt', 'stock', => 'TEXT';
		process '//td[@class="stoksPrice"]', 'price' => 'TEXT'; 
		process '//th[@class="symbol"]//h1', 'name' => 'TEXT';
		process '//dd[@class="yjSb real"]//span', 'date' => 'TEXT';
	};
	my $result = $scraper->scrape($content);

	my	$stock_info = {
		code => $result->{stock},
		name => $result->{name},
		price => $result->{price},
		date => _get_date($result->{date}),
		time => _get_time($result->{date})
	};

	$stocks{$symbol} = $stock_info;
	return %stocks;
}

sub _web_scrape_single_by_parse($;@) {
	my ($content, $symbol) = @_;
	my %stocks = ();
	my $tree = HTML::TreeBuilder->new;
	$tree->utf8_mode(1);
	$tree->parse($content);
	$tree->eof();

	my $stock_element = $tree->look_down('class', 'stocksInfo')->find('dt');
	my $price_element = $tree->look_down('class', 'stoksPrice');
	my $name_element = $tree->look_down('class', 'symbol')->find('h1');
	my $date_element = $tree->look_down('class', 'yjSb real')->find('span');
	my $stock_info = {
		code => $stock_element->as_text,
		name => $name_element->as_text,
		price => $price_element->as_text,
		date => _get_date($date_element->as_text),
		time => _get_time($date_element->as_text)
	};
	# detach memory
	$tree->delete();

	$stocks{$symbol} = $stock_info;
	return %stocks;
}

# web scrape 
sub _web_scrape($;@) {
	my ($content, @symbols) = @_;
	my %info = ();
	my %stocks = ();

#	%stocks = _web_scrape_by_scraper($content, @symbols);
	%stocks = _web_scrape_by_parse($content, @symbols);
			
	foreach my $symbol (@symbols) {
		if (defined $stocks{$symbol}) {
			$info{$symbol, 'symbol'} = $symbol;
			$info{$symbol, 'success'} = 1;
			$info{$symbol, 'currency'} = 'JPY';
			$info{$symbol, 'method'} = 'yahoo_japan';
			$info{$symbol, 'name'} = $stocks{$symbol}->{name};
			$info{$symbol, 'date'} = $stocks{$symbol}->{date};
			$info{$symbol, 'time'} = $stocks{$symbol}->{time};
			my $price = $stocks{$symbol}->{price}; 
			$price =~ s/,//g;
			$info{$symbol, 'price'} = $price;
			$info{$symbol, 'errormsg'} = '';
		} 
	}

#	foreach my $code (keys(%stocks)) {
#		print "stocks is : " . $stocks{$code}->{name} . "\n";
#	}	
		
	return %info;
}

sub _web_scrape_by_parse($;@) {
	my ($content, @symbols) = @_;
	my $tree = HTML::TreeBuilder->new;
	my %stocks = ();
	$tree->utf8_mode(1);
	$tree->parse($content);
	$tree->eof();

	my $tableLine = $tree->look_down('class', 'selectLine');
	my @elements = $tableLine->find('tr') if (defined $tableLine);
	foreach my $element (@elements) {
		my @row = $element->find('td');
		if (defined($row[0])) {
			my $stock_info = {
				code => $row[0]->as_text,
				name => $row[2]->as_text,
				price => $row[4]->as_text,
				date => _get_date($row[3]->as_text),
				time => _get_time($row[3]->as_text)
			};
			$stocks{$row[0]->as_text} = $stock_info;
		}
	}
	# detach memory
	$tree->delete();
	return %stocks;
}

# Web::Scraper
sub _web_scrape_by_scraper($;@) {
	my ($content, @symbols) = @_;
	my ($i, $j, @array);
	my %stocks = ();
	my $scraper = scraper {
		process '/html/body/div/div[2]/div[2]/div[1]/div[2]/table/tr', 'list[]' => scraper {
			process 'td', 'val[]' => 'TEXT';
		}
	};
	my $result = $scraper->scrape($content);

	# skip for header line(<th>) 
	for ($i = 1; $i < scalar @{$result->{list}} -1; $i++) {
		# dereference from hash.
		@array = @{$result->{list}->[$i]->{val}};

		my $stock_info = {
			code => $array[0],
			name => $array[2],
			price => $array[4],
			date => _get_date($array[3]),
			time => _get_time($array[3])
		};
		$stocks{$array[0]} = $stock_info;
	}
	return %stocks;
}

sub _get_date($;@) {
	my ($value) = @_;
	my ($date);

	if (defined $value) {
		if (index($value, '/') != -1) {
			$date = _parse_date($value);
		} else {
			my @now = localtime;
			$date = _parse_date($now[4]+1 . '/' . $now[3]);
		}
	} else {
		my @now = localtime;
		$date = _parse_date($now[4]+1 . '/' . $now[3]);
	}
	return $date;
}

sub _get_time($;@) {
	my ($value) = @_;
	my ($time);

	if (defined $value) {
		if (index($value, '/') != -1) {
			$time = '15:00:00'; 
		} else {
			$time = _parse_time($value);
		}
	} else {
		$time = '15:00:00'; 
	}
	return $time;
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
        my @cells = split /(?:&nbsp;|<[^>]+?>)+/, $row;
        my (undef, $sym, $name, $date, $time, $price) = @cells;

        # Formats data.
        $price =~ tr/0-9//cd if (defined $price);
        $date = _parse_date($date) if (defined $date);
        $time = _parse_time($time) if (defined $time);

        # Validates data.
        my $success = 1;
        $success = 0 if (!defined $price || $price eq '');
        $success = 0 if (!defined $date || $date eq $_ERROR_DATE);

        $info{$sym, 'success'}  = $success;
        $info{$sym, 'currency'} = 'JPY';
        $info{$sym, 'method'}   = 'yahoo_japan';
        $info{$sym, 'name'}     = $name;
        $info{$sym, 'date'}     = $date;
        $info{$sym, 'time'}     = $time;
        $info{$sym, 'price'}    = $price;
        $info{$sym, 'errormsg'} = $success ? '' : $row;
    }

    return %info;
}

# Determines the date of a quote.
sub _parse_date($;) {
    my ($date, @now) = (shift, localtime);
    if ($date =~ /(\d{1,2})\/(\d{1,2})/) {
        # MM/DD
        my ($yyyy, $mm, $dd) = ($now[5] + 1900, $1, $2);
        $yyyy-- if ($now[4] + 1 < $mm); # MM may point last December in January.
        return sprintf '%04d-%02d-%02d', $yyyy, $mm, $dd;
    } else {
        return $_ERROR_DATE;
    }
}

# Determines the time of a quote.
sub _parse_time($;) {
    my $time = shift;
    if ($time =~ /(\d{1,2}):(\d{1,2})/) {
        # HH:MM
        return sprintf '%02d:%02d:00', $1, $2;
    } else {
        return '15:00:00';  # XXX
    }
}

1;
