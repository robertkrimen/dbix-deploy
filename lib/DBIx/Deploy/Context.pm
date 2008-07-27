package DBIx::Deploy::Context;

use warnings;
use strict;

=head1 NAME

DBIx::Deploy::Context

=head1 SYNPOSIS 

=head1 DESCRIPTION

A context for a running script. The context contains a reference to the engine, current stage and step, and a persistent stash for
sharing information.

=cut

use Moose;
use DBIx::Deploy::Carp;

=head1 METHODS

=head2 $context->engine

Return the L<DBIx::Deploy::Engine> associated with $context

=head2 $context->stage

Return the current stage, generally one of C<create>, C<populate>, C<setup>, or C<teardown>

=head2 $context->step

Return the current L<DBIx::Deploy::Step>

=head2 $context->command

Return the current L<DBIx::Deploy::Command>

=head2 $context->arguments

Return the arguments, a HASH reference, from $context->command->arguments

=head2 $context->connection

Return the connection (L<DBIx::Deploy::Connection>) resolved from $context->engine->connection and $context->step->connection

That is, the name given by $context->step->connection is passed through to $context->engine->connection and the result is returned

If $context->step->connection is the special value "default", then the connection name is the value of $context->stash->{default_connection}

Finally, if $context->stash->{default_connection} is undef, then the $engine->connection->user is returned

=cut

has engine => qw/is ro required 1 isa DBIx::Deploy::Engine/;
has stage => qw/is ro required 1 isa Str/;
has step => qw/is rw isa DBIx::Deploy::Step/;
has stash => qw/is ro required 1 isa HashRef lazy 1/, default => sub { {} };

sub command {
    my $self = shift;
    return $self->step->command;
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

=head2 $context->dbh

A shortcut for $context->connection->dbh

See L<DBIx::Deploy::Connection> for more information

=cut

sub dbh {
    my $self = shift;
    return $self->connection->dbh(@_);
}

=head2 $context->run( ... )

A shortcut for $context->connection->run( ... )

See L<DBIx::Deploy::Connection> for more information

=cut

sub run {
    my $self = shift;
    return $self->connection->run(@_);
}


1;
