#!perl -w

use strict;

use Test::More qw/no_plan/;
use Test::Deep;
use DBIx::Deploy::Engine::PostgreSQL;

my $deploy = DBIx::Deploy::Engine::PostgreSQL->new(configure => {

    user => [ qw/deploy deploy deploy/ ],
    superdatabase => [ qw/template1 postgres/ ],

    teardown => \<<_END_,
DROP DATABASE [% connection.database %];
--
DROP USER [% connection.username %];
_END_
});

ok($deploy);

$deploy->teardown;

$deploy = DBIx::Deploy::Engine::MySQL->new(configure => {

    user => [ qw/deploy deploy deploy/ ],
    superdatabase => [ qw/template1 postgres/ ],

    teardown => \<<_END_,
DROP DATABASE [% connection.database %];
--
DROP USER [% connection.username %];
_END_
});
