package MyAdmin::MySQL;
use strict;
use warnings;
use utf8;

use MyAdmin::Base -base;
use Data::Page::NoTotalEntries;

use DBI;

sub dbh {
    my $c = shift;
    $c->{dbh} ||= do {
        my @config = @{$c->config->{database}};
        $config[3]->{mysql_enable_utf8} //= 1;
        DBI->connect(
            @config
        ) or die $DBI::errstr;
    };
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
    my $c = shift;
    $c->use_db();

    my $table            = $c->table;
    my $page             = 0 + ( $c->req->param('page') // 1 );
    my $entries_per_page = 0 + 10;
    my $offset           = ( $page - 1 ) * $entries_per_page;
    my $sth              = $c->dbh->prepare(qq{SELECT * FROM $table LIMIT ? OFFSET ?});
    $sth->execute($entries_per_page+1, $offset);
    my @names = @{$sth->{NAME}};
    my @right;
    my @type_names = @{$sth->{mysql_type_name}};
    for my $i (0..@names-1) {
        $right[$i] = $sth->{mysql_type_name}->[$i] eq 'integer';
    }
    my @rows;
    while (my @row = $sth->fetchrow_array()) {
        push @rows, \@row;
    }
    my $has_next = 0;
    if (@rows==$entries_per_page+1) {
        pop @rows;
        $has_next++;
    }
    my $pager = Data::Page::NoTotalEntries->new(
        has_next => $has_next,
        entries_per_page => $entries_per_page,
        current_page => $page,
    );
    $c->render(
        'mysql/list.tt' => {
            names => \@names,
            rows => \@rows,
            database => $c->database,
            table => $c->table,
            right => \@right,
            type_names => \@type_names,
            pager => $pager,
        },
    );
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

