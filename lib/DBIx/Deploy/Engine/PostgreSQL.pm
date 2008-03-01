package DBIx::Deploy::Engine::PostgreSQL;

use warnings;
use strict;

use Moose;
extends qw/DBIx::Deploy::Engine::DBISuTdConnection/;

sub driver {
    return "Pg";
}

sub created {
    my $self = shift;
    my $connection = shift;

    # TODO Setuped?
    my $result = $connection->select_value('SELECT COUNT(*) FROM pg_database WHERE datname = ?', $connection->database);
    return 0 unless $result;

    return 1 unless defined (my $created = $self->stash->{created}); # By default (if we get this far) assume the database was made
    $result = $connection->select_value('SELECT COUNT(*) FROM pg_tables WHERE tablename = ?', $created);
    return $result;
}

sub populated {
    my $self = shift;
    my $connection = shift;

    return 1 unless defined (my $populated = $self->stash->{populated}); # By default, assume the database is populated
    $populated =~ s/\W//; # Detaint this puppy
    my $result = $connection->select_value("SELECT COUNT(*) FROM $populated");
    return $result > 0 ? 1 : 0;
}

1;
