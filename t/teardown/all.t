#!perl -w

use strict;

use Test::More qw/no_plan/;
use Test::Deep;
use DBIx::Deploy::Engine::PostgreSQL;

my $deploy = DBIx::Deploy::Engine::PostgreSQL->new(configure => {

    connection => {
        user => [ qw/deploy deploy deploy/ ],
        superuser => [ qw/template1 postgres/ ],
    },

    teardown => [ superuser => \<<_END_ ],
DROP DATABASE [% connection.database %];
--
DROP USER [% connection.username %];
_END_
});

ok($deploy);

$deploy->teardown;
