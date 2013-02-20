package MyAdmin::Base;
use strict;
use warnings;
use utf8;
use Amon2 3.72;
use Amon2::Web;
use Router::Simple::Sinatraish ();
use Plack::App::File;
use Text::Xslate;

sub import {
    my $pkg = caller(0);

    return unless $_[1] eq '-base';

    no strict 'refs';
    unshift @{"${pkg}::ISA"}, 'Amon2';
    unshift @{"${pkg}::ISA"}, 'Amon2::Web';

    $pkg->make_local_context();

    Router::Simple::Sinatraish->export_to_level(1);

    $pkg->router->connect('/static/*', { code => \&_static }, {method => ['GET', 'HEAD']});

    my $view = Text::Xslate->new(
        syntax => 'TTerse',
        path => [File::Spec->catfile($pkg->base_dir(), 'tmpl/')],
        module => [qw(Text::Xslate::Bridge::Star)],
        function => {
            c => sub { $pkg->context },
        },
    );
    *{"${pkg}::create_view"} = sub { $view };

    *{"${pkg}::dispatch"} = sub {
        my $c = shift;

        my $p = $pkg->router->match($c->req->env);
        if ($p) {
            $p->{code}->($c, $p);
        } else {
            $c->res_404();
        }
    };

    *{"${pkg}::to_app"} = sub {
        my ($class, $config) = @_;
        sub {
            local *{"${pkg}::config"} = sub { $config };
            $class->handle_request(shift);
        };
    };
}

sub _static {
    my ($c, $p) = @_;
    my $app = Plack::App::File->new(root => 'static');
    my $env = {%{$c->req->env}};
    $env->{PATH_INFO} = '/' . $p->{splat}->[0];
    my $res = $app->($env);
    return $c->create_response(@$res);
}

1;

