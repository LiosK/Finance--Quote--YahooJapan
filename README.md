# NAME

Finance::Quote::YahooJapan - A Perl module that enables GnuCash to get quotes of Japanese stocks and funds from Yahoo! JAPAN.

# SYNOPSIS

    use Finance::Quote;
    my $q = Finance::Quote->new('-defaults', 'YahooJapan');
    my %quotes = $q->fetch('yahoo_japan', '7203', '8306', '9437');

# DESCRIPTION

Finance::Quote::YahooJapan is a submodule of Finance::Quote, and adds support for Japanese stock and mutual fund quotes. This module allows GnuCash to fetch these quotes from Yahoo! Finance JAPAN [http://finance.yahoo.co.jp/](http://finance.yahoo.co.jp/) with online price update feature.

This module obtains quotes by extracting them from the search result pages of Yahoo! Finance JAPAN's stock price search service. Thus the quotes fetched through this module are bound by Yahoo!'s terms and conditions.

See my blog article for more detailed information: [http://liosk.blog103.fc2.com/blog-entry-185.html](http://liosk.blog103.fc2.com/blog-entry-185.html) (ja)

# USAGE

## 1. Install Finance::Quote

Install and setup Finance::Quote module as explained in the GnuCash Help Manual: [http://svn.gnucash.org/docs/C/gnucash-help/acct-create.html#Online-price-setup](http://svn.gnucash.org/docs/C/gnucash-help/acct-create.html#Online-price-setup)

## 2. Install Finance::Quote::YahooJapan

a. Locate the directory where Finance::Quote is installed and then put the submodule file `YahooJapan.pm` at `Finance/Quote/YahooJapan.pm`.

b. Set the `FQ_LOAD_QUOTELET` environment variable to `-defaults YahooJapan` in order to load Finance::Quote::YahooJapan.

## 3. Setup GnuCash Online Quote Feature

Launch GnuCash and setup your securities as explained in the Manual: [http://svn.gnucash.org/docs/C/gnucash-help/acct-create.html#Online-price-setup](http://svn.gnucash.org/docs/C/gnucash-help/acct-create.html#Online-price-setup)

# LIMITATIONS

Finance::Quote::YahooJapan fails to fetch quotes of some securities under certain conditions, because this module extracts quotes from only a limited number of paginated search result pages though Yahoo! Finance JAPAN's stock price search service returns a lot of unrelated securities that partially match to a search query. Yahoo! tends to return too many unrelated securities when a search query contains a simple symbol (such as `1` and `T`) that does not look like an actual Japanese ticker symbol. If you cannot get a quote of a target security, please examine your search query and remove such simple symbols (if any). Also, appending market selector suffixes to stock codes, like making `1305` into `1305.t`, will be helpful in some cases.

# LICENSE

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

Quotations fetched through this module are bound by Yahoo!'s terms and conditions. See [http://finance.yahoo.co.jp/](http://finance.yahoo.co.jp/) for more details.

# AUTHOR

LiosK <contact@mail.liosk.net>
