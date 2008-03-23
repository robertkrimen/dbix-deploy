package DBIx::Deploy::SQLite;

use strict;
use warnings;

use DBIx::Deploy::Engine::SQLite;

sub new {
    my $class = shift;

    my $cfg = {};
    $cfg = pop if @_ && ref $_[@_ - 1] eq "HASH";

    defined $_[0] ? $cfg->{database} = shift : shift if @_;
    if (@_) {
        my $from = shift;
        for (qw/create populate/) {
            $cfg->{$_} = "?$from" unless exists $cfg->{$_};
        }
    }
    
    return DBIx::Deploy::Engine::SQLite->new(configure => $cfg);
}

1;
