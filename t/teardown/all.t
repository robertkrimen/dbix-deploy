#!perl -w

use strict;

use Test::More qw/no_plan/;
use Test::Deep;
use DBIx::Deploy::Engine::PostgreSQL;

my $deploy = DBIx::Deploy::Engine::PostgreSQL->new(configure => {
    sutd_connection => [ qw/template1 postgres/ ],

    connection => {
        database => "deploy",
        username => "deploy",
    },

    teardown => \<<_END_,
DROP DATABASE [% connection.database %];
--
DROP USER [% connection.username %];
_END_
});

ok($deploy);

$deploy->teardown;
