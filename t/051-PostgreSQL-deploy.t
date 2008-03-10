#!perl -w

use strict;

use Test::More qw/no_plan/;
use Test::Deep;
use t::Test;

my $deploy = t::Test::PostgreSQL->deploy;
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
