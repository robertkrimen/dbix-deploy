package DBIx::Deploy::Engine::SQLite;

use warnings;
use strict;

use Moose;
extends qw/DBIx::Deploy::Engine/;

use DBIx::Deploy::Connection::SQLite;

__PACKAGE__->configure({
    connection_class => "DBIx::Deploy::Connection::SQLite",
});

has connection => qw/is ro required 1 lazy 1/, default => sub {
    my $self = shift;
    return $self->stash->{connection_class}->parse($self, $self->stash->{connection});
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
