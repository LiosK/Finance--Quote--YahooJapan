requires 'perl', '5.018';
requires 'Finance::Quote', '1.51';
requires 'HTML::TreeBuilder', '5.07';
requires 'URI::Escape', '5.10';

on 'test' => sub {
    requires 'Test::More';
};
