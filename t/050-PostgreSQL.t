use strict;
use warnings;

use Test::More;
use Test::Deep;
use t::Test;

plan qw/skip_all/ => t::Test->no_PostgreSQL_reason and exit unless t::Test->can_PostgreSQL;
plan qw/no_plan/;

my @superdatabase = t::Test->get_superdatabase;
my @user = t::Test->get_user;

my $deploy = t::Test::PostgreSQL->deploy;
ok($deploy);

my $setup = sub { $deploy->generate($deploy->stash->{script}->{setup}->[0]) };
is(${ $setup->() }, <<_END_);
CREATE USER $user[1] WITH PASSWORD '$user[2]';
--
CREATE DATABASE $user[0] WITH TEMPLATE template0 OWNER = $user[1];
--
_END_
cmp_deeply([ $setup->() ], [
    "CREATE USER $user[1] WITH PASSWORD '$user[2]';",
    "CREATE DATABASE $user[0] WITH TEMPLATE template0 OWNER = $user[1];",
]);


my $teardown = sub { $deploy->generate($deploy->stash->{script}->{teardown}->[0]) };
is(${ $teardown->() }, <<_END_);
DROP DATABASE $user[0];
--
DROP USER $user[1];
_END_
cmp_deeply([ $teardown->() ], [
    "DROP DATABASE $user[0];",
    "DROP USER $user[1];",
]);

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

sleep 1; # Wait a second for the disconnect to propagate

$deploy->teardown;

1;
