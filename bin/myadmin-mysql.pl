#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use 5.008005;

use MyAdmin::DB;
use Plack::Loader;
use Getopt::Long;
use Plack::Builder;

my $http_port = 5000;
GetOptions(
    'username=s' => \my $username,
    'password=s' => \my $password,
    'dbhost=s' => \my $dbhost,
    'dbport=i' => \my $dbport,
    'p|port=i' => \$http_port,
    'read_only' => \my $read_only,
);

my $dsn = 'dbi:mysql:';
if (defined $dbhost) {
    $dsn .= "host=$dbhost;";
}
if (defined $dbport) {
    $dsn .= "port=$dbport;";
}
my $app = builder {
    enable 'AccessLog';
    enable 'Session';

    MyAdmin::DB->to_app(
        {
            database => [
                $dsn,
                $username,
                $password,
            ],
            read_only => $read_only,
        }
    );
};
print "http://127.0.0.1:$http_port/\n";
Plack::Loader->auto(
    port => $http_port,
)->run($app);

