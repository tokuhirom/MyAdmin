package MyAdmin::Base;
use strict;
use warnings;
use utf8;
use Amon2 3.72;
use Amon2::Web;
use Router::Simple::Sinatraish ();
use Plack::App::File;
use Text::Xslate;
use Try::Lite;
use File::ShareDir;

sub import {
    my $class = shift;
    my $pkg = caller(0);

    return unless $_[0] eq '-base';
    shift @_;

    my %args = @_;

    no strict 'refs';
    unshift @{"${pkg}::ISA"}, 'Amon2';
    unshift @{"${pkg}::ISA"}, 'Amon2::Web';

    $pkg->make_local_context();

    Router::Simple::Sinatraish->export_to_level(1);

    $pkg->router->connect('/static/*', { code => \&_static }, {method => ['GET', 'HEAD']});

    *{"${pkg}::resource_dir"} = \&_resource_dir;

    my $view = $class->_init_xslate($pkg, $args{'-xslate'});
    *{"${pkg}::create_view"} = sub { $view };

    *{"${pkg}::dispatch"} = sub {
        my $c = shift;

        my $p = $pkg->router->match($c->req->env);
        if ($p) {
            try {
                $p->{code}->($c, $p);
            }
                'MyAdmin::Exception' => sub {
                    my $e = $@;
                    $c->render(
                        'error.tt' => {
                            exception => $e,
                        }
                    );
                };
        } else {
            $c->res_404();
        }
    };

    *{"${pkg}::to_app"} = sub {
        my ($class, $config) = @_;
        unless ($config && ref $config eq 'HASH') {
            Carp::croak("Usage: ${pkg}->to_app(\\%config)");
        }
        sub {
            local *{"${pkg}::config"} = sub { $config };
            $class->handle_request(shift);
        };
    };
}

sub _resource_dir {
    my ($c) = @_;
    if (-d File::Spec->catdir($c->base_dir, 'tmpl')) {
        return $c->base_dir;
    } else {
        File::ShareDir::dist_dir('MyAdmin');
    }
}

sub _init_xslate {
    my $class = shift;
    my $pkg = shift;
    my %xslate_opts = %{ $_[0] || {} };
    my %xslate_args = (
        syntax => 'TTerse',
        module => [qw(Text::Xslate::Bridge::Star)],
        function => {
            c => sub { $pkg->context },
            uri_for => sub { $pkg->context->uri_for(@_) },
            uri_with => sub { $pkg->context->request->uri_with(@_) },
        },
    );
    if (my $tmpl_dirname = delete $xslate_opts{tmpl_dirname}) {
        unshift @{$xslate_args{path}}, File::Spec->catfile($pkg->resource_dir, 'tmpl/', $tmpl_dirname);
    }
    if (my $mods = delete $xslate_opts{module}) {
        push @{$xslate_args{module}}, @$mods;
    }
    if (my $function = delete $xslate_opts{function}) {
        push %{$xslate_args{function}}, %$function;
    }
    return Text::Xslate->new(%xslate_args);
}

sub _static {
    my ($c, $p) = @_;
    my $app = Plack::App::File->new(root => File::Spec->catdir($c->resource_dir(), 'static'));
    my $env = {%{$c->req->env}};
    $env->{PATH_INFO} = '/' . $p->{splat}->[0];
    my $res = $app->($env);
    return $c->create_response(@$res);
}

1;

