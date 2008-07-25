package DBIx::Deploy::Connection::SQLite;

use strict;
use warnings;

use Moose;
use DBIx::Deploy::Carp;

extends qw/DBIx::Deploy::Connection/;

before connect => sub {
    my $self = shift;
    my $database = Path::Class::Dir->new($self->database);
    $database->parent->mkpath unless -d $database->parent;
};

sub database_exists {
    my $self = shift;
    return -f $self->database && -s _ ? 1 : 0;
}

sub parse {
    my $class = shift;

    my ($linkage, $attributes);
    if (ref $_[0] eq "ARRAY") {
        ($linkage, $attributes) = @{ $_[0] };
        shift;
    }
    elsif (ref $_[0] eq "HASH") {
        ($linkage, $attributes) = @{ $_[0] }{qw/database attributes/};
        shift;
    }
    elsif ($_[0]) {
        $linkage = shift;
    }
    else {
        croak "Don't know what to do";
    }

    my $engine = shift;
    my $name = shift;
    my $driver_hint = shift;

    return $class->SUPER::parse([ $linkage, undef, undef, $attributes ], $engine, $name, $driver_hint);
}

1;
