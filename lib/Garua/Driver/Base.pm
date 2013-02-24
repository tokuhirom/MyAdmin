package Garua::Driver::Base;
use strict;
use warnings;
use utf8;

use Moo;

has dbh => (
    is => 'rw',
    required => 1,
);

has sql_maker => (
    is => 'ro',
    required => 1,
    lazy => 1,
    default => sub {
        my $self = shift;
        SQL::Maker->new(driver => $self->dbh->{Driver}->{Name});
    },
);

no Moo;

sub databases {
    my ($self, ) = @_;
    die ref($self) . " does not support 'databases' method";
}

sub count {
    my ($self, $table, $select, $where) = @_;
    my ($sql, @binds) = $self->sql_maker->select($table, $select, $where);
    my ($cnt) = $self->dbh->selectrow_array($sql, {}, @binds);
    return $cnt;
}

sub make_rows_from_sth {
    my ($self, $sth) = @_;

    my @rows;
    while (my @row = $sth->fetchrow_array()) {
        my @columns;
        for (my $i=0; $i<@row; $i++) {
            my $column = Garua::Column->new(
                value           => $row[$i],
                type            => $sth->{TYPE}->[$i],
                is_primary_key  => $sth->{mysql_is_pri_key}->[$i],
                is_binary       => $self->is_binary($sth, $i),
                name            => $sth->{NAME}->[$i],
            );
            push @columns, $column;
        }
        push @rows, Garua::Row->new(
            columns => \@columns,
        );
    }
    return @rows;
}

sub is_binary {
    my ($self, $sth, $i) = @_;
    return 0;
}

sub insert {
    my ($self, $table, $params) = @_;
    my ($sql, @binds) = $self->sql_maker->insert($table, $params);
    $self->dbh->do($sql, {}, @binds);
}

sub search_with_pager {
    my ($self, $table, $columns, $where, $page, $entries_per_page) = @_;

    my ($sql, @binds) = $self->sql_maker->select(
        $table,
        $columns,
        $where
    );
    my ($names, $rows, $pager) = $self->search_by_sql_with_pager(
        $sql,
        [@binds],
        $page,
        10
    );
    return ($names, $rows, $pager);
}

sub search_by_sql_with_pager {
    my ($self, $sql, $binds, $page, $entries_per_page) = @_;

    my $offset           = ( $page - 1 ) * $entries_per_page;

    my $sth = $self->dbh->prepare($sql . q{ LIMIT ? OFFSET ?});
    $sth->execute(@$binds, $entries_per_page+1, $offset);

    my @names = @{$sth->{NAME}};

    my @rows = $self->make_rows_from_sth($sth);

    my $has_next = 0;
    if (@rows==$entries_per_page+1) {
        pop @rows;
        $has_next++;
    }
    my $pager = Data::Page::NoTotalEntries->new(
        has_next         => $has_next,
        entries_per_page => $entries_per_page,
        current_page     => $page,
    );

    return (\@names, \@rows, $pager);
}

sub single {
    my ($self, $table, $columns, $where) = @_;

    die "Bad where" unless %$where;

    my ($sql, @binds) = $self->sql_maker->select(
        $table,
        $columns,
        $where
    );
    my $sth = $self->dbh->prepare(
        $sql
    );
    $sth->execute(@binds);
    my @rows = $self->make_rows_from_sth($sth);
    die "Bad where($sql) : " . (0+@rows) if @rows > 1;
    return @rows;
}

sub schema {
    my ($self, $table) = @_;
    my ($schema) = map { $_->[1] } @{
        $self->dbh->selectall_arrayref(
            sprintf(qq{SHOW CREATE TABLE %s}, $self->dbh->quote_identifier($table)),
        );
    };
    return $schema;
}

sub update {
    my ($self, $table, $set, $where) = @_;

    my ($sql, @binds) = $self->sql_maker->update(
        $table,
        $set,
        $where
    );
    $self->dbh->do($sql, {}, @binds);
}

sub delete {
    my ($self, $table, $where) = @_;

    die "Bad where" unless %$where;

    my ($sql, @binds) = $self->sql_maker->delete(
        $table,
        $where
    );
    my $sth = $self->dbh->prepare(
        $sql
    );
    $sth->execute(@binds);
}

1;

