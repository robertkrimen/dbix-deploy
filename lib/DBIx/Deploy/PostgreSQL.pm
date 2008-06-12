package DBIx::Deploy::PostgreSQL;

use strict;
use warnings;

use DBIx::Deploy::Engine::PostgreSQL;

=head1 NAME

DBIx::Deploy::PostgreSQL

=head1 SYNOPSIS

    use DBIx::Deploy::PostgreSQL;
    use DBI:

    my $deploy = DBIx::Deploy::PostgreSQL->new(
        [ "my_database", "my_database_user" ], [ "postgres", "template1", "<" ],
            "path/to/SQL");

    my $dbh = DBI->connect($deploy->information); # Database will deploy automatically if it doesn't exist

    # Or you can do it manually:
    
    $deploy->deploy if ! $deploy->database_exists;

=head1 Database administration password

If you need a password to log in as your database admin user, you can either embed the password into your code/configuration or use the special value "<".
If "<" is set, then DBIx::Deploy will prompt via STDIN/STDOUT for the password.

=head1 METHODS

=head2 my $deploy = DBIx::Deploy::PostgreSQL->new( <user>, <superdatabase>, <directory>, ... )

This method will return a L<DBIx::Deploy::Engine::PostgreSQL> object that you can use to deploy your database schema.

<user> and <superdatabase> should be in the proper format to be passed to DBI connect, with the exception that the database
may be passed in name only (that is, "my_database" instead of "dbi:Pg:dname=my_database")

The <directory> argument should point to a directory on disk containing something like:

    setup.sql
    create.sql
    populate.sql
    teardown.sql

If a file doesn't exist, then it won't be run.

Finally, any remaining arguments will be passed through to the configuration of L<DBIx::Deploy::Engine>

=cut

sub new {
    my $class = shift;

    my $cfg = {};
    $cfg = pop if @_ && ref $_[@_ - 1] eq "HASH";

    defined $_[0] ? $cfg->{user} = shift : shift if @_;
    defined $_[0] ? $cfg->{superdatabase} = shift : shift if @_;
    if (@_) {
        my $from = shift;
        for (qw/setup teardown create populate/) {
            $cfg->{$_} = "?$from" unless exists $cfg->{$_};
        }
    }
    
    return DBIx::Deploy::Engine::PostgreSQL->new(configure => $cfg);
}

1;
