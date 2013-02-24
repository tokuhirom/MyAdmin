package Garua;
use strict;
use warnings;
use utf8;
use Carp;
use Class::Load;

sub new {
    my $class = shift;
    my %args = @_==1 ? %{$_[0]} : @_;
    my $dbh = $args{dbh} || Carp::croak("Missing mandatory parameter: 'dbh'");
    my $klass = 'Garua::Driver::' . $dbh->{Driver}->{Name};
    Class::Load::load_class($klass);
    return $klass->new(%args);
}

1;

