package DBIx::Deploy::MySQL;

use strict;
use warnings;

use DBIx::Deploy::Engine::MySQL;

sub new {
    my $class = shift;

    my $cfg = {};
    $cfg = pop if @_ && ref $_[@_ - 1] eq "HASH";

    defined $_[0] ? $cfg->{superdatabase} = shift : shift if @_;
    defined $_[0] ? $cfg->{user} = shift : shift if @_;
    if (@_) {
        my $from = shift;
        for (qw/setup teardown create populate/) {
            $cfg->{$_} = "?$from" unless exists $cfg->{$_};
        }
    }
    
    return DBIx::Deploy::Engine::MySQL->new(configure => $cfg);
}

1;
