requires 'Amon2' => 3.27;
requires 'Text::Xslate' => 2;
requires 'Exporter'                      => '0';
requires 'parent'                        => '0';
requires 'Plack'                         => '0.9949';
requires 'Data::Page::NoTotalEntries'    => 0;
requires 'Exception::Tiny'               => 0;
requires 'Try::Lite' => '0.0.2';
requires 'File::ShareDir' => 0;
requires 'SQL::Maker' => 0;
requires 'MooX::Types::MooseLike' => 0;
requires Moo => 0;
requires 'DBIx::Inspector' => 0.09;
requires 'JSON' => 2;
requires 'CPAN';
requires 'DBD::mysql';
requires 'Class::Load';

on test => sub {
    requires 'Test::More' => 0.98;
};
