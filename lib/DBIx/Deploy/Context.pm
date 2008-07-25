package DBIx::Deploy::Context;

use warnings;
use strict;

use Moose;
use DBIx::Deploy::Carp;

has stash => qw/is ro required 1 isa HashRef/;

for my $name (qw/stage engine step command/) {
    __PACKAGE__->meta->add_method($name => sub {
        my $self = shift;
        return $self->stash->{$name};
    });
}

sub arguments {
    my $self = shift;
    return $self->command->arguments;
}

sub connection {
    my $self = shift;

    my $connection = $self->step->connection;
    $connection = $self->stash->{default_connection} if $connection eq "default";
    return $self->engine->connection($connection);
}

1;
