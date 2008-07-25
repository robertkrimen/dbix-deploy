package DBIx::Deploy::Engine::SQLite;

use warnings;
use strict;

use Moose;
extends qw/DBIx::Deploy::Engine/;

use DBIx::Deploy::Connection::SQLite;

__PACKAGE__->configure({
    connection_class => "DBIx::Deploy::Connection::SQLite",
});

sub driver_hint {
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

after _prepare_configuration => sub {
    my $self = shift;

    my $configuration = $self->configuration;

    if (! $configuration->{connection}->{user} && $configuration->{database}) {
        $configuration->{connection}->{user} = delete $configuration->{database};
    }
};

1;
