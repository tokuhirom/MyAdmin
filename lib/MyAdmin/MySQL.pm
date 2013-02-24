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

use MyAdmin::Accessor::LazyRO (
    dbh => sub {
        my $c = shift;
        my @config = @{$c->config->{database}};
        $config[3]->{mysql_enable_utf8} ||= 1;
        $config[3]->{ShowErrorStatement} ||= 1;
        $config[3]->{RaiseError} = 1;
        my $dbh = DBI->connect(
            @config
        ) or MyAdmin::Exception->throw($DBI::errstr);
        $dbh->{HandleError} = sub {
            MyAdmin::Exception->throw($_[0])
        };
        $dbh->do(q{SET SESSION sql_mode=STRICT_TRANS_TABLES;});
        $dbh;
    },
    inspector => sub {
        my $c = shift;
        DBIx::Inspector->new(dbh => $c->dbh);
    },
    db => sub {
        my $c = shift;
        MyAdmin::MySQL::DB->new(dbh => $c->dbh, sql_maker => $c->sql_maker);
    },
    sql_maker => sub {
        my $c = shift;
        SQL::Maker->new(driver => 'mysql');
    },
    column => sub {
        my $c = shift;
        my $column = $c->req->param('column') || die;
        _validate($column);
        $column;
    },
    column_values => sub {
        my $c = shift;
        my %columns;
        for my $key (grep /^col\./, $c->req->parameters->keys) {
            my $val = $c->req->param($key);
            (my $column = $key) =~ s!^col\.!!;
            $columns{$column} = $val;
        }
        return \%columns;
    },
    table => sub {
        my $c = shift;
        my $table = $c->req->param('table') || die;
        _validate($table);
        $table;
    },
    database => sub {
        my $c = shift;
        my $database = $c->req->param('database') || die;
        _validate($database);
        $database;
    },
    where => sub {
        my $c = shift;
        my $where = decode_json(scalar $c->req->param('where'));
        die "There is no where" unless %$where;

        # check this where clause just select one row.
        $c->use_db();
        my ($sql, @binds) = $c->sql_maker->select($c->table, [\'COUNT(*)'], $where);
        my ($cnt) = $c->dbh->selectrow_array($sql, {}, @binds);
        $cnt == 1 or MyAdmin::Exception->throw("Bad where: $cnt");

        # okay, it's valid.
        $where;
    },
);


sub _validate {
    my $stuff = shift;
    $stuff =~ /\A[A-Za-z0-9_]+\z/ or die "Invalid name: $stuff";
}

sub use_db {
    my $c = shift;

    $c->dbh->do(sprintf(qq{USE %s}, $c->dbh->quote_identifier($c->database)));
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
    my @tables = $c->inspector->tables;

    $c->render('database.tt' => {
        database => $c->database,
        tables => \@tables,
    });
};

get '/list' => sub {
    my $c = shift;
    $c->use_db();

    my $page = 0 + ( $c->req->param('page') || 1 );

    my $column_values = $c->column_values;
    my ($sql, @binds) = $c->sql_maker->select(
        $c->table,
        ['*'],
        +{
            map { $_ => $column_values->{$_} }
            grep { length($column_values->{$_}) > 0 }
            keys %$column_values
        }
    );
    my ($names, $rows, $pager) = $c->db->search_with_pager(
        $sql,
        [@binds],
        $page,
        10
    );

    my $table = $c->inspector->table($c->table);

    $c->render(
        'list.tt' => {
            database => $c->database,
            table => $c->table,

            columns  => [$table->columns->all],

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
    my ($row) = $c->db->single(
        $c->table,
        [$column],
        $c->where,
    ) or MyAdmin::Exception->throw('Bad where.');
    my $value = $row->column($column)->value;
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

get '/update' => sub {
    my ($c) = @_;

    $c->use_db();
    my ($row) = $c->db->single(
        $c->table,
        ['*'],
        $c->where,
    ) or MyAdmin::Exception->throw('Bad where.');
    return $c->render(
        'update.tt' => {
            database => $c->database,
            table => $c->table,

            row => $row,
        },
    );
};

post '/update' => sub {
    my $c = shift;
    $c->use_db();

    my %params;
    for my $key (grep /^col\./, $c->req->parameters->keys) {
        my $val = $c->req->param($key);
        (my $column = $key) =~ s!^col\.!!;

        my $inspector = DBIx::Inspector->new(dbh => $c->dbh);
        my $table = $inspector->table($c->table);
        $params{$column} = $val;
    }
    my ($sql, @binds) = $c->sql_maker->update($c->table, \%params, $c->where);
    $c->dbh->do($sql, {}, @binds);
    return $c->redirect($c->uri_for('/list', {database => $c->database, table => $c->table}));
};

get '/delete' => sub {
    my ($c) = @_;

    $c->use_db();
    my ($row) = $c->db->single(
        $c->table,
        ['*'],
        $c->where,
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

    $c->db->delete(
        $c->table,
        $c->where,
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
    * download data by csv

