package MyAdmin::MySQL::Column;
use strict;
use warnings;
use utf8;

use Moo;
use MooX::Types::MooseLike::Base qw(Maybe Str Bool);

has name => (
    is => 'ro',
    isa => Str,
    required => 1,
);

has value => (
    is => 'ro',
    isa => Maybe[Str],
    required => 1,
);

has type => (
    is => 'ro',
    isa => Str,
    required => 1,
);

has is_binary => (
    is => 'ro',
    isa => Bool,
    required => 1,
);

has is_primary_key => (
    is => 'ro',
    isa => Bool,
    required => 1,
);

no Moo;

sub is_numeric {
    my $self = shift;
    return $self->type eq DBI::SQL_INTEGER() || $self->type eq DBI::SQL_DECIMAL;
}

1;

