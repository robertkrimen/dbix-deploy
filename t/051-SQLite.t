#!perl -w

use strict;

use Test::More qw/no_plan/;
use Test::Deep;
use DBIx::Deploy::Engine::SQLite;

unlink "./deploy.db" or warn $!;

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

{
    my $dbh = $deploy->connection->connect;
    ok($dbh);

    for ($deploy->generate("create")) {
        $dbh->do($_) or die $dbh->errstr;
    }

    $dbh->disconnect;
}

1;
