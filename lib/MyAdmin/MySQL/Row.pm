package MyAdmin::MySQL::Row;
use strict;
use warnings;
use utf8;

use Moo;
use MooX::Types::MooseLike::Base qw(ArrayRef);

has columns => (
    is => 'ro',
    isa => ArrayRef,
    required => 1,
);

no Moo;

sub column {
    my ($self, $column) = @_;
    my ($col) = grep { $_->name eq $column } @{$self->columns};
    return $col;
}

sub where {
    my $self = shift;

    my %where;
    my %where_all;
    for my $column (@{$self->columns}) {
        $where_all{$column->name} = $column->value;

        next unless $column->is_primary_key;
        $where{$column->name} = $column->value;
    }

    # The table has PK.
    return \%where if %where;
    # no PK.
    return \%where_all;
}

1;

