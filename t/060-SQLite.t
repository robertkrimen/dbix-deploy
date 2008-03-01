#!perl -w

use strict;

use Test::More qw/no_plan/;
use Test::Deep;
use DBIx::Deploy::Engine::SQLite;

my $deploy = DBIx::Deploy::Engine::SQLite->new(configure => {
    connection => {
        database => "./deploy.db",
    },

    create => \<<_END_,
CREATE TABLE deploy_test (
    hello_world     TEXT
);
--
_END_
});

ok($deploy);

is(${ $deploy->generate("create") }, <<_END_);
CREATE TABLE deploy_test (
    hello_world     TEXT
);
--
_END_
cmp_deeply([ $deploy->generate("create") ], [
    (local $_ = <<_END_) && chomp && $_,
CREATE TABLE deploy_test (
    hello_world     TEXT
);
_END_
]);

$deploy->setup;

$deploy->create;

$deploy->teardown;

1;
