requires 'perl', '5.008005';

requires 'Amon2', '3.72';
requires 'Amon2::Web';
requires 'Class::Accessor::Lite::Lazy';
requires 'DBI';
requires 'DBIx::Inspector', '0.09';
requires 'Data::Page::NoTotalEntries';
requires 'Exception::Tiny';
requires 'File::ShareDir';
requires 'Getopt::Long';
requires 'JSON', '2';
requires 'Plack::App::File';
requires 'Plack::Builder';
requires 'Plack::Loader';
requires 'Pod::Usage';
requires 'Router::Simple::Sinatraish';
requires 'SQL::Maker';
requires 'Teng';
requires 'Teng::Row';
requires 'Teng::Schema::Table';
requires 'Text::Xslate';
requires 'Try::Lite';
requires 'parent';

on test => sub {
    requires 'Plack::Test';
    requires 'Test::More', 0.98;
    requires 'Test::Requires';
};
