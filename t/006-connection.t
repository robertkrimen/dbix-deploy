#!perl -w

use strict;

use Test::Most;
use t::Test;

plan qw/no_plan/;

my $engine = DBIx::Deploy::Engine->new;
my $connection;

$connection = DBIx::Deploy::Connection->parse([ qw/database|mysql/ ], $engine, qw/user/);
is($connection->source, "dbi:mysql:dbname=database");

$connection = DBIx::Deploy::Connection->parse([ qw/database|pg/ ], $engine, qw/user/);
is($connection->source, "dbi:Pg:dbname=database");

$connection = DBIx::Deploy::Connection->parse([ qw/database|PoStgres/ ], $engine, qw/user mysql/);
is($connection->source, "dbi:Pg:dbname=database");

$connection = DBIx::Deploy::Connection->parse([ qw/database|A-very-strange-%database-source/ ], $engine, qw/user mysql/);
is($connection->source, "A-very-strange-database-source");
