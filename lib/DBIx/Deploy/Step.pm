package DBIx::Deploy::Step;

use warnings;
use strict;

use Moose;
use DBIx::Deploy::Carp;

=head1 NAME

DBIx::Deploy::Step

=head1 METHODS

=head2 $step->stage

Returns the stage (C<create>, C<populate>, C<setup>, or C<teardown>) associated with $step

=head2 $step->command

Returns the L<DBIx::Deploy::Command> associated with $step

=head2 $step->connection

Returns the name of the connection that $step should use when executing $step->command

=head2 $step->rank

Returns the rank of $step

=cut

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

sub run {
    my $self = shift;
    my $context = shift;

    $context->step($self);

    $self->command->run($context);
}

1;
