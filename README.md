# NAME

Finance::Quote::YahooJapan - A Perl module that enables GnuCash to get quotes of Japanese stocks and mutual funds from Yahoo! Finance JAPAN.

# SYNOPSIS

    use Finance::Quote;
    my $q = Finance::Quote->new('-defaults', 'YahooJapan');
    my %quotes = $q->fetch('yahoo_japan', '6758', '6861', '7203');

# DESCRIPTION

Finance::Quote::YahooJapan is a submodule of Finance::Quote, and adds support for Japanese stock and mutual fund quotes. This module extracts these quotes from the result pages of Yahoo! Finance JAPAN's stock price search service. Thus this module enables GnuCash to obtain Japanese quotes through its online price update feature.

# SETUP

## 1. Install Finance::Quote

Install and setup Finance::Quote module as explained in the GnuCash Help Manual: [https://code.gnucash.org/docs/C/gnucash-help/acct-create.html#accts-online-quotes](https://code.gnucash.org/docs/C/gnucash-help/acct-create.html#accts-online-quotes)

## 2. Install Finance::Quote::YahooJapan

a. Type `cpanm https://github.com/LiosK/Finance--Quote--YahooJapan.git` in the terminal. Or, if you don't prefer to use `cpanm`, locate the directory where `Finance::Quote::*` are installed, and then put `lib/Finance/Quote/YahooJapan.pm` in the directory.

b. Set the `FQ_LOAD_QUOTELET` environment variable to `-defaults YahooJapan` in order to load Finance::Quote::YahooJapan.

## 3. Setup GnuCash Online Quote Feature

Launch GnuCash and setup your securities as explained in the Manual: [https://code.gnucash.org/docs/C/gnucash-help/acct-create.html#accts-online-quotes](https://code.gnucash.org/docs/C/gnucash-help/acct-create.html#accts-online-quotes)

# LICENSE

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

Quotations fetched through this module are bound by Yahoo!'s terms and conditions. See [https://finance.yahoo.co.jp/](https://finance.yahoo.co.jp/) for more details.

# AUTHOR

LiosK <contact@mail.liosk.net>

# SEE ALSO

Finance::Quote
