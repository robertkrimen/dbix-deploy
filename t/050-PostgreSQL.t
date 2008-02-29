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

    setup => \<<_END_,
CREATE DATABASE [% connection.database %];
--
CREATE USER [% connection.username %];
_END_

    teardown => \<<_END_,
DROP DATABASE [% connection.database %];
--
DROP USER [% connection.username %];
_END_

    create => \<<_END_,
CREATE TABLE deploy_test (
    hello_world     TEXT
);
--
_END_
});

ok($deploy);

is(${ $deploy->generate("setup") }, <<_END_);
CREATE DATABASE deploy;
--
CREATE USER deploy;
_END_
cmp_deeply([ $deploy->generate("setup") ], [
    "CREATE DATABASE deploy;",
    "CREATE USER deploy;",
]);

is(${ $deploy->generate("teardown") }, <<_END_);
DROP DATABASE deploy;
--
DROP USER deploy;
_END_
cmp_deeply([ $deploy->generate("teardown") ], [
    "DROP DATABASE deploy;",
    "DROP USER deploy;",
]);

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

{
    my $dbh = $deploy->sutd_connection->connect;
    ok($dbh);

    for ($deploy->generate("teardown")) {
        $dbh->do($_) or die $dbh->errstr;
    }

    for ($deploy->generate("setup")) {
        $dbh->do($_) or die $dbh->errstr;
    }

    $dbh->disconnect;
}

{
    my $dbh = $deploy->connection->connect;
    ok($dbh);

    for ($deploy->generate("create")) {
        $dbh->do($_) or die $dbh->errstr;
    }

    $dbh->disconnect;
}

1;
