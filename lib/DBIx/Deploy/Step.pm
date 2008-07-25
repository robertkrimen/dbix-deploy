package DBIx::Deploy::Step;

use warnings;
use strict;

use Moose;
use DBIx::Deploy::Carp;

has stage => qw/is ro required 1/;
has command => qw/is ro/;
has rank => qw/is ro required 1 isa Int default 0/;
has connection => qw/is rw required 1 isa Str default default/;

sub BUILD {
    my $self = shift;
    my $given = shift;

    croak "Wasn't given a command" unless my $command = $given->{command};

    if (blessed $command && $command->isa("DBIx::Deploy::Command")) {
    }
    else {
        $self->{command} = DBIx::Deploy::Command->Parse($command);
    }
}

sub execute {
    my $self = shift;
    my $context = shift;

    $context->stash->{step} = $self;

    $self->command->execute($context);
}

1;
