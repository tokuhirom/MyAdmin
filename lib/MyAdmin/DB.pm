package MyAdmin::DB;
use strict;
use warnings;
use utf8;

use Data::Page::NoTotalEntries;

use DBI;
use DBIx::Inspector;
use SQL::Maker;
use MyAdmin::Exception;
use JSON 2 qw(decode_json);
use MyAdmin::DB::Teng;
use MyAdmin::DB::Teng::Loader;
use Teng::Schema::Table;

__PACKAGE__->load_plugin('Web::CSRFDefender' => {
    post_only => 1,
});

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
                    exception => MyAdmin::Exception->new(message => 'This MyAdmin::DB instance run on read only mode.')
                }
            );
        }
    },
);

__PACKAGE__->add_trigger(
    BEFORE_DISPATCH => sub {
        my $self = shift;
        if ($self->req->param('database')) {
            $self->use_db($self->database);
        }
    },
);

sub _build_teng {
    my $c = shift;

    my $schema =
        scalar($c->req->param('table'))
        ? MyAdmin::DB::Teng::Loader->load(dbh => $c->dbh, table => $c->table)
        : Teng::Schema->new(namespace => 'MyAdmin::DB::Teng');

    MyAdmin::DB::Teng->new(
        dbh => $c->dbh,
        schema => $schema,
        fields_case => 'NAME',
    );
}

sub _build_dbh {
    my $c = shift;
    my @config = @{$c->config->{database}};
    $config[3]->{mysql_enable_utf8} ||= 1;
    $config[3]->{ShowErrorStatement} ||= 1;
    $config[3]->{RaiseError} = 1;
    my $dbh = DBI->connect(
        @config
    ) or MyAdmin::Exception->throw($DBI::errstr);
    $dbh->{HandleError} = sub {
        use Carp; Carp::cluck($_[0]);
        MyAdmin::Exception->throw($_[0])
    };
    if ($dbh->{Driver}->{Name} eq 'mysql') {
        $dbh->do(q{SET SESSION sql_mode=STRICT_TRANS_TABLES;});
    }
    $dbh;
}

use Class::Accessor::Lite::Lazy (
    ro_lazy => [qw(dbh teng inspector column column_values where database table)],
);

sub _build_inspector {
    my $c = shift;
    DBIx::Inspector->new(dbh => $c->dbh);
}

sub _build_column {
    my $c = shift;
    my $column = $c->req->param('column') || die;
    _validate($column);
    $column;
}

sub _build_column_values {
    my $c = shift;
    my %columns;
    for my $key (grep /^col\./, $c->req->parameters->keys) {
        my $val = $c->req->param($key);
        (my $column = $key) =~ s!^col\.!!;
        $columns{$column} = $val;
    }
    return \%columns;
}

sub _build_table {
    my $c = shift;
    my $table = $c->req->param('table') || die;
    _validate($table);
    $table;
}

sub _build_database {
    my $c = shift;
    my $database = $c->req->param('database') || die;
    _validate($database);
    $database;
}

sub _build_where {
    my $c = shift;
    my $where = decode_json(scalar $c->req->param('where'));
    die "There is no where" unless %$where;

    # check this where clause just select one row.
    $c->use_db();
    my $cnt = $c->teng->count($c->table, '*', $where);
    $cnt == 1 or MyAdmin::Exception->throw("Bad where: $cnt");

    # okay, it's valid.
    $where;
}


sub _validate {
    my $stuff = shift;
    $stuff =~ /\A[A-Za-z0-9_]+\z/ or die "Invalid name: $stuff";
}

sub use_db {
    my $c = shift;

    my $driver = $c->dbh->{Driver}->{Name};
    if ($driver eq 'mysql') {
        $c->dbh->do(sprintf(qq{USE %s}, $c->dbh->quote_identifier($c->database)));
    } elsif ($driver eq 'SQLite') {
        # nop
    } else {
        die "This method is not supported for $driver";
    }
}

get '/' => sub {
    my $c = shift;

    $c->render('index.tt' => {
        databases => [$c->teng->databases],
    });
};

get '/database' => sub {
    my $c = shift;

    my @tables = $c->inspector->tables_and_views(undef);

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
    my ($rows, $pager) = $c->teng->search_with_pager(
        $c->table,
        +{
            map { $_ => $column_values->{$_} }
            grep { length($column_values->{$_}) > 0 }
            keys %$column_values
        },
        {
            page => $page,
            rows => 10,
        }
    );

    my $table = $c->inspector->table_or_view($c->table);

    $c->render(
        'list.tt' => {
            database => $c->database,
            table => $c->table,

            columns  => [$table->columns->all],

            names => $c->teng->schema->get_table($c->table)->columns,
            rows => $rows,
            pager => $pager,
        },
    );
};

get '/schema' => sub {
    my $c = shift;

    my $schema = $c->teng->get_schema_sql($c->table);

    $c->render('schema.tt' => {
        database => $c->database,
        table    => $c->table,

        schema   => $schema,
    });
};

get '/insert' => sub {
    my $c = shift;

    my $table = $c->inspector->table($c->table);
    $c->render('insert.tt' => {
        database => $c->database,
        table    => $c->table,
        columns  => [$table->columns->all],
    });
};

post '/insert' => sub {
    my $c = shift;
    $c->use_db();

    my $table = $c->inspector->table($c->table);

    my $column_values = $c->column_values;

    my %params;
    while (my ($column, $val) = each %$column_values) {
        my $column_info = $table->column($column) or die "Unknown column: $column";
        if ($column_info->get('MYSQL_IS_AUTO_INCREMENT') && $val eq '') {
            # It's optional.
            next;
        }
        $params{$column} = $val;
    }
    $c->teng->insert($c->table, \%params);

    return $c->redirect(
        $c->uri_for( '/list', {
            database => $c->database,
            table => $c->table
        } )
    );
};

get '/download_column' => sub {
    my ($c) = @_;

    my $column = $c->column;
    my ($row) = $c->teng->single(
        $c->table,
        $c->where,
        { columns => [$c->column] }
    ) or MyAdmin::Exception->throw('Bad where.');
    my $value = $row->get_column($c->column);

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

    my ($row) = $c->teng->single(
        $c->table,
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

    $c->teng->update(
        $c->table,
        $c->column_values,
        $c->where
    );
    return $c->redirect(
        $c->uri_for('/list', {
            database => $c->database,
            table => $c->table
        })
    );
};

get '/delete' => sub {
    my ($c) = @_;

    my ($row) = $c->teng->single(
        $c->table,
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

    $c->teng->delete(
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

=head1 NAME

MyAdmin::MySQL - MySQL admin site PSGI app

=head1 SYNOPSIS

    builder {
        mount '/mysql/' => MyAdmin::MySQL->to_app(
            +{
                database => [
                    'dbi:mysql:...',
                    'root',
                    'pa55word',
                ]
            }
        );
    };

=head1 DESCRIPTION

This is a admin site L<PSGI> app for management mysql.

=head1 TODO

    * download data by csv

