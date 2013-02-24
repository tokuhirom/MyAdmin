package Garua::Driver::mysql;
use strict;
use warnings;
use utf8;

use Garua::Column;
use Garua::Row;

use Moo;

extends 'Garua::Driver::Base';

no Moo;

sub databases {
    my $self = shift;

    my @databases = map { @$_ } @{
        $self->dbh->selectall_arrayref(q{SHOW DATABASES});
    };
    return @databases;
}

sub is_binary {
    my ($self, $sth, $i) = @_;
    return $sth->{mysql_type_name}->[$i] =~ /\A(?:blob|longblob)\z/ ? 1 : 0;
}

1;

