package DBIx::Deploy::Engine::PostgreSQL;

use warnings;
use strict;

use Moose;
extends qw/DBIx::Deploy::Engine/;

sub driver {
    return "Pg";
}

sub _database_exists {
    my $self = shift;

    my $result = $self->connection(qw/superdatabase/)->select_value('SELECT COUNT(*) FROM pg_database WHERE datname = ?', $self->connection->database);
    return $result > 0 ? 1 : 0;
}

sub _schema_exists {
    my $self = shift;

    if ($self->stash->{schema_exists} && ref $self->stash->{schema_exists} eq "") {
        my $result = $self->connection->select_value('SELECT COUNT(*) FROM pg_tables WHERE tablename = ?', $self->stash->{schema_exists});
        return $result;
    }

    return undef;
}

1;

__END__

sub populated {
    my $self = shift;
    my $connection = shift || $self->connection;

    return 1 unless defined (my $populated = $self->stash->{populated}); # By default, assume the database is populated
    $populated =~ s/\W//; # Detaint this puppy
    my $result = $connection->select_value("SELECT COUNT(*) FROM $populated");
    return $result > 0 ? 1 : 0;
}

1;
