#!perl -w

use strict;

use Test::More qw/no_plan/;
use Test::Deep;
use t::Test;

my $deploy = t::Test::PostgreSQL->deploy;
ok($deploy);

my $setup = sub { $deploy->generate($deploy->stash->{setup}->[1]) };
is(${ $setup->() }, <<_END_);
CREATE USER deploy WITH PASSWORD 'deploy';
--
CREATE DATABASE deploy WITH TEMPLATE template0 OWNER = deploy;
--
_END_
cmp_deeply([ $setup->() ], [
    "CREATE USER deploy WITH PASSWORD 'deploy';",
    "CREATE DATABASE deploy WITH TEMPLATE template0 OWNER = deploy;",
]);


my $teardown = sub { $deploy->generate($deploy->stash->{teardown}->[1]) };
is(${ $teardown->() }, <<_END_);
DROP DATABASE deploy;
--
DROP USER deploy;
_END_
cmp_deeply([ $teardown->() ], [
    "DROP DATABASE deploy;",
    "DROP USER deploy;",
]);

my $create = sub { $deploy->generate($deploy->stash->{create}) };
is(${ $create->() }, <<_END_);
CREATE TABLE deploy_test (
    hello_world     TEXT
);
--
_END_
cmp_deeply([ $create->() ], [
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
