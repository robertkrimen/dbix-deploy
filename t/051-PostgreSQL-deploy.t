#!perl -w

use strict;

use Test::More qw/no_plan/;
use Test::Deep;
use t::Test;

my $deploy = t::Test::PostgreSQL->deploy;
ok($deploy);

#my $deploy = DBIx::Deploy::Engine::PostgreSQL->new(configure => {
#    sutd_connection => [ qw/template1 postgres/ ],

#    connection => {
#        database => "deploy",
#        username => "deploy",
#    },

#    setup => \<<_END_,
#CREATE DATABASE [% connection.database %];
#--
#CREATE USER [% connection.username %];
#_END_

#    teardown => \<<_END_,
#DROP DATABASE [% connection.database %];
#--
#DROP USER [% connection.username %];
#_END_

#    create => \<<_END_,
#CREATE TABLE deploy_test (
#    hello_world     TEXT
#);
#--
#_END_

#    populate => \<<_END_,
#INSERT INTO deploy_test VALUES ('bye world');
#--
#_END_
#});

ok($deploy);

ok(! $deploy->connection->connectable);

$deploy->deploy;

ok($deploy->connection->connectable);

$deploy->teardown;

ok(! $deploy->connection->connectable);

$deploy->setup;

ok($deploy->connection->connectable);

$deploy->deploy;

{
    my $dbh = $deploy->connection->connect;
    my $value;
    $value = $dbh->selectrow_arrayref('SELECT COUNT(*) FROM deploy_test')->[0];
    is($value, 1);
    $value = $dbh->selectrow_arrayref('SELECT * FROM deploy_test')->[0];
    is($value, "bye world");
    $dbh->disconnect;
}

$deploy->teardown;

ok(! $deploy->connection->connectable);

1;
