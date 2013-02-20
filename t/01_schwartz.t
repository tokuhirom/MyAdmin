use strict;
use warnings;
use utf8;
use Test::More;
use Plack::Test;
use MyAdmin::TheSchwartz;
use Test::Requires qw(HTTP::Request::Common);

my $app = MyAdmin::TheSchwartz->to_app({ databases => [] });
test_psgi app => $app, client => sub {
    my $cb = shift;

    subtest 'top' => sub {
        my $req = GET 'http://example.com/';
        my $res = $cb->($req);
        is($res->code, 200);
        like($res->content, qr{State of});
    };
    subtest 'css' => sub {
        my $req = GET 'http://example.com/static/bootstrap/css/bootstrap.min.css';
        my $res = $cb->($req);
        is($res->code, 200) or diag $res->content;
    };
};


done_testing;

