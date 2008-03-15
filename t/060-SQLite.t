#!perl -w

use strict;

use Test::More qw/no_plan/;
use Test::Deep;
use t::Test;

my $deploy = t::Test::SQLite->deploy;
ok($deploy);

my $create = sub { $deploy->generate($deploy->stash->{script}->{create}) };
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
