package DBIx::Deploy::SQLite;

use strict;
use warnings;

use DBIx::Deploy::Engine::SQLite;

# TODO This documentation needs some clarifying

=head1 NAME

DBIx::Deploy::SQLite

=head1 SYNOPSIS

    use DBIx::Deploy::SQLite;
    use DBI:

    my $deploy = DBIx::Deploy::SQLite->new(
        [ "my_database", "my_database_user" ], [ "postgres", "template1", "password" ],
            "path/to/SQL");

    my $dbh = DBI->connect($deploy->information); # Database will deploy automatically if it doesn't exist

    # Or you can do it manually:
    
    $deploy->deploy if ! $deploy->database_exists;

head1 Database administration password

Unfortunately for now, if you need a password to log in as your database admin user (via the "superdatabase"), then you need to
embed the password into your code or configuration.

head1 METHODS

head2 my $deploy = DBIx::Deploy::SQLite->new(<user>, <superdatabase>, <path-to-SQL>, ...)

This method will return a L<DBIx::Deploy::Engine::SQLite> object that you can use to deploy your database schema.

<user> and <superdatabase> should be in the proper format to be passed to DBI connect, with the exception that the database
may be passed in name only (that is, "my_database" instead of "DBI::mysql::database=my_database")

The <path-to-SQL> argument should point to a directory on disk containing something like:

    create.sql
    populate.sql

If a file doesn't exist, then it won't be run.

Finally, any remaining arguments will be passed through to the configuration of DBIx::Deploy::Engine::SQLite

=cut
sub new {
    my $class = shift;

    my $cfg = {};
    $cfg = pop if @_ && ref $_[@_ - 1] eq "HASH";

    defined $_[0] ? $cfg->{database} = shift : shift if @_;
    if (@_) {
        my $from = shift;
        for (qw/create populate/) {
            $cfg->{$_} = "?$from" unless exists $cfg->{$_};
        }
    }
    
    return DBIx::Deploy::Engine::SQLite->new(configure => $cfg);
}

1;
