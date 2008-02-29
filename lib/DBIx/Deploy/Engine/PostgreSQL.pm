package DBIx::Deploy::Engine::PostgreSQL;

use warnings;
use strict;

use Moose;
extends qw/DBIx::Deploy::Engine/;

use DBIx::Deploy::Connection::DBI;

sub driver {
    return "Pg";
}

has sutd_connection => qw/is ro required 1 lazy 1/, default => sub {
    my $self = shift;
    return DBIx::Deploy::Connection::DBI->new($self, $self->{configure}->{sutd_connection});
};

has connection => qw/is ro required 1 lazy 1/, default => sub {
    my $self = shift;
    return DBIx::Deploy::Connection::DBI->new($self, $self->{configure}->{connection});
};

after _generate_prepare_context => sub {
    my $self = shift;
    my $context = shift;

    $context->{sutd_connection} = $self->sutd_connection;
};

sub setup {
    my $self = shift;
    return $self->run("setup", $self->sutd_connection, @_);
}

sub teardown {
    my $self = shift;
    return $self->run("teardown", $self->sutd_connection, @_);
}

1;
