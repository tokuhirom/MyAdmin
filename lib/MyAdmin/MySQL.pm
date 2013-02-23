package MyAdmin::MySQL;
use strict;
use warnings;
use utf8;

use Data::Page::NoTotalEntries;

use DBI;
use DBIx::Inspector;
use SQL::Maker;
use MyAdmin::Exception;
use MyAdmin::MySQL::DB;
use JSON 2 qw(decode_json);

use MyAdmin::Base -base => (
    -xslate => {
        tmpl_dirname => 'mysql',
        module => ['JSON' => ['encode_json']],
    }
);

__PACKAGE__->add_trigger(
    BEFORE_DISPATCH => sub {
        my $c = shift;
        if ($c->config->{read_only} && $c->request->method ne 'GET') {
            return $c->render(
                'error.tt', {
                    message => 'This MyAdmin::MySQL instance run on read only mode.'
                }
            );
        }
    },
);

sub dbh {
    my $c = shift;
    $c->{dbh} ||= do {
        my @config = @{$c->config->{database}};
        $config[3]->{mysql_enable_utf8} //= 1;
        $config[3]->{ShowErrorStatement} //= 1;
        $config[3]->{RaiseError} = 1;
        my $dbh = DBI->connect(
            @config
        ) or MyAdmin::Exception->throw($DBI::errstr);
        $dbh->{HandleError} = sub {
            MyAdmin::Exception->throw($_[0])
        };
        $dbh->do(q{SET SESSION sql_mode=STRICT_TRANS_TABLES;});
        $dbh;
    };
}

sub db {
    my $c = shift;
    $c->{db}||= MyAdmin::MySQL::DB->new(dbh => $c->dbh, sql_maker => $c->sql_maker);
}

sub sql_maker {
    my $c = shift;
    SQL::Maker->new(driver => 'mysql');
}

sub _validate {
    my $stuff = shift;
    $stuff =~ /\A[A-Za-z0-9_]+\z/ or die "Invalid name: $stuff";
}

sub column {
    my $c = shift;
    my $column = $c->req->param('column') // die;
    _validate($column);
    $column;
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

    $c->render('index.tt' => {
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

    $c->render('database.tt' => {
        database => $c->database,
        tables => \@tables,
    });
};

get '/list' => sub {
    my $c = shift;
    $c->use_db();

    my $table = $c->table;
    my $page = 0 + ( $c->req->param('page') // 1 );

    my ($names, $rows, $pager) = $c->db->search_with_pager(
        sprintf(qq{SELECT * FROM %s}, $c->table),
        [],
        $page,
        10
    );

    $c->render(
        'list.tt' => {
            database => $c->database,
            table => $c->table,

            names => $names,
            rows => $rows,
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

    $c->render('schema.tt' => {
        database => scalar($c->req->param('database')),
        table => $table,
        schema => $schema,
    });
};

get '/insert' => sub {
    my $c = shift;
    $c->use_db();
    my $inspector = DBIx::Inspector->new(dbh => $c->dbh);
    my $table = $inspector->table($c->table);
    $c->render('insert.tt' => {
        database => $c->database,
        table    => $c->table,
        columns  => [$table->columns->all],
    });
};

post '/insert' => sub {
    my $c = shift;
    $c->use_db();

    my %params;
    for my $key (grep /^col\./, $c->req->parameters->keys) {
        my $val = $c->req->param($key);
        (my $column = $key) =~ s!^col\.!!;

        my $inspector = DBIx::Inspector->new(dbh => $c->dbh);
        my $table = $inspector->table($c->table);
        my $column_info = $table->column($column) or die "Unknown column: $column";
        if ($column_info->get('MYSQL_IS_AUTO_INCREMENT') && $val eq '') {
            # It's optional.
            next;
        }
        $params{$column} = $val;
    }
    my ($sql, @binds) = $c->sql_maker->insert($c->table, \%params);
    $c->dbh->do($sql, {}, @binds)
        or MyAdmin::Exception->throw($c->dbh->errstr);
    return $c->redirect($c->uri_for('/list', {database => $c->database, table => $c->table}));
};

get '/download_column' => sub {
    my ($c) = @_;

    my $column = $c->column;
    $c->use_db();
    my $where = decode_json(scalar $c->req->param('where'));
    die "There is no where" unless %$where;
    my ($sql, @binds) = $c->sql_maker->select(
        $c->table,
        [$column],
        $where
    );
    my ($value) = $c->dbh->selectrow_array(
        $sql, {}, @binds
    );
    return $c->create_response(
        200,
        [
            'Content-Type' => 'application/octet-stream',
            'Content-Disposition' => "attachment; filename='$column'",
            'Content-Length' => length($value),
        ],
        [$value],
    );
};

get '/delete' => sub {
    my ($c) = @_;

    $c->use_db();
    my $where = decode_json(scalar $c->req->param('where'));
    die "There is no where" unless %$where;

    my ($row) = $c->db->single(
        $c->table,
        ['*'],
        $where,
    ) or MyAdmin::Exception->throw('Bad where.');
    return $c->render(
        'delete.tt' => {
            database => $c->database,
            table => $c->table,

            row => $row,
        },
    );
};

post '/delete' => sub {
    my ($c) = @_;

    $c->use_db();
    my $where = decode_json(scalar $c->req->param('where'));
    die "There is no where" unless %$where;

    $c->db->delete(
        $c->table,
        $where,
    ) or MyAdmin::Exception->throw('Bad where.');
    return $c->redirect(
        $c->uri_for('/list', {
            database => $c->database,
            table => $c->table,
        })
    );
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

=head1 TODO

    * csrf defender
    * list long blobs
    * download longblob
    * download csv


