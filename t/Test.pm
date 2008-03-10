package t::Test;

use strict;
use warnings;

use DBIx::Deploy;
use DBIx::Deploy::Engine::PostgreSQL;
use DBIx::Deploy::Engine::SQLite;

package t::Test::PostgreSQL;

sub deploy {
    return DBIx::Deploy::Engine::PostgreSQL->new(configure => {
    connection => {
        superuser => [ qw/template1 postgres/ ],

        user => {
            database => "deploy",
            username => "deploy",
            password => "deploy",
        },
    },

    setup => [ qw/superuser/ => \<<_END_ ],
CREATE USER [% connection.username %] WITH PASSWORD 'deploy';
--
CREATE DATABASE [% connection.database %] WITH TEMPLATE template0 OWNER = [% connection.username %];
--
_END_

    teardown => [ qw/superuser/ => \<<_END_ ],
DROP DATABASE [% connection.database %];
--
DROP USER [% connection.username %];
_END_

    created => "deploy_test",
    create => \<<_END_,
CREATE TABLE deploy_test (
    hello_world     TEXT
);
--
_END_

    populated => "deploy_test",
    populate => \<<_END_,
INSERT INTO deploy_test VALUES ('bye world');
--
_END_
    });
}

package t::Test::SQLite;

sub deploy {
    return DBIx::Deploy::Engine::SQLite->new(configure => {
    connection => {
        user => {
            database => "./deploy.db",
        },
    },

    create => \<<_END_,
CREATE TABLE deploy_test (
    hello_world     TEXT
);
--
_END_
    });
}

1;

package t::Test::Deploy::PostgreSQL;

use Moose;

extends qw/DBIx::Deploy::Engine::PostgreSQL/;

__PACKAGE__->configure({
    connection => {
        superuser => [ qw/template1 postgres/ ],

        user => {
            database => "deploy",
            username => "deploy",
            password => "deploy",
        },
    },

    setup => [ qw/superuser/ => \<<_END_ ],
CREATE USER [% connection.username %] WITH PASSWORD 'deploy';
--
CREATE DATABASE [% connection.database %] WITH TEMPLATE template0 OWNER = [% connection.username %];
--
_END_

    teardown => [ qw/superuser/ => \<<_END_ ],
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
});

1;
