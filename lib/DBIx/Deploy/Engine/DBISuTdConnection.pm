package DBIx::Deploy::Engine::DBISuTdConnection;

use warnings;
use strict;

use Moose;
extends qw/DBIx::Deploy::Engine/;

use DBIx::Deploy::Connection;

__PACKAGE__->configure({
    sutd_connection_class => "DBIx::Deploy::Connection",
});

has sutd_connection => qw/is ro required 1 lazy 1/, default => sub {
    my $self = shift;
    
    return $self->stash->{sutd_connection_class}->parse($self, $self->stash->{sutd_connection});
};

has connection => qw/is ro required 1 lazy 1/, default => sub {
    my $self = shift;
    return $self->stash->{connection_class}->parse($self, $self->stash->{connection});
};

after _generate_prepare_context => sub {
    my $self = shift;
    my $context = shift;

    $context->{sutd_connection} = $self->sutd_connection;
};

before setup => sub {
    my $self = shift;
    return $self->run_script("setup", $self->sutd_connection, @_);
};

after teardown => sub {
    my $self = shift;
    $self->connection->disconnect;
    return $self->run_script("teardown", $self->sutd_connection, @_);
};

1;