package DBIx::Deploy::Connection;

use strict;
use warnings;

use Moose;
use DBI;
use Carp::Clan;

=head1 NAME

DBIx::Deploy::Connection

=head1 SYNPOSIS 

    my $connection = $engine->connection->user

    if ($connection->connectable) {
    
        ... Are we able to connect to the database? ...

    }

    my $dbh = $connection->dbh

    ...

    $connection->disconnect # Does $dbh->disconnect IF already connected, does nothing otherwise

=head1 DESCRIPTION

Represents a connection to a database, similar to a DBI handle

=head1 METHODS

=cut

has engine => qw/is ro required 1 weak_ref 1/;
has [qw/linkage source database username password attributes/] => qw/is ro/;
has handle => qw/is ro lazy 1/, default => sub {
    my $self = shift;
    return $self->connect;
};

=head2 $connection->dbh

=head2 $connection->open

Return an active DBI handle for $connection, opening it first if necessary

=cut

sub dbh {
    return shift->handle;
}

sub open {
    return shift->handle;
}

=head2 $connection->disconnect

=head2 $connection->close

Perform a disconnect on the active DBI handle, if any

If not already connected, then this method does nothing

=cut

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

=head2 $connection->connect

Return a separate/standalone DBI handle for use outside of $connection

Do NOT use this if you want the handle for $connection (Use ->dbh instead)

=cut

sub connect {
    my $self = shift;
    return DBI->connect($self->information);
}

sub _parse_linkage {
    my $class = shift;
    my $linkage = shift;
    my $driver_hint = shift;

    my ($database, $source_template) = split m/\|/, $linkage;
    $database = $linkage unless $database;
    $source_template = $driver_hint unless $source_template;

    croak "Don't know how to generate database source" unless defined $source_template;

    if ($source_template =~ m/^\s*(?:Pg|PostgreS(?:QL)?)\s*$/i) {
        $source_template = "dbi:Pg:dbname=\%database";
    }
    elsif ($source_template =~ m/^\s*MySQL\s*$/i) {
        $source_template = "dbi:mysql:dbname=\%database";
    }
    elsif ($source_template =~ m/^\s*SQLite\s*$/i) {
        $source_template = "dbi:SQLite:dbname=\%database";
    }

    my $source = $source_template;
    $source =~ s/%database/$database/g;

    return ($source, $database);
}


sub parse {
    my $class = shift;

    my ($linkage, $username, $password, $attributes);
    if (ref $_[0] eq "ARRAY") {
        ($linkage, $username, $password, $attributes) = @{ $_[0] };
        shift;
    }
    elsif (ref $_[0] eq "HASH") {
        ($linkage, $username, $password, $attributes) = @{ $_[0] }{qw/database username password attributes/};
        shift;
    }
    else {
        croak "Don't know what to do with $_[0]";
    }

    my $engine = shift;
    my $name = shift;
    my $driver_hint = shift;

    $driver_hint = $engine->driver_hint unless defined $driver_hint;

    $linkage = $engine->connection($1)->linkage if $linkage && ! ref $linkage && $linkage =~ m/^\$(.*)$/;
    $username = $engine->connection($1)->username if $username && ! ref $username && $username =~ m/^\$(.*)$/;
    $password = $engine->connection($1)->password if $password && ! ref $password && $password =~ m/^\$(.*)$/;
    $attributes = $engine->connection($1)->attributes if $attributes && ! ref $attributes && $attributes =~ m/^\$(.*)$/;

    $linkage = $$linkage if ref $linkage eq "SCALAR";

    my ($source, $database) = $class->_parse_linkage($linkage, $driver_hint);

    if ($password && $password =~ s/\s*<//) {
        my $key = $password;

        my $identity = "$username\@$database";

        if      ($key eq "\$name")                  { $key = $name }
        elsif   (! $key || $key eq "\$identity")    { $key = $identity }

        $password = $engine->password(key => $key, prompt => "Enter password for $identity ($name):");
    }

    for ($username, $password, $attributes) {
        $_ = $$_ if ref $_ eq "SCALAR";
    }

    return $class->new(engine => $engine, linkage => $linkage, source => $source, database => $database, username => $username, password => $password, attributes => $attributes, @_);
}

sub run {
    my $self = shift;
    my $statements = shift;
    my $context = shift;

    my $raise_error = 1;
    $raise_error = $context->{raise_error} if exists $context->{raise_error};

    my $dbh = $self->connect;
    unless ($dbh) {
        no warnings 'uninitialized';
        my @information = $self->information;
        croak "Unable to connect with (@information): ", DBI->errstr unless $dbh;
    }
    for my $statement (@$statements) {
        eval {
            chomp $statement;
            warn "$statement\n" if $ENV{DBID_TRACE};
            $dbh->do($statement) or die $dbh->errstr;
        };
        if (my $error = $@) {
            if ($raise_error) {
                die $error;
            }
            else {
                warn $error;
            }
        }
    }
    $dbh->disconnect;
}

=head2 $connection->connectable

Return true if $connection was able to connect to the database successfully  

Essentially just does a $dbh->ping

This method will not open a persistent connection (like $connection->dbh does, etc.)

=cut

sub connectable {
    my $self = shift;

    my ($source, $username, $password, $attributes) = $self->information;
    $attributes ||= {};
    $attributes->{$_} = 0 for qw/PrintWarn PrintError RaiseError/;
    my $dbh = DBI->connect($source, $username, $password, $attributes);
    my $success = $dbh && ! $dbh->err && $dbh->ping;
    $dbh->disconnect if $dbh;
    return $success;
}

=head2 $connection->source

Return the source for $connection

    dbi:Pg:dbname=xyzzy

=head2 $connection->database

Return the database (name) for $connection

    xyzzy

=head2 $connection->username

Return the username (if any) for $connection

    Alice

=head2 $connection->password

Return the password (if any) for $connection

    ******

=head2 $connection->attributes

Return the attributes (as a hash reference, if any) for $connection

    {
        RaiseError => 1,
        ...,
    }

=head2 $connection->information

Return the connection information for $connection, suitable for passing into DBI->connect 

That is, will return <source>, <username>, <password>, <attributes>

In scalar context will return a list reference instead of a list

=cut

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
