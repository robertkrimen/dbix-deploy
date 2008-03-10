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
        $self->stash->{connection_class}->parse($self, $self->stash->{connection}->{$name});
    };
}

sub BUILD {
    my $self = shift;
    my $new = shift;
    my $configure = $new->{configure} || {};
    my $stash = $self->configure($configure);
    $self->{stash} = $stash;
    return $self;
}

sub generate {
    my $self = shift;
    my $input = shift;
    my $context = shift || {};

    $self->_generate_prepare_context($context);

    croak "Don't have a template" unless $input;
    croak "Don't understand template \"$input\"" unless ref $input eq "SCALAR";
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

    my @script;
    croak "Don't have a script called $name" unless my $script = $self->stash->{$name};
    if (ref $script eq "ARRAY") {
        @script = @$script;
    }
    else {
        @script = (qw/user/, $script);
    }

    while (@script) {
        croak "A null step in script \"$name\"?" unless my $step = shift @script;
        if (ref $step eq "SCALAR") {
            unshift @script, $step;
            $step = "user";
        }
        if (ref $step eq "") {
            my $connection = $self->connection($step);
            my @statements = $self->generate(shift @script);
            $connection->run(@statements);
        }
        elsif (ref $step eq "ARRAY") {
            my ($database, $username, $password, $attributes) = @$step;
            $database = $self->connection($1)->database if $database && $database =~ m/^\$(.*)$/;
            $username = $self->connection($1)->username if $username && $username =~ m/^\$(.*)$/;
            $password = $self->connection($1)->password if $password && $password =~ m/^\$(.*)$/;
            $attributes = $self->connection($1)->attributes if $attributes && $attributes =~ m/^\$(.*)$/;
            my $connection = $self->stash->{connection_class}->parse($self, [ $database, $username, $password, $attributes ]);
            my @statements = $self->generate(shift @script);
            $connection->run(@statements);
        }
        elsif (ref $step eq "CODE") {
            $step->($self, \@script);
        }
        else {
            croak "Don't understand script step $step";
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

sub create {
    my $self = shift;
    return $self->run_script("create", @_) if $self->stash->{create};
}

sub populate {
    my $self = shift;
    return $self->run_script("populate", @_) if $self->stash->{populate};
}

sub setup {
    my $self = shift;
    return $self->run_script("setup", @_) if $self->stash->{setup};
}

sub teardown {
    my $self = shift;
    return $self->run_script("teardown", @_) if $self->stash->{teardown};
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
