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

has mysql_type_name => (
    is => 'ro',
    isa => Str,
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
    return $self->mysql_type_name eq 'integer';
}

sub is_binary {
    my $self = shift;
    return $self->mysql_type_name =~ /\A(?:blob|longblob)\z/;
}

1;

