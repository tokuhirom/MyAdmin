package MyAdmin::MySQL::DB;
use strict;
use warnings;
use utf8;

use MyAdmin::MySQL::Column;
use MyAdmin::MySQL::Row;

use Moo;

has dbh => (
    is => 'rw',
    required => 1,
);

has sql_maker => (
    is => 'ro',
    required => 1,
);

no Moo;

sub make_rows_from_sth {
    my ($self, $sth) = @_;

    my @rows;
    while (my @row = $sth->fetchrow_array()) {
        my @columns;
        for (my $i=0; $i<@row; $i++) {
            my $column = MyAdmin::MySQL::Column->new(
                value           => $row[$i],
                mysql_type_name => $sth->{mysql_type_name}->[$i],
                is_primary_key  => $sth->{mysql_is_pri_key}->[$i],
                name            => $sth->{NAME}->[$i],
            );
            push @columns, $column;
        }
        push @rows, MyAdmin::MySQL::Row->new(
            columns => \@columns,
        );
    }
    return @rows;
}

sub search_with_pager {
    my ($self, $sql, $binds, $page, $entries_per_page) = @_;

    my $offset           = ( $page - 1 ) * $entries_per_page;

    my $sth = $self->dbh->prepare($sql . q{ LIMIT ? OFFSET ?});
    $sth->execute(@$binds, $entries_per_page+1, $offset)
        or MyAdmin::Exception->throw($self->dbh->errstr);

    my @names = @{$sth->{NAME}};

    my @rows = $self->make_rows_from_sth($sth);

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
    $sth->execute(@binds) or MyAdmin::Exception->throw($self->dbh->errstr);
    my @rows = $self->make_rows_from_sth($sth);
    die "Bad where($sql) : " . (0+@rows) if @rows > 1;
    return @rows;
}

sub delete_row {
    my ($self, $table, $where) = @_;

    die "Bad where" unless %$where;

    my ($sql, @binds) = $self->sql_maker->delete(
        $table,
        $where
    );
    my $sth = $self->dbh->prepare(
        $sql
    );
    $sth->execute(@binds) or MyAdmin::Exception->throw($self->dbh->errstr);
}

1;

