package DBIx::Deploy::Connection::SQLite;

use strict;
use warnings;

use DBI;
use Object::Tiny qw/engine source database username password attributes/;

sub new {
    my $self = bless {}, shift;
    my $engine = shift;

    my ($database, $attributes);
    if (ref $_[0] eq "ARRAY") {
        ($database, $attributes) = @{ $_[0] };
    }
    elsif (ref $_[0] eq "HASH") {
        ($database, $attributes) = @{ $_[0] }{qw/database attributes/};
    }
    else {
        die;
    }

    my $source = "dbi:" . $engine->driver . ":dbname=$database";

    @$self{qw/engine source database username password attributes/} = ($engine, $source, $database, undef, undef, $attributes);

    return $self;
}

sub connect {
    my $self = shift;
    return DBI->connect($self->information);
}

sub information {
    my $self = shift;
    my @information = ($self->source, $self->username, $self->password, $self->attributes);
    return wantarray ? @information : \@information;
}

1;

