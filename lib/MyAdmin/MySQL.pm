package MyAdmin::MySQL;
use strict;
use warnings;
use utf8;

use MyAdmin::Base -base;

use DBI;

sub dbh {
    my $c = shift;
    $c->{dbh} ||= DBI->connect(
        @{$c->config->{database}}
    ) or die $DBI::errstr;
}

sub _validate {
    my $stuff = shift;
    $stuff =~ /\A[A-Za-z0-9_]+\z/ or die "Invalid name: $stuff";
}

sub table {
    my $c = shift;
    my $table = $c->req->param('table') // die;
    _validate($table);
    $table;
}

sub database {
    my $c = shift;
    my $database = $c->req->param('database') // die;
    _validate($database);
    $database;
}

sub use_db {
    my $c = shift;

    my $database = $c->database;
    $c->dbh->do(qq{USE $database});
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

    my $dbh = $c->dbh;
    $c->use_db();
    my @tables = map { @$_ } @{
        $c->dbh->selectall_arrayref(q{SHOW TABLES});
    };

    $c->render('mysql/database.tt' => {
        database => $c->database,
        tables => \@tables,
    });
};

get '/list' => sub {
    ... # yes. it's not implemented yet.
};

get '/schema' => sub {
    my $c = shift;

    $c->use_db();

    my $table = $c->table;
    my ($schema) = map { $_->[1] } @{
        $c->dbh->selectall_arrayref(qq{SHOW CREATE TABLE $table});
    };

    $c->render('mysql/schema.tt' => {
        database => scalar($c->req->param('database')),
        table => $table,
        schema => $schema,
    });
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

