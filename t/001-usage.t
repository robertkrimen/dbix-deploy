#!perl -w

use strict;

use Test::More qw/no_plan/;
use Test::Deep;
use t::Test;

{
    my $deploy = DBIx::Deploy->create(

        engine => "PostgreSQL",

        configure => {

            connection => {
                superuser => [ qw/template1 postgres/ ],

                user => {
                    database => "deploy",
                    username => "deploy",
                    password => "deploy",
                },
            },

            setup => [ qw/superuser/, \<<_END_ ],
CREATE DATABASE [% connection.database %] WITH TEMPLATE template0;
--
CREATE USER [% connection.username %] WITH PASSWORD '[% connection.password %]';
_END_

            teardown => [ qw/superuser/, \<<_END_ ],
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

    $deploy->teardown;

    ok(1);
}

{
    my $deploy = DBIx::Deploy->create(

        engine => "+t::Test::Deploy::PostgreSQL",

    );

    $deploy->setup;

    $deploy->create;

    $deploy->teardown;

    ok(1);
}
