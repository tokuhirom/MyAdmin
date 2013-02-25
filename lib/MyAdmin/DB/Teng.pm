package MyAdmin::DB::Teng;
use strict;
use warnings;
use utf8;

use parent qw(Teng);

__PACKAGE__->load_plugin(qw(Pager));
__PACKAGE__->load_plugin(qw(Count));

sub databases {
    my $self = shift;

    my $driver = $self->dbh->{Driver}->{Name};
    if ($driver eq 'mysql') {
        my @databases = map { @$_ } @{
            $self->dbh->selectall_arrayref(q{SHOW DATABASES});
        };
        return @databases;
    } elsif ($driver eq 'SQLite') {
        return 'main';
    } else {
        die "This method is not supported for $driver";
    }
}

sub get_schema_sql {
    my ($self, $table) = @_;
    defined($table) or die;

    # TODO I should move this feature to DBIx::Inspector.
    my $driver = $self->dbh->{Driver}->{Name};
    if ($driver eq 'mysql') {
        # XXX This is not portable, too.
        my ($schema) = map { $_->[1] } @{
            $self->dbh->selectall_arrayref(
                sprintf(qq{SHOW CREATE TABLE %s}, $self->dbh->quote_identifier($table)),
            );
        };
        return $schema;
    } elsif ($driver eq 'SQLite') {
        my ($schema) = $self->dbh->selectrow_array(
            q{SELECT sql FROM sqlite_master WHERE name=?},
            {},
            $table,
        );
        return $schema;
    } else {
        die "This method is not supported for $driver";
    }
}

1;

