#!perl -w

use strict;

use Test::More qw/no_plan/;
use Test::Deep;
use t::Test;

{
    my $database = (t::Test->scratch->tempfile)[1];
    my $deploy = DBIx::Deploy->create(
        engine => 'SQLite',
        configure => {
            database => $database,
            create => "t/assets",
            populate => "t/assets",
        },
    );

    is(-s $database, 0);

    $deploy->deploy;

    is($deploy->connection->dbh->selectrow_hashref(qq/SELECT count(*) AS count FROM deploy_test WHERE hello_world = 'bye world'/)->{count}, 1);

    ok(-s $database);

    $deploy->teardown;

    ok(! -f $database);
}

{
    use DBIx::Deploy::SQLite;

    my $database = (t::Test->scratch->tempfile)[1];
    my $deploy = DBIx::Deploy::SQLite->new($database, "t/assets");

    is(-s $database, 0);

    $deploy->deploy;

    is($deploy->connection->dbh->selectrow_hashref(qq/SELECT count(*) AS count FROM deploy_test WHERE hello_world = 'bye world'/)->{count}, 1);

    ok(-s $database);

    $deploy->teardown;

    ok(! -f $database);
}
