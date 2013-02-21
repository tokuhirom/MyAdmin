package MyAdmin::TheSchwartz;
use strict;
use warnings;
use utf8;
use DBI;

use MyAdmin::Base '-base' => (
    '-xslate' => {
        tmpl_dirname => 'schwartz',
    }
);

get '/' => sub {
    my $c = shift;

    my @results;
    for my $dbinfo (@{$c->config->{databases}}) {
        my $dbh = DBI->connect(@$dbinfo);
        my @rows = @{$dbh->selectall_arrayref(q{SELECT funcid, funcname FROM funcmap}, {Slice => {}})};
        my %funcid2cnt = map { @$_ } @{
            $dbh->selectall_arrayref(
                q{SELECT funcid, COUNT(*)
                FROM job
                GROUP BY funcid
                ORDER BY funcid}
            )
        };
        for (@rows) {
            $_->{count} = $funcid2cnt{ $_->{funcid} } || 0;
        }
        push @results, \@rows;
        $dbh->disconnect;
    }
    return $c->render(
        'index.tt', {
            results => \@results
        }
    );
};

1;
__END__

=head1 NAME

MyAdmin::TheSchwartz - Administration PSGI app for TheSchwartz

=head1 SYNOPSIS

    mount '/schwartz/' => MyAdmin::TheSchwartz->to_app(
        +{
            databases => [
                [
                    'dbi:mysql:...',
                    'root',
                ],
                ...
            ]
        }
    );

