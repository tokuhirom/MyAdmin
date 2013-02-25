#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use 5.008005;

use MyAdmin::DB;
use Plack::Loader;
use Getopt::Long;
use Plack::Builder;
use Pod::Usage;

my $http_port = 5000;
GetOptions(
    'p|port=i' => \$http_port,
    'read-only' => \my $read_only,
) or pod2usage();
my $dbname = shift or pod2usage();

my $dsn = "dbi:SQLite:dbname=$dbname";
my $app = builder {
    enable 'AccessLog';
    enable 'Session';

    MyAdmin::DB->to_app(
        {
            database => [
                $dsn,
            ],
            read_only => $read_only,
        }
    );
};
print "http://127.0.0.1:$http_port/\n";
Plack::Loader->auto(
    port => $http_port,
)->run($app);

__END__

=head1 SYNOPSIS

    % myadmin-sqlite.pl path/to/db

        --port=5000   HTTP server port number
        --read-only   Enable read only mode

