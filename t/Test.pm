package t::Test;

use strict;
use warnings;

use DBIx::Deploy;
use DBIx::Deploy::Engine::PostgreSQL;
use DBIx::Deploy::Engine::SQLite;
use Directory::Scratch;
use Carp;

sub scratch {
    return Directory::Scratch->new;
}

sub get_superdatabase {
    my $superdatabase = $ENV{TEST_DBIx_Deploy_PostgreSQL_superdatabase} or croak "Erg, no superdatabase in environment";
    $superdatabase = "template1:postgres" if $superdatabase =~ m/^default$/i;
    return split m/:/, $superdatabase;
}

sub get_user {
    my $user = $ENV{TEST_DBIx_Deploy_PostgreSQL_user} or croak "Erg, no user in environment";
    $user = "_deploy:_deployusername:_deploypassword" if $user =~ m/^default$/i;
    return split m/:/, $user;
}

our (@superdatabase, @user);
eval {
    @superdatabase = t::Test->get_superdatabase;
    @user = t::Test->get_user;
};

sub no_PostgreSQL_reason {
    return <<_END_
Can't test PostgreSQL functionality without setting: TEST_DBIx_Deploy_PostgreSQL_superdatabase and TEST_DBIx_Deploy_PostgreSQL_user ...
TEST_DBIx_Deploy_PostgreSQL_superdatabase is usually, "template1:postgres"
TEST_DBIx_Deploy_PostgreSQL_user is something like, "_deploy:_deployusername:_deploypassword"
_END_
}

sub can_PostgreSQL {
    return @superdatabase && @user;
}

package t::Test::PostgreSQL;

sub deploy {
    return DBIx::Deploy::Engine::PostgreSQL->new(configure => {

    superdatabase => \@superdatabase,

    user => {
        database => $user[0],
        username => $user[1],
        password => $user[2],
    },

    setup => [ \<<_END_ ],
CREATE USER [% connection.username %] WITH PASSWORD '[% connection.password %]';
--
CREATE DATABASE [% connection.database %] WITH TEMPLATE template0 OWNER = [% connection.username %];
--
_END_

    teardown => [ \<<_END_ ],
DROP DATABASE [% connection.database %];
--
DROP USER [% connection.username %];
_END_

    database_exists => "deploy_test",
    create => \<<_END_,
CREATE TABLE deploy_test (
    hello_world     TEXT
);
--
_END_

    schema_exists => "deploy_test",
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
            database => (t::Test->scratch->tempfile)[1],
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

    superdatabase => \@superdatabase,

    user => {
        database => $user[0],
        username => $user[1],
        password => $user[2],
    },

    setup => [ \<<_END_ ],
CREATE USER [% connection.username %] WITH PASSWORD '[% connection.password %]';
--
CREATE DATABASE [% connection.database %] WITH TEMPLATE template0 OWNER = [% connection.username %];
--
_END_

    teardown => [ \<<_END_ ],
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
