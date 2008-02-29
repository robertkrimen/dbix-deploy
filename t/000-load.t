#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'DBIx::Deploy' );
}

diag( "Testing DBIx::Deploy $DBIx::Deploy::VERSION, Perl $], $^X" );
