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
    return Template->new;
};

has stash => qw/is ro/;

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
    my $step = shift;
    my $context = shift || {};

    $self->_generate_prepare_context($context);

    my $input = $self->stash->{$step} or croak "Don't have a script for $step";
    my $script = $self->_template_process($input, $context);

    return $script unless wantarray;

    $self->script->read($script);
    my @statements = $self->script->statements;
    return @statements;
}

sub run_script {
    my $self = shift;
    my $step = shift;
    my $connection = shift || $self->connection;

    my @statements = $self->generate($step);
    $connection->run(@statements);
}

sub _generate_prepare_context {
    my $self = shift;
    my $context = shift;

    $context->{engine} = $self;
    $context->{connection} = $self->connection;
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
    return $self->run_script("create", @_);
}

sub populate {
    my $self = shift;
    return $self->run_script("populate", @_) if $self->stash->{populate};
}

sub setup {
    my $self = shift;
}

sub teardown {
    my $self = shift;
}

sub deploy {
    my $self = shift;

    my $connection = $self->connection;

    if ($connection->connectable) {
        if ($self->created($connection)) {
            unless ($self->populated($connection)) {
                $self->populate;
            }
        }
        else {
            $self->create;
            $self->populate;
        }
        $connection->disconnect;
    }
    else {
        $self->setup;
        $self->create;
        $self->populate;
    }

    return $connection->information;
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
