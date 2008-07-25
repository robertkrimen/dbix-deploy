package DBIx::Deploy::Engine;

use warnings;
use strict;

use Moose;
use base qw/Class::Accessor::Grouped/;
use DBIx::Deploy::Carp;

use Template;
use SQL::Script;
use DBIx::Deploy::Connection;
use DBIx::Deploy::Step;
use DBIx::Deploy::Stash;
use DBIx::Deploy::Context;
use DBIx::Deploy::Command;
use Term::Prompt();
use Hash::Merge::Simple qw/merge/;

__PACKAGE__->mk_group_accessors(inherited => qw/configuration/);
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

=head1 Scripting setup/create/populate/teardown

A script is a list (array reference) composed of steps. The steps are run through in order according to their rank.

SQL in a step (from a SCALAR reference or a file) will be first processed via Template Toolkit. 
The result will be split using L<SQL::Script> with the following pattern: C</\n\s*-{2,4}\n/>

That is, a newline, followed by optional whitespace, followed by 2 to 4 dashes and another newline. For example:

    CREATE TABLE album (...)

    --

    CREATE TABLE artist (...)

    --

A step can be:

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

=head2 rank <rank>

Not a step per se. Will set the rank of the following steps to the integer value <rank> (which can be negative or positive). The default rank is 0.

=head2 stage <stage>

Not a step per se. Will set the stage of the following steps to <stage> (which should be one of C<create>, C<populate>, C<setup>, or C<teardown>)

=head2 connection <connection>

Not a step per se. Will set the connection of the following steps to <connection> (usually C<user>, C<superuser>, or C<superdatabase>)

=cut

#    =head2 ~<connection> 

#    Set the connection for the following STEP to be <connection>

#    After the following STEP, the connection will revert to the default connection

#        ..., ~user => \"CREATE TABLE ...", ...

#        ..., ~superuser => \"CREATE TABLE ...", ...

#    =head2 CODE

#    Execute CODE, passing in: the engine,  the remaining script (as an array reference) 

#    =head2 ARRAY


sub driver {
    my $self = shift;
    croak "Don't have a driver for $self";
}

has script_parser => qw/is ro required 1 lazy 1/, default => sub {
    return SQL::Script->new(split_by => qr/\n\s*-{2,4}\n/);
};

has template => qw/is ro required 1 lazy 1/, default => sub {
    return Template->new({});
};

has [qw/stash _script _connection _password/] => qw/is ro required 1 lazy 1 isa HashRef/, default => sub { {} };

sub connection {
    my $self = shift;
    my $name = shift;
    $name = "user" unless defined $name;
    if ($name =~ m/\|/) {
        my @name = split m/\|/, $name;
        for my $name (@name) {
            next unless $self->configuration->{connection}->{$name};
            return $self->connection($name);
        }
        croak "Unable to find a connection for $name";
    }
    return $self->_connection->{$name} ||= do {
        my $connection = $self->configuration->{connection}->{$name};
        if (! $connection && $name eq "superuser") {
            $connection = [ qw/$user $superdatabase $superdatabase $user/ ],
        }
        croak "Don't have a connection definition for $name" unless $connection;
        $self->configuration->{connection_class}->parse($self, $name, $connection);
    };
}

sub password {
    my $self = shift;
    my %given = @_;

    my $key = $given{key};
    $given{save} = 1 unless exists $given{save};

    if ($given{force} || ! defined $self->_password->{$key}) {

        unless ($Test::Builder::VERSION) {
            croak "Can't read password prompt from non-tty STDIN" unless -t STDIN && -t STDOUT;
        }

        my $password = Term::Prompt::prompt(P => $given{prompt} || "Enter password:", $given{help} || '', '');
        $self->_password->{$key} = $password if $given{save};
        return $password;
    }

    return $self->_password->{$key};
}

sub BUILD {
    my $self = shift;
    my $given = shift;

    my $configuration = $self->configure($given->{configuration} || {});

    $self->_prepare_configuration($configuration);
    $self->_prepare_script(delete $configuration->{$_}, stage => $_) for qw/create populate setup teardown/;
    $self->_prepare_script(delete $configuration->{script}, qw/stage create/);

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

sub configure {
    my $self = shift;
    my $override = shift;
    my $base = $self->configuration || {};
    return $self->configuration(merge $base, $override);
}

sub _prepare_configuration {
    my $self = shift;
    my $configuration = shift;

    $configuration->{connection} ||= {};
    for my $name (qw/user superuser superdatabase/) {
        my $connection = delete $configuration->{$name};
        $configuration->{connection}->{$name} = $connection if $connection;
    }
}

sub _prepare_script {
    my $self = shift;
    my $script = shift;
    my %default = @_;

    return unless $script;

    $script = [ $script ] unless ref $script eq "ARRAY";

    croak "Don't understand script $script" unless ref $script eq "ARRAY";

    my @script = @$script;

    while (@script) {
        local $_ = shift @script;
        next unless $_;
        if (! ref) {
            if ($_ =~ m/^(?:rank|stage|connection|as)$/) {
                $default{$_} = shift @script;
                next;
            }
            elsif ($_ =~ m/^(?:step|do)$/) {
                $self->do(%default, %{ shift @script });
                next;
            }
        }

        $self->do(%default, command => $_);
    }
}

sub do {
    my $self = shift;
    my $step = @_ == 1 && ref $_[0] eq "HASH" ? shift : { @_ };
    $step = DBIx::Deploy::Step->new(%$step);
    push @{ $self->_script->{$step->stage} }, $step;
    return $step;
}

sub _run_script {
    my $self = shift;
    my $stage = shift;
    my $stash = { @_ };

    $stash->{stage} = $stage;
    $stash->{engine} = $self;
    my $context = DBIx::Deploy::Context->new(stash => $stash);

    my @script = sort { $a->rank <=> $b->rank } @{ $self->_script->{$stage} || [] };

    for my $step (@script) {
        $self->_run_step($step, $context);
    }
}

sub _run_step {
    my $self = shift;
    my $step = shift;
    my $context = shift;

    $step->execute($context);
}

sub create {
    my $self = shift;
    return $self->_run_script("create", ignore_missing => 1, default_connection => "user", @_);
}

sub populate {
    my $self = shift;
    return $self->_run_script("populate", ignore_missing => 1, default_connection => "user", @_);
}

sub setup {
    my $self = shift;
    return $self->_run_script("setup", ignore_missing => 1, default_connection => "superdatabase|superuser|user", @_);
}

sub teardown {
    my $self = shift;
    return $self->_run_script("teardown", raise_error => 0, ignore_missing => 1, default_connection => "superdatabase|superuser|user", @_);
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

sub prepare_SQL_context {
    my $self = shift;
    my $context = shift || {};

    if (blessed $context) {
        my %context;
        %context = %{ $context->stash };
        $context{context} = $context;
        $context{connection} = $context->connection;
        $context = \%context;
    }
    else {
        $context->{engine} ||= $self;
        $context->{connection} ||= $context->{engine}->connection;
    }

    $context->{user} ||= $context->{engine}->connection;

    return $context;
}

sub run_SQL {
    my $self = shift;
    my $SQL = shift;
    my $context = $self->prepare_SQL_context(shift);

    my @statements = $self->generate_SQL($SQL, $context);
    my $connection = $context->{connection};
    $connection->run(\@statements, $context);
}

sub generate_SQL {
    my $self = shift;
    my $input = shift;
    my $context = $self->prepare_SQL_context(shift);

    $input = "$input" if blessed $input && $input->isa("Path::Class::File");

    croak "Don't have a template" unless $input;
    croak "Don't understand template \"$input\"" unless ref $input eq 'SCALAR' || ref $input eq '';
    my $script = $self->_template_process($input, $context);

    return $script unless wantarray;

    $self->script_parser->read($script);
    my @statements = $self->script_parser->statements;
    return @statements;
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
    if (ref $self->configuration->{database_exists} eq "CODE") {
        return $self->configuration->{database_exists}->($self);
    }
    return $self->_database_exists;
}

sub _database_exists {
    # Placeholder to be overridden
    return undef;
}

sub schema_exists {
    my $self = shift;
    if (ref $self->configuration->{schema_exists} eq "CODE") {
        return $self->configuration->{schema_exists}->($self);
    }
    return $self->_schema_exists;
}

sub _schema_exists {
    # Placeholder to be overridden
    return undef;
}

sub ready {
    my $self = shift;
    if (ref $self->configuration->{ready} eq "CODE") {
        return $self->configuration->{ready}->($self);
    }
}

sub _ready {
    my $self = shift;
    return $self->database_exists && $self->schema_exists;
}

1;

__END__

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

1;
