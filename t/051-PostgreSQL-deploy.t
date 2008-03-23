use strict;
use warnings;

use Test::More;
use Test::Deep;
use t::Test;

plan qw/skip_all/ => t::Test->no_PostgreSQL_reason and exit unless t::Test->can_PostgreSQL;
plan qw/no_plan/;

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

eval {
    my $dbh = $deploy->connection->connect;
    my $value;
    $value = $dbh->selectrow_arrayref('SELECT COUNT(*) FROM deploy_test')->[0];
    is($value, 1);
    $value = $dbh->selectrow_arrayref('SELECT * FROM deploy_test')->[0];
    is($value, "bye world");
    $dbh->disconnect;
};
ok(!$@);

sleep 1; # Wait a second for the disconnect to propagate

$deploy->teardown;

ok(! $deploy->connection->connectable);

1;
