package DBIx::Deploy::Command;

use warnings;
use strict;

use Moose;
use DBIx::Deploy::Carp;

has name => qw/is ro required 1/;
has code => qw/is ro isa CodeRef/, default => sub {
    my $self = shift;
    return $self->_code;
};
has arguments => qw/is ro required 1 isa HashRef/, default => sub { {} };

{
    my %code = (

        sqlfile => sub {
            my $self = shift;
            my $context = shift;

            my $file = $self->arguments->{file};
            my $flags = $self->arguments->{flags};
            $flags = "" unless defined $flags;

            if (-d $file) {
                my $stage = $context->stage;
                $file = "$file/$stage";
                $flags .= "*";
            }

            if ($flags =~ m/\*/) {
                my $_file;

                for ("", qw/.sql .tt2.sql .tt.sql .tt2 .tt/) {
                    $_file = "$file$_";
                    last if -f $_file;
                    undef $_file;
                }

                $file = $_file;
            }

            return if $flags =~ m/\?/ && ! $file || ! -f $file;

            croak "Don't have file" unless $file;
            croak "File $file doesn't exist" unless -f $file;

            $context->engine->run($file, $context);
        },

        sql => sub {
            my $self = shift;
            my $context = shift;

            $context->engine->run($self->arguments->{sql}, $context);
        },

        code => sub {
            my $self = shift;
            my $context = shift;

            my $code = $self->arguments->{code};

            $code->($context);
        },

    );

    sub _code {
        my $self = shift;
        my $name = shift || $self->name;

        croak "Wasn't given a name" unless $name;

        my $code = $code{$name} or croak "Couldn't find code for $name";

        return $code;
    }
}

sub execute {
    my $self = shift;
    my $context = shift;

    $context->stash->{command} = $self;

    $self->code->($self, $context);
}

sub Parse {
    my $self = shift;
    my $class = ref $self || $self;
    my $command = shift;

    croak "Wasn't given a command to parse" unless $command;

    my %parse;
    if (ref $command eq 'SCALAR') {
        %parse = (qw/name sql/, sql => $command);
    }
    elsif (ref $command eq 'CODE') {
        %parse = (qw/name code/, code => $command);
    }
    elsif (ref $command eq 'HASH') {
        croak "Don't have a name for command" unless $command->{name};
        %parse = %$command;
    }
    elsif (! ref $command) {
        if ($command =~ s/^(sqlfile):([^:]+:)?//) {
            %parse = (name => $1, flags => $2, file => $command);
        }
        elsif ($command =~ s/^(sqldir):([^:]+:)?//) {
            %parse = (name => $1, flags => $2, file => $command);
        }
        elsif ($command =~ s{/\*$}{}) {
            %parse = (qw/name sqldir/, dir => $command); 
        }
        else {
            %parse = (qw/name sqlfile/, file => $command); 
        }
    }
    else {
        croak "Don't understand command: $command";
    }

    return $class->new(name => delete $parse{name}, arguments => \%parse);
}

1;
