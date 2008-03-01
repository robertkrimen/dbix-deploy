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
    my ($connection, $dbh) = @_;

    my $created = $dbh->selectrow_arrayref('SELECT COUNT(*) FROM pg_database WHERE datname = ?', undef, $connection->database)->[0];
    return 0 unless $created;

    $created = $dbh->selectrow_arrayref('SELECT COUNT(*) FROM pg_tables WHERE tablename = ?', undef, 'deploy_test')->[0];
    return $created;
}

sub populated {
    my $self = shift;
    my ($connection, $dbh) = @_;

    my $populated = $dbh->selectrow_arrayref('SELECT COUNT(*) FROM deploy_test')->[0];
    return $populated > 0 ? 1 : 0;
}

1;
