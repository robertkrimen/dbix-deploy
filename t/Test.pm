package t::Test;

use strict;
use warnings;

use DBIx::Deploy;
use DBIx::Deploy::Engine::PostgreSQL;
use DBIx::Deploy::Engine::SQLite;
use DBIx::Deploy::Engine::MySQL;
use Directory::Scratch;
use Carp;

sub scratch {
    return Directory::Scratch->new;
}

sub get_PostgreSQL_superdatabase {
    my $superdatabase = $ENV{TEST_DBIx_Deploy_PostgreSQL_superdatabase} or croak "Erg, no superdatabase in environment";
    $superdatabase = "template1:postgres" if $superdatabase =~ m/^default$/i;
    return split m/:/, $superdatabase;
}

sub get_PostgreSQL_user {
    my $user = $ENV{TEST_DBIx_Deploy_PostgreSQL_user} or croak "Erg, no user in environment";
    $user = "_deploy:_deployusername:_deploypassword" if $user =~ m/^default$/i;
    return split m/:/, $user;
}

sub get_MySQL_superdatabase {
    my $superdatabase = $ENV{TEST_DBIx_Deploy_MySQL_superdatabase} or croak "Erg, no superdatabase in environment";
    $superdatabase = "mysql:root" if $superdatabase =~ m/^default$/i;
    return split m/:/, $superdatabase;
}

sub get_MySQL_user {
    my $user = $ENV{TEST_DBIx_Deploy_MySQL_user} or croak "Erg, no user in environment";
    $user = "_deploy:_deployusername:_deploypassword" if $user =~ m/^default$/i;
    return split m/:/, $user;
}

our (@PostgreSQL_superdatabase, @PostgreSQL_user);
our (@MySQL_superdatabase, @MySQL_user);
eval {
    @PostgreSQL_superdatabase = t::Test->get_PostgreSQL_superdatabase;
    @PostgreSQL_user = t::Test->get_PostgreSQL_user;
};
eval {
    @MySQL_superdatabase = t::Test->get_MySQL_superdatabase;
    @MySQL_user = t::Test->get_MySQL_user;
};

sub no_MySQL_reason {
    return <<_END_
Can't test MySQL functionality without setting: TEST_DBIx_Deploy_MySQL_superdatabase and TEST_DBIx_Deploy_MySQL_user ...
TEST_DBIx_Deploy_MySQL_superdatabase is usually, "mysql:root"
TEST_DBIx_Deploy_MySQL_user is something like, "_deploy:_deployusername:_deploypassword"
_END_
}

sub can_MySQL {
    return @MySQL_superdatabase && @MySQL_user;
}

sub no_PostgreSQL_reason {
    return <<_END_
Can't test PostgreSQL functionality without setting: TEST_DBIx_Deploy_PostgreSQL_superdatabase and TEST_DBIx_Deploy_PostgreSQL_user ...
TEST_DBIx_Deploy_PostgreSQL_superdatabase is usually, "template1:postgres"
TEST_DBIx_Deploy_PostgreSQL_user is something like, "_deploy:_deployusername:_deploypassword"
_END_
}

sub can_PostgreSQL {
    return @PostgreSQL_superdatabase && @PostgreSQL_user;
}

package t::Test::PostgreSQL;

sub deploy {
    return DBIx::Deploy::Engine::PostgreSQL->new(configuration => {

    superdatabase => \@PostgreSQL_superdatabase,

    user => {
        database => $PostgreSQL_user[0],
        username => $PostgreSQL_user[1],
        password => $PostgreSQL_user[2],
    },

    setup => [ \<<_END_ ],
CREATE USER [% user.username %] WITH PASSWORD '[% user.password %]';
--
CREATE DATABASE [% user.database %] WITH TEMPLATE template0 OWNER = [% user.username %];
--
_END_

    teardown => [ \<<_END_ ],
DROP DATABASE [% user.database %];
--
DROP USER [% user.username %];
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
    return DBIx::Deploy::Engine::SQLite->new(configuration => {

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

package t::Test::MySQL;


sub deploy {
    return DBIx::Deploy::Engine::MySQL->new(configuration => {

    superdatabase => \@MySQL_superdatabase,

    user => {
        database => $MySQL_user[0],
        username => $MySQL_user[1],
        password => $MySQL_user[2],
    },

    setup => [ \<<_END_ ],
CREATE DATABASE [% user.database %];
--
GRANT ALL ON [% user.database %].* TO [% user.username %] IDENTIFIED BY '[% user.password %]';
--
_END_

    teardown => [ \<<_END_ ],
DROP DATABASE [% user.database %];
--
DROP USER [% user.username %];
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
}

1;

package t::Test::Deploy::PostgreSQL;

use Moose;

extends qw/DBIx::Deploy::Engine::PostgreSQL/;

__PACKAGE__->configure({

    superdatabase => \@PostgreSQL_superdatabase,

    user => {
        database => $PostgreSQL_user[0],
        username => $PostgreSQL_user[1],
        password => $PostgreSQL_user[2],
    },

    setup => [ \<<_END_ ],
CREATE USER [% user.username %] WITH PASSWORD '[% user.password %]';
--
CREATE DATABASE [% user.database %] WITH TEMPLATE template0 OWNER = [% user.username %];
--
_END_

    teardown => [ \<<_END_ ],
DROP DATABASE [% user.database %];
--
DROP USER [% user.username %];
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
