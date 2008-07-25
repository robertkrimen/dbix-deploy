use strict;
use warnings;

use Test::More;
use Test::Deep;
use t::Test;

plan qw/skip_all/ => t::Test->no_MySQL_reason and exit unless t::Test->can_MySQL;
plan qw/no_plan/;

my @superdatabase = t::Test->get_MySQL_superdatabase;
my @user = t::Test->get_MySQL_user;

my $deploy = t::Test::MySQL->deploy;
ok($deploy);

my $setup = sub { $deploy->generate_SQL($deploy->_script->{setup}->[0]->command->arguments->{sql}) };
is(${ $setup->() }, <<_END_);
CREATE DATABASE $user[0];
--
GRANT ALL ON $user[0].* TO $user[1] IDENTIFIED BY '$user[2]';
--
_END_
cmp_deeply([ $setup->() ], [
    "CREATE DATABASE $user[0];",
    "GRANT ALL ON $user[0].* TO $user[1] IDENTIFIED BY '$user[2]';",
]);


my $teardown = sub { $deploy->generate_SQL($deploy->_script->{teardown}->[0]->command->arguments->{sql}) };
is(${ $teardown->() }, <<_END_);
DROP DATABASE $user[0];
--
DROP USER $user[1];
_END_
cmp_deeply([ $teardown->() ], [
    "DROP DATABASE $user[0];",
    "DROP USER $user[1];",
]);

my $create = sub { $deploy->generate_SQL($deploy->_script->{create}->[0]->command->arguments->{sql}) };
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
