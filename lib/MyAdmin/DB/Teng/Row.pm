package MyAdmin::DB::Teng::Row;
use strict;
use warnings;
use utf8;

use parent qw(Teng::Row);

use MyAdmin::DB::Teng::Column;
use Class::Accessor::Lite::Lazy (
    ro_lazy => [qw(where)],
);

# Note, Teng should provide 'table' or 'table_name' attribute?
sub get_column_objects {
    my $self = shift;
    my @objects;
    for my $column_name (@{$self->{table}->columns}) {
        push @objects, MyAdmin::DB::Teng::Column->new(
            row      => $self,
            name     => $column_name,
            sql_type => $self->{table}->get_sql_type($column_name),
            sql_type_name => $self->{table}->{sql_type_names}->{$column_name},
        );
    }
    return \@objects;
}

# same as _where_clause.
# But this function just return undef when there is no PK.
sub _build_where {
    my $self = shift;

    # XXX table and table_name are private thing.
    # I need to talking about this private variables to public.
    my $table      = $self->{table};
    my $table_name = $self->{table_name};
    unless ($table) {
        Carp::croak("Unknown table: $table_name");
    }

    # get target table pk
    my $pk = $table->primary_keys;
    unless ($pk) {
        return undef;
    }

    # multi primary keys
    if ( ref $pk eq 'ARRAY' ) {
        unless (@$pk) {
            return undef;
        }

        my %pks = map { $_ => 1 } @$pk;

        unless ( ( grep { exists $pks{ $_ } } @{$self->{select_columns}} ) == @$pk ) {
            return undef;
        }

        return +{ map { $_ => $self->get_column($_) } @$pk };
    } else {
        unless (grep { $pk eq $_ } @{$self->{select_columns}}) {
            return undef;
        }

        return +{ $pk => $self->get_column($pk) };
    }
}

1;

