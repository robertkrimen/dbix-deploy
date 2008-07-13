package DBIx::Deploy::Engine;

use warnings;
use strict;

use Moose;
use base qw/Class::Accessor::Grouped/;

use Template;
use SQL::Script;
use Carp;
use DBIx::Deploy::Connection;
use DBIx::Deploy::Stash;
use Term::Prompt();

__PACKAGE__->mk_group_accessors(inherited => qw/_base_stash/);
__PACKAGE__->configure({
    connection_class => "DBIx::Deploy::Connection",
});

=head1 NAME

DBIx::Deploy::Engine

=head1 Connection specification

A connection specification specifies the DBI connections used by the engine. The most basic format is an array reference of what
you would pass to DBI->connect(...):

    

=head1 Engine configuration

An engine configuration is a hash containing the following:

    connection => {

        user => The user connection for the database. This is the connection that interacts with the database while the application
                is running.

        superdatabase => This is the connection used for creating/dropping the actual database (CREATE DATABASE/DROP DATABASE).
                         This connection does NOT connect to the user database because:

                                1. You can't connect to a database that doesn't exist
                                2. You can't drop a database with an active connection

                         In PostgreSQL, this is something like the template0 or template1 database.
                         In MySQL, this is something like the mysql database.

        superuser => A hybrid connection, consisting of the superdatabase username/password and user database. This is used for
                     setting up advanced features on the user database without having to grant extra privileges to the regular user.
                     For example, with a PostgreSQL database you would use this connection to run CREATE LANGUAGE

        <name> => Any other specially named connection you want to specify

    }

    setup => A script for creating the actual database (e.g. createdb with PostgreSQL). Run via the C<superdatabase> connection.

    create => A script for creating the database schema. Run via the C<user> connection.

    populate => A script for populating the database with data. Run via the C<user> connection.

    teardown => A script for tearing down the database (e.g. dropdb with PostgreSQL). Run via the C<superdatabase> connection.

    before => {
    
        setup => A script that will run before the (main) setup script.

        create => A script that will run before the (main) create script.

        populate => A script that will run before the (main) populate script.

        teardown => A script that will run before the (main) teardown script.
    }

    after => {
    
        setup => A script that will run after the (main) setup script.

        create => A script that will run after the (main) create script.

        populate => A script that will run after the (main) populate script.

        teardown => A script that will run after the (main) teardown script.
    }

=head1 Scripting setup/create/populate/teardown

A script is a list (array reference) composed of steps. The steps are run through in order.

SQL in a step will be first processed via Template Toolkit.  The result will be split using L<SQL::Script> with the following pattern: C</\n\s*-{2,4}\n/>

That is, a newline, followed by optional whitespace, followed by 2 to 4 dashes and another newline. For example:

    CREATE TABLE album (...)

    --

    CREATE TABLE artist (...)

    --

A step can be:

=head2 ~<connection> 

Set the connection for the following STEP to be <connection>

After the following STEP, the connection will revert to the default connection

    ..., ~user => \"CREATE TABLE ...", ...

    ..., ~superuser => \"CREATE TABLE ...", ...

=head2 <file>

Execute the SQL in the <file> using the current connection

    ..., /path/to/sql/extra.sql, ...

=head2 <directory>

Execute the SQL in the file <directory>/<stage>{.sql, .tt2.sql, .tt.sql, .tt2, .tt} using the current connection

    ..., /path/to/sql/, ...

    # If the current stage is "create", then the above will use /path/to/sql/create.sql (or one of the other extensions)

=head2 SCALAR

Execute the SQL contained in SCALAR using the current connection. Again, statements should be separated using a double dash at the
beginning of the line (as described above).

=cut

    #=head2 CODE

    #Execute CODE, passing in: the engine,  the remaining script (as an array reference) 

    #=head2 ARRAY


sub driver {
    my $self = shift;
    croak "Don't have a driver for $self";
}

has script => qw/is ro required 1 lazy 1/, default => sub {
    return SQL::Script->new(split_by => qr/\n\s*-{2,4}\n/);
};

has template => qw/is ro required 1 lazy 1/, default => sub {
    return Template->new({});
};

has _connection => qw/is ro required 1 lazy 1/, default => sub { {} };

has stash => qw/is ro/;

has password_store => qw/is ro required 1 lazy 1 isa HashRef/, default => sub { {} };

sub connection {
    my $self = shift;
    my $name = shift;
    $name = "user" unless defined $name;
    return $self->_connection->{$name} ||= do {
        my $connection = $self->stash->{connection}->{$name};
        if (! $connection && $name eq "superuser") {
            $connection = [ qw/$user $superdatabase $superdatabase $user/ ],
        }
        croak "Don't have a connection definition for $name" unless $connection;
        $self->stash->{connection_class}->parse($self, $name, $connection);
    };
}

sub prepare_stash {
    my $self = shift;
    my $stash = shift;

    $stash->{connection} ||= {};
    $stash->{script} ||= {};

    for (qw/user superuser superdatabase/) {
        if (exists $stash->{$_}) {
            my $value = delete $stash->{$_};
            $stash->{connection}->{$_} = $value unless exists $stash->{connection}->{$_}
        }
    }

    for (qw/setup teardown create populate/) {
        if (exists $stash->{$_}) {
            my $value = delete $stash->{$_};
            $stash->{script}->{$_} = $value unless exists $stash->{script}->{$_}
        }
    }

    $self->{stash} = $stash;
}

sub BUILD {
    my $self = shift;
    my $new = shift;
    my $configure = $new->{configure} || {};
    my $stash = $self->configure($configure);

    $self->prepare_stash($stash);

    if ($self->{template}) {
        if (ref $self->{template} eq "" || (blessed $self->{template} && $self->{template}->isa("Path::Class::Dir"))) {
            $self->{template} = Template->new({ INCLUDE_PATH => $self->{template} });
        }
        elsif (ref $self->{template} eq "HASH") {
            $self->{template} = Template->new($self->{template});
        }
        elsif (blessed $self->{template} && $self->{template}->isa("Template")) {
        }
        else {
            croak "Don't understand how to use $self->{template} for templating"
        }
    }

    return $self;
}

sub password {
    my $self = shift;
    my %given = @_;

    my $key = $given{key};
    $given{save} = 1 unless exists $given{save};

    if ($given{force} || ! defined $self->password_store->{$key}) {

        unless ($Test::Builder::VERSION) {
            croak "Can't read password prompt from non-tty STDIN" unless -t STDIN && -t STDOUT;
        }

        my $password = Term::Prompt::prompt(P => $given{prompt} || "Enter password:", $given{help} || '', '');
        $self->password_store->{$key} = $password if $given{save};
        return $password;
    }

    return $self->password_store->{$key};
}

sub generate {
    my $self = shift;
    my $input = shift;
    my $context = shift || {};

    $self->_generate_prepare_context($context);

    $input = "$input" if blessed $input && $input->isa("Path::Class::File");

    croak "Don't have a template" unless $input;
    croak "Don't understand template \"$input\"" unless ref $input eq 'SCALAR' || ref $input eq '';
    my $script = $self->_template_process($input, $context);

    return $script unless wantarray;

    $self->script->read($script);
    my @statements = $self->script->statements;
    return @statements;
}

sub _generate_prepare_context {
    my $self = shift;
    my $context = shift;

    $context->{engine} = $self;
    $context->{connection} = $self->connection;
}

sub _run_from_file {
    my $self = shift;
    my $connection = shift;
    my $file = shift;

    $file = Path::Class::file($file);

    my @statements = $self->generate($file);
    $connection->run(\@statements, @_);
}

sub _run_from_name {
    my $self = shift;
    my $connection = shift;
    my $dir = shift;
    my $name = shift;

    my $soft = $dir =~ s/^\?//;
    $dir = Path::Class::dir($dir);

    for ("", qw/.sql .tt2.sql .tt.sql .tt2 .tt/) {
        next unless -f (my $file = $dir->file("$name$_"));
        return $self->_run_from_file($connection, $file, @_)
    }

    croak "Couldn't find file under $dir for $name" unless $soft;
}

sub _run_from_all {
    my $self = shift;
    my $connection = shift;
    my $dir = shift;

    $dir =~ s{\*$}{};
    $dir = Path::Class::dir($dir);

    croak "Uhh, not ready yet";
}

sub run_script_sequence {
    my $self = shift;
    my $name = shift;

    my $stash = $self->stash->{script};
    my $script;

    if ($stash->{before} && ($script = $stash->{before}->{$name})) {
        $self->run_script($name, script => $script, @_);
    }

    $self->run_script($name, script => $stash->{$name}, @_);

    if ($stash->{after} && ($script = $stash->{after}->{$name})) {
        $self->run_script($name, script => $script, @_);
    }
}

sub run_script {
    my $self = shift;
    my $name = shift;
    local %_ = @_;

    my $default_connection = $_{connection} || $self->connection;

    my $script = delete $_{script};
    unless ($script) {
        return if $_{ignore_missing};
        croak "Don't have a script called $name";
    }

    my @script = ref $script eq "ARRAY" ? @$script : ($script);

    while (@script) {

        my $connection = $default_connection;

STEP:
        croak "A null step in script \"$name\"?" unless defined (my $step = shift @script);

        if (ref $step eq '') {
            if ($step =~ s/^~//) {
                $connection = $self->connection($step);
                goto STEP if @script;
            }
            elsif ($step =~ m/^!exec$/i) {
                croak "Uhh, not ready yet";
            }
            elsif ($step =~ m/::/i) {
                # DBIx::Class::Schema
                croak "Uhh, not ready yet";
            }
            else {
                if ($step =~ m{/$}) {
                    $self->_run_from_name($connection, $step, $name, %_);
                }
                elsif ($step =~ m{/\*$}) {
                    $self->_run_from_all($connection, $step, %_);
                }
                else {
                    my $test = $step;
                    $test =~ s/^\?//;
                    if (-f $test) {
                        $self->_run_from_file($connection, $step, %_);
                    }
                    elsif (-d $test) {
                        $self->_run_from_name($connection, $step, $name, %_);
                    }
                    else {
                        croak "Don't understand step ($step) since ($test) is neither a file nor directory";
                    }
                }
            }
        }
        elsif (ref $step eq 'SCALAR') {
            my @statements = $self->generate($step);
            $connection->run(\@statements, %_);
        }
        elsif (ref $step eq 'CODE') {
            $step->($self, \@script, %_);
        }
        elsif (ref $step eq 'ARRAY') {
            # TODO Don't think this works
            for (@$step) {
                my @statements = $self->generate($step);
                $connection->run(\@statements, %_);
            }
        }
        else {
            croak "Don't understand step: $step";
        }
    }
}

sub _template_process {
    my $self = shift;
    my $template = shift;
    my $context = shift || {};

    my $output;
    $self->template->process($template, $context, \$output) or die $self->template->error;

    return \$output;
}

sub database_exists {
    my $self = shift;
    if (ref $self->stash->{database_exists} eq "CODE") {
        return $self->stash->{database_exists}->($self);
    }
    return $self->_database_exists;
}

sub _database_exists {
    return undef;
}

sub schema_exists {
    my $self = shift;
    if (ref $self->stash->{schema_exists} eq "CODE") {
        return $self->stash->{schema_exists}->($self);
    }
    return $self->_schema_exists;
}

sub _schema_exists {
    return undef;
}

sub _superdatabase_or_super_or_user_connection {
    my $self = shift;
    for (qw/superdatabase superuser user/) {
        return $self->connection($_) if $self->stash->{connection}->{$_};
    }
    croak "Urgh, don't have any connection to return";
}

sub ready {
    my $self = shift;
    if (ref $self->stash->{ready} eq "CODE") {
        return $self->stash->{ready}->($self);
    }
}

sub _ready {
    my $self = shift;
    return $self->database_exists && $self->schema_exists;
}

sub create {
    my $self = shift;
    return $self->run_script_sequence("create", ignore_missing => 1, @_);
}

sub populate {
    my $self = shift;
    return $self->run_script_sequence("populate", ignore_missing => 1, @_);
}

sub setup {
    my $self = shift;
    return $self->run_script_sequence("setup", ignore_missing => 1, connection => $self->_superdatabase_or_super_or_user_connection, @_);
}

sub teardown {
    my $self = shift;
    return $self->run_script_sequence("teardown", raise_error => 0, ignore_missing => 1, connection => $self->_superdatabase_or_super_or_user_connection, @_);
}

sub deploy {
    my $self = shift;

    if (defined (my $database_exists = $self->database_exists)) {
        if ($database_exists) {
            if (defined (my $schema_exists = $self->schema_exists)) {
                unless ($schema_exists) {
                    $self->create;
                    $self->populate;
                }
            }
        }
        else {
            $self->setup;
            $self->create;
            $self->populate;
        }
    }

    $self->connection->disconnect;

    return $self->connection->information;
}

sub information {
    my $self = shift;
    local %_ = @_;
    $_{deploy} = 1 unless exists $_{deploy};
    $self->deploy if $_{deploy};
    return $self->connection->information;
}

sub configure {
    my $self = shift;
    my $override = shift;
    my $base = $self->_base_stash || {};
    return $self->_base_stash(DBIx::Deploy::Stash->merge($base, $override));
}

1;
