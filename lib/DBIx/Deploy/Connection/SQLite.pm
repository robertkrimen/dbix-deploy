package DBIx::Deploy::Connection::SQLite;

use strict;
use warnings;

use Moose;

extends qw/DBIx::Deploy::Connection/;

sub parse {
    my $class = shift;
    my $engine = shift;

    my ($database, $attributes);
    if (ref $_[0] eq "ARRAY") {
        ($database, $attributes) = @{ $_[0] };
    }
    elsif (ref $_[0] eq "HASH") {
        ($database, $attributes) = @{ $_[0] }{qw/database attributes/};
    }
    else {
        die;
    }

    return $class->SUPER::parse($engine => [ $database, undef, undef, $attributes) ]);
}

1;
