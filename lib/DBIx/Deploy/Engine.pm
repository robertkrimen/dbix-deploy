package DBIx::Deploy::Engine;

use warnings;
use strict;

use Moose;
use base qw/Class::Data::Inheritable/;

use Template;
use SQL::Script;
use Carp;

__PACKAGE__->mk_classdata(qw/_configure/);

sub driver {
    my $self = shift;
    croak "Don't have a driver for $self";
}

has script => qw/is ro required 1 lazy 1/, default => sub {
    return SQL::Script->new(split_by => qr/\n--\n/);
};

has template => qw/is ro required 1 lazy 1/, default => sub {
    return Template->new;
};

sub BUILD {
    my $self = shift;
    my $new = shift;
    $self->{configure} = $new->{configure};
    return $self;
}

sub generate {
    my $self = shift;
    my $step = shift;
    my $context = shift || {};

    $self->_generate_prepare_context($context);

    my $script = $self->_template_process($self->{configure}->{$step}, $context);

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
    my $dbh = $connection->connect;
    for (@statements) {
        chomp;
        warn "$_\n" if 1;
        $dbh->do($_) or die $dbh->errstr;
    }
    $dbh->disconnect;
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
    return $self->run_script("populate", @_) if $self->{configure}->{populate};
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
        my $dbh = $connection->connect;
        if ($self->created($connection, $dbh)) {
            unless ($self->populated($connection, $dbh)) {
                $self->populate;
            }
        }
        else {
            $self->create;
            $self->populate;
        }
        $dbh->disconnect;
    }
    else {
        $self->setup;
        $self->create;
        $self->populate;
    }

    return $connection->information;
}

1;
