use strict;
use warnings;
use Module::Build;
use File::Copy::Recursive;

my $build = Module::Build->new(
    license              => 'perl',
    dynamic_config       => 0,

    build_requires       => {
        'Test::More' => '0.98',
        'Test::Requires' => 0,
    },
    configure_requires   => {
        'Module::Build' => '0.38',
        'File::Copy::Recursive' => 0,
    },
    requires             => {
        perl => '5.008005',
        'Amon2' => 3.27,
        'Text::Xslate' => 2,
        'Exporter'                      => '0',
        'parent'                        => '0',
        'Plack'                         => '0.9949',
        'Data::Page::NoTotalEntries'    => 0,
        'Exception::Tiny'               => 0,
        'Try::Lite' => '0.0.2',
        'File::ShareDir' => 0,
        'SQL::Maker' => 0,
        'MooX::Types::MooseLike' => 0,
        Moo => 0,
    },

    no_index    => { 'directory' => [ 'inc' ] },
    name        => 'MyAdmin',
    module_name => 'MyAdmin',

    script_files => ['bin/myadmin-mysql.pl'],

    test_files => (-d '.git' || $ENV{RELEASE_TESTING}) ? 't/ xt/' : 't/',
    recursive_test_files => 1,

    share_dir => {
        dist => ['_share'],
    },
   
    create_readme  => 1,
    create_license => 1,
);
{
    mkdir '_share' unless -d '_share';
    File::Copy::Recursive::rcopy('tmpl', '_share/tmpl');
    File::Copy::Recursive::rcopy('static', '_share/static');
}
$build->create_build_script();
