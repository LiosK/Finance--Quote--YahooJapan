use utf8;
use strict;
use warnings;
use Test::More;


require_ok('Finance::Quote');
my $q = Finance::Quote->new('-defaults', 'YahooJapan');
isa_ok($q, 'Finance::Quote');


ok(grep(/^yahoo_japan$/, $q->sources()), '"yahoo_japan" in $quote->sources()');


cmp_ok(Finance::Quote::YahooJapan->n_symbols_per_query(), '>', 0, 'Finance::Quote::YahooJapan->n_symbols_per_query() > 0');
my $n_symbols_per_query = Finance::Quote::YahooJapan->n_symbols_per_query();
Finance::Quote::YahooJapan->n_symbols_per_query($n_symbols_per_query + 3);
is(Finance::Quote::YahooJapan->n_symbols_per_query(), $n_symbols_per_query + 3, 'Finance::Quote::YahooJapan->n_symbols_per_query($n_symbols_per_query)');


cmp_ok(Finance::Quote::YahooJapan->n_pages_per_query(), '>', 0, 'Finance::Quote::YahooJapan->n_pages_per_query() > 0');
my $n_pages_per_query = Finance::Quote::YahooJapan->n_pages_per_query();
Finance::Quote::YahooJapan->n_pages_per_query($n_pages_per_query + 3);
is(Finance::Quote::YahooJapan->n_pages_per_query(), $n_pages_per_query + 3, 'Finance::Quote::YahooJapan->n_pages_per_query($n_pages_per_query)');


cmp_ok(Finance::Quote::YahooJapan->delay_per_request(), '>', 0, 'Finance::Quote::YahooJapan->delay_per_request() > 0');
my $delay_per_request = Finance::Quote::YahooJapan->delay_per_request();
Finance::Quote::YahooJapan->delay_per_request($delay_per_request + 1);
is(Finance::Quote::YahooJapan->delay_per_request(), $delay_per_request + 1, 'Finance::Quote::YahooJapan->delay_per_request($delay_per_request)');


done_testing;
