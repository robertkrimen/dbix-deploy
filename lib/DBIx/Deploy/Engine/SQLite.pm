package DBIx::Deploy::Engine::SQLite;

use warnings;
use strict;

use Moose;
extends qw/DBIx::Deploy::Engine/;

use DBIx::Deploy::Connection::SQLite;

has connection => qw/is ro required 1 lazy 1/, default => sub {
    my $self = shift;
    return DBIx::Deploy::Connection::SQLite->new($self, $self->{configure}->{connection});
};

sub driver {
    return "SQLite";
}

sub verify {
    my $self = shift;
}

after teardown => sub {
    my $self = shift;
    my $connection = $self->connection;
    unlink $connection->database or warn $!;
};

1;
