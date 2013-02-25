package MyAdmin::DB::Teng::Loader;
use strict;
use warnings;
use utf8;
use DBIx::Inspector 0.09;

sub load {
    my ($class, %args) = @_;
    my $dbh = $args{dbh} || die "Missing mandatory parameter: dbh";
    my $inspector = DBIx::Inspector->new(dbh => $dbh);
    my $schema = Teng::Schema->new(namespace => 'MyAdmin::DB::Teng');

    my $table = $args{table} || die "Missing mandatory parameter: table";
    for my $table_info ($inspector->tables_and_views($table)) {
        my $table_name = $table_info->name;
        my @table_pk   = map { $_->name } $table_info->primary_key;
        my @col_names;
        my %sql_types;
        my %sql_type_names;
        for my $col ( $table_info->columns ) {
            push @col_names, $col->name;
            $sql_types{ $col->name } = $col->data_type;
            $sql_type_names{ $col->name } = $col->type_name;
        }

        # We need to provide a patch to extend Teng::Schema::Table
        # to support sql_type_names?
        #
        # sql_type_names is required to detect longblob or not.
        $schema->add_table(
            Teng::Schema::Table->new(
                columns      => \@col_names,
                name         => $table_name,
                primary_keys => \@table_pk,
                sql_types    => \%sql_types,
                sql_type_names    => \%sql_type_names,
                inflators    => [],
                deflators    => [],
                row_class    => 'MyAdmin::DB::Teng::Row',
            )
        );
    }
    return $schema;
}

1;

