package DBIx::Deploy::Engine::SQLite;

use warnings;
use strict;

use Moose;
extends qw/DBIx::Deploy::Engine/;

use DBIx::Deploy::Connection::SQLite;

sub driver {
    return "SQLite";
}

has connection => qw/is ro required 1 lazy 1/, default => sub {
    my $self = shift;
    return DBIx::Deploy::Connection::SQLite->new($self, $self->{configure}->{connection});
};

1;
