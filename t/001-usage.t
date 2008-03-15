#!perl -w

use strict;

use Test::More qw/no_plan/;
use Test::Deep;
use t::Test;

SKIP: {
    skip(t::Test->no_PostgreSQL_reason) unless t::Test->can_PostgreSQL;

    my @superdatabase = t::Test->get_superdatabase;
    my @user = t::Test->get_user;

    my $deploy = DBIx::Deploy->create(

        engine => "PostgreSQL",

        configure => {

            connection => {
                superuser => \@superdatabase,

                user => {
                    database => $user[0],
                    username => $user[1],
                    password => $user[2],
                },
            },

            setup => \<<_END_,
CREATE DATABASE [% connection.database %] WITH TEMPLATE template0;
--
CREATE USER [% connection.username %] WITH PASSWORD '[% connection.password %]';
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

            populate => \<<_END_,
INSERT INTO deploy_test VALUES ('bye world');
--
_END_
        },

    );

    $deploy->setup;

    $deploy->create;

    sleep 1; # Wait a second for the disconnect to propagate

    $deploy->teardown;

    ok(1);
}

SKIP: {
    skip(t::Test->no_PostgreSQL_reason) unless t::Test->can_PostgreSQL;
    my $deploy = DBIx::Deploy->create(

        engine => "+t::Test::Deploy::PostgreSQL",

    );

    $deploy->setup;

    $deploy->create;

    sleep 1; # Wait a second for the disconnect to propagate

    $deploy->teardown;

    ok(1);
}

SKIP: {
    skip(t::Test->no_PostgreSQL_reason) unless t::Test->can_PostgreSQL;
    my @superdatabase = t::Test->get_superdatabase;
    my @user = t::Test->get_user;

    my $deploy = DBIx::Deploy->create(

        engine => "PostgreSQL",

        configure => {

            superuser => \@superdatabase,

            user => {
                database => $user[0],
                username => $user[1],
                password => $user[2],
            },

            qw(
                setup t/assets/setup.tt.sql
                teardown t/assets/teardown.tt.sql
                create t/assets/create.tt.sql
                populate t/assets/populate.tt.sql
            ),
        },

    );

    $deploy->setup;

    $deploy->create;

    sleep 1; # Wait a second for the disconnect to propagate

    $deploy->teardown;

    ok(1);
}
