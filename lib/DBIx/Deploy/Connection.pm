package DBIx::Deploy::Connection;

use strict;
use warnings;

use Moose;
use DBI;
use Carp::Clan;

has engine => qw/is ro required 1 weak_ref 1/;
has $_ => qw/is ro/ for qw/source database username password attributes/;
has handle => qw/is ro lazy 1/, default => sub {
    my $self = shift;
    return $self->connect;
};

sub dbh {
    return shift->handle;
}

sub open {
    return shift->handle;
}

sub close {
    my $self = shift;
    if ($self->{handle}) {
        $self->handle->disconnect;
        $self->meta->get_attribute("handle")->clear_value($self);
    }
}

sub disconnect {
    my $self = shift;
    return $self->close;
}

sub parse {
    my $class = shift;
    my $engine = shift;

    my ($database, $username, $password, $attributes);
    if (ref $_[0] eq "ARRAY") {
        ($database, $username, $password, $attributes) = @{ $_[0] };
        shift;
    }
    elsif (ref $_[0] eq "HASH") {
        ($database, $username, $password, $attributes) = @{ $_[0] }{qw/database username password attributes/};
        shift;
    }
    else {
        croak "Don't know what to do with $_[0]";
    }

    $database = $engine->connection($1)->database if $database && ! ref $database && $database =~ m/^\$(.*)$/;
    $username = $engine->connection($1)->username if $username && ! ref $username && $username =~ m/^\$(.*)$/;
    $password = $engine->connection($1)->password if $password && ! ref $password && $password =~ m/^\$(.*)$/;
    $attributes = $engine->connection($1)->attributes if $attributes && ! ref $attributes && $attributes =~ m/^\$(.*)$/;
    for ($database, $username, $password, $attributes) {
        $_ = $$_ if ref $_ eq "SCALAR";
    }

    my $source = "dbi:" . $engine->driver . ":dbname=$database";

    return $class->new(engine => $engine, source => $source, database => $database, username => $username, password => $password, attributes => $attributes, @_);
}

sub run {
    my $self = shift;

    my $dbh = $self->connect;
    unless ($dbh) {
        no warnings 'uninitialized';
        my @information = $self->information;
        croak "Unable to connect with (@information): ", DBI->errstr unless $dbh;
    }
    for my $statement (@_) {
        chomp $statement;
        warn "$statement\n" if 1;
        $dbh->do($statement) or die $dbh->errstr;
    }
    $dbh->disconnect;
}

sub connectable {
    my $self = shift;

    my ($database, $username, $password, $attributes) = $self->information;
    $attributes ||= {};
    $attributes->{$_} = 0 for qw/PrintWarn PrintError RaiseError/;
    my $dbh = DBI->connect($database, $username, $password, $attributes);
    my $success = $dbh && ! $dbh->err && $dbh->ping;
    $dbh->disconnect if $dbh;
    return $success;
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

sub select_value {
    my $self = shift;
    my $statement = shift;
    unshift @_, undef unless ref $_[0] eq "HASH";

    my $result = $self->handle->selectrow_arrayref($statement, @_);
    my $value = $result->[0];
    return $value;
}

1;
