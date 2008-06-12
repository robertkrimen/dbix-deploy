package DBIx::Deploy::Connection::SQLite;

use strict;
use warnings;

use Moose;
use Carp::Clan;

extends qw/DBIx::Deploy::Connection/;

before connect => sub {
    my $self = shift;
    my $database = $self->database;
    $database->parent->mkpath unless -d $database->parent;
};

sub database_exists {
    my $self = shift;
    return -f $self->database && -s _ ? 1 : 0;
}

sub parse {
    my $class = shift;
    my $name = shift;
    my $engine = shift;

    my ($database, $attributes);
    if (ref $_[0] eq "ARRAY") {
        ($database, $attributes) = @{ $_[0] };
        shift;
    }
    elsif (ref $_[0] eq "HASH") {
        ($database, $attributes) = @{ $_[0] }{qw/database attributes/};
        shift;
    }
    elsif ($_[0]) {
        $database = shift;
    }
    else {
        croak "Don't know what to do";
    }

    return $class->SUPER::parse($name => $engine, [ $database, undef, undef, $attributes ]);
}

1;
