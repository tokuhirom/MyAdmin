package MyAdmin::MySQL;
use strict;
use warnings;
use utf8;

use MyAdmin::Base -base;

use DBI;

sub dbh {
    my $c = shift;
    DBI->connect(
        @{$c->config->{database}}
    ) or die $DBI::errstr;
}

get '/' => sub {
    my $c = shift;

    my $dbh = $c->dbh;
    my @databases = map { @$_ } @{
        $dbh->selectall_arrayref(q{SHOW DATABASES});
    };

    $c->render('mysql/index.tt' => {
        databases => \@databases,
    });
};

get '/database' => sub {
    my $c = shift;

    my $database = $c->req->param('database') // die;
    $database =~ /\A[A-Za-z0-9_]+\z/ or die "Invalid database name: $database";

    my $dbh = $c->dbh;
    $dbh->do(qq{USE $database});
    my @tables = map { @$_ } @{
        $dbh->selectall_arrayref(q{SHOW TABLES});
    };

    $c->render('mysql/database.tt' => {
        database => $database,
        tables => \@tables,
    });
};

get '/table' => sub {
    ... # yes. it's not implemented yet.
};


1;
__END__

=head1 SYNOPSIS

    mount '/schwartz/' => MyAdmin::MySQL->to_app(
        +{
            database => [
                'dbi:mysql:...',
                'root',
            ]
        }
    );

