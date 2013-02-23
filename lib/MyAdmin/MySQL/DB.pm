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

no Moo;

sub search_with_pager {
    my ($self, $sql, $binds, $page, $entries_per_page) = @_;

    my $offset           = ( $page - 1 ) * $entries_per_page;

    my $sth = $self->dbh->prepare($sql . q{ LIMIT ? OFFSET ?});
    $sth->execute(@$binds, $entries_per_page+1, $offset)
        or MyAdmin::Exception->throw($self->dbh->errstr);

    my @names = @{$sth->{NAME}};

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

1;

