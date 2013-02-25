package MyAdmin::DB::Teng::Column;
use strict;
use warnings;
use utf8;

use Class::Accessor::Lite::Lazy (
    ro => [qw(row name sql_type sql_type_name)],
    new => 1,
);

sub value {
    my $self = shift;
    $self->row->get_column($self->name);
}

sub is_numeric {
    my $self = shift;
    return $self->sql_type eq DBI::SQL_INTEGER() || $self->sql_type eq DBI::SQL_DECIMAL;
}

sub is_binary {
    my $self = shift;
    return $self->sql_type_name eq 'LONGBLOB';
}

1;

