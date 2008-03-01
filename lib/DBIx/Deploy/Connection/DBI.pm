package DBIx::Deploy::Connection::DBI;

use strict;
use warnings;

use Moose;

extends qw/DBIx::Deploy::Connection/;

sub parse {
    my $class = shift;
    my $engine = shift;

    my ($database, $username, $password, $attributes);
    if (ref $_[0] eq "ARRAY") {
        ($database, $username, $password, $attributes) = @{ $_[0] };
    }
    elsif (ref $_[0] eq "HASH") {
        ($database, $username, $password, $attributes) = @{ $_[0] }{qw/database username password attributes/};
    }
    else {
        die;
    }

    my $source = "dbi:" . $engine->driver . ":dbname=$database";

    return $class->new(engine => $engine, source => $source, database => $database, username => $username, password => $password, attributes => $attributes, @_);
}

sub information {
    my $self = shift;
    my @information = ($self->source, $self->username, $self->password, $self->attributes);
    return wantarray ? @information : \@information;
}

1;
