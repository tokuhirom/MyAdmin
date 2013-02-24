package MyAdmin::Accessor::LazyRO;
use strict;
use warnings FATAL => 'all';
use utf8;

sub import {
    my $class = shift;
    my $pkg = caller(0);

    no strict 'refs';

    while (@_) {
        my $name = shift @_;
        my $code = shift @_;
        *{"${pkg}::${name}"} = sub {
            if (not exists $_[0]->{$name}) {
                $_[0]->{$name} = $code->($_[0]);
            }
            return $_[0]->{$name};
        };
    }
}

1;

