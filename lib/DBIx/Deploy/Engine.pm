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

__PACKAGE__->mk_group_accessors(inherited => qw/_base_stash/);
__PACKAGE__->configure({
    connection_class => "DBIx::Deploy::Connection",
});

sub driver {
    my $self = shift;
    croak "Don't have a driver for $self";
}

has script => qw/is ro required 1 lazy 1/, default => sub {
    return SQL::Script->new(split_by => qr/\n\s*--\n/);
};

has template => qw/is ro required 1 lazy 1/, default => sub {
    return Template->new({});
};

has _connection => qw/is ro required 1 lazy 1/, default => sub { {} };

has stash => qw/is ro/;

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
        $self->stash->{connection_class}->parse($self, $connection);
    };
}

sub BUILD {
    my $self = shift;
    my $new = shift;
    my $configure = $new->{configure} || {};
    my $stash = $self->configure($configure);

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

sub generate {
    my $self = shift;
    my $input = shift;
    my $context = shift || {};

    $self->_generate_prepare_context($context);

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

sub run_script {
    my $self = shift;
    my $name = shift;
    local %_ = @_;

    my $default_connection = $_{connection} || $self->connection;

    my $script = $self->stash->{script}->{$name};
    unless ($script) {
        return if $_{nonexistent_is_okay};
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
            elsif ($step =~ m/[\/\.]/) {
                my @statements = $self->generate($step);
                $connection->run(@statements);
            }
            else {
                croak "Don't understand step: $step";
            }
        }
        elsif (ref $step eq 'SCALAR') {
            my @statements = $self->generate($step);
            $connection->run(@statements);
        }
        elsif (ref $step eq 'CODE') {
            $step->($self, \@script);
        }
        elsif (ref $step eq 'ARRAY') {
            for (@$step) {
                my @statements = $self->generate($step);
                $connection->run(@statements);
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

sub created {
    my $self = shift;
    return 1; # Safest to do nothing
}

sub populated {
    my $self = shift;
    return 1; # Safest to do nothing
}

sub _superdatabase_or_super_or_user_connection {
    my $self = shift;
    for (qw/superdatabase superuser user/) {
        return $self->connection($_) if $self->stash->{connection}->{$_};
    }
    croak "Urgh, don't have any connection to return";
}

sub create {
    my $self = shift;
    return $self->run_script("create", nonexistent_is_okay => 1, @_);
}

sub populate {
    my $self = shift;
    return $self->run_script("populate", nonexistent_is_okay => 1, @_);
}

sub setup {
    my $self = shift;
    return $self->run_script("setup", nonexistent_is_okay => 1, connection => $self->_superdatabase_or_super_or_user_connection, @_);
}

sub teardown {
    my $self = shift;
    return $self->run_script("teardown", nonexistent_is_okay => 1, connection => $self->_superdatabase_or_super_or_user_connection, @_);
}

sub deploy {
    my $self = shift;

    if ($self->exists) {
        if ($self->created) {
            unless ($self->populated) {
                $self->populate;
            }
        }
        else {
            $self->create;
            $self->populate;
        }
    }
    else {
        $self->setup;
        $self->create;
        $self->populate;
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
