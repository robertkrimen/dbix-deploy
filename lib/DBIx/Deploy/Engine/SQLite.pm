package DBIx::Deploy::Engine::SQLite;

use warnings;
use strict;

use Moose;
extends qw/DBIx::Deploy::Engine/;

use DBIx::Deploy::Connection::SQLite;

__PACKAGE__->configure({
    connection_class => "DBIx::Deploy::Connection::SQLite",
});

sub driver {
    return "SQLite";
}

sub _database_exists {
    my $self = shift;
    return 0 unless -f $self->connection->database;
    return -s _;
}

after teardown => sub {
    my $self = shift;
    my $connection = $self->connection;
    unlink $connection->database or warn $!;
};

after prepare_stash => sub {
    my $self = shift;

    my $stash = $self->stash;

    if (! $stash->{connection}->{user} && $stash->{database}) {
        $stash->{connection}->{user} = delete $stash->{database};
    }
};

1;
