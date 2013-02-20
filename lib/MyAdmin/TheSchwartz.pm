package MyAdmin::TheSchwartz;
use strict;
use warnings;
use utf8;
use Amon2 3.72;
use parent qw(Amon2 Amon2::Web);
use DBI;
use Router::Simple::Sinatraish;
use Text::Xslate;
use Plack::App::File;

__PACKAGE__->make_local_context();

sub to_app {
    my ($class, $config) = @_;
    sub {
        local *MyAdmin::TheSchwartz::config = sub { $config };
        $class->handle_request(shift);
    };
}

my $view = Text::Xslate->new(
    syntax => 'TTerse',
    path => [File::Spec->catfile(__PACKAGE__->base_dir(), 'tmpl/')],
    function => {
        c => sub { __PACKAGE__->context },
    },
);
sub create_view { $view }

sub dispatch {
    my $c = shift;

    my $p = __PACKAGE__->router->match($c->req->env);
    if ($p) {
        $p->{code}->($c, $p);
    } else {
        $p->res_404();
    }
}

get '/' => sub {
    my $c = shift;

    my @results;
    for my $dbinfo (@{$c->config->{databases}}) {
        my $dbh = DBI->connect(@$dbinfo);
        my @rows = @{$dbh->selectall_arrayref(q{SELECT funcid, funcname FROM funcmap}, {Slice => {}})};
        my %funcid2cnt = map { @$_ } @{
            $dbh->selectall_arrayref(
                q{SELECT funcid, COUNT(*)
                FROM job
                GROUP BY funcid
                ORDER BY funcid}
            )
        };
        for (@rows) {
            $_->{count} = $funcid2cnt{ $_->{funcid} } || 0;
        }
        push @results, \@rows;
        $dbh->disconnect;
    }
    return $c->render(
        'schwartz/index.tt', {
            results => \@results
        }
    );
};

get '/static/*' => sub {
    my ($c, $p) = @_;
    my $app = Plack::App::File->new(root => 'static');
    my $env = {%{$c->req->env}};
    $env->{PATH_INFO} = '/' . $p->{splat}->[0];
    my $res = $app->($env);
    return $c->create_response(@$res);
};

1;
__END__

=head1 NAME

MyAdmin::TheSchwartz - Administration PSGI app for TheSchwartz

=head1 SYNOPSIS

    mount '/schwartz/' => MyAdmin::TheSchwartz->to_app(
        +{
            databases => [
                [
                    'dbi:mysql:...',
                    'root',
                ],
                ...
            ]
        }
    );

