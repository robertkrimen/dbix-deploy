package DBIx::Deploy::MySQL;

use strict;
use warnings;

use DBIx::Deploy::Engine::MySQL;

=head1 NAME

DBIx::Deploy::MySQL

=head1 SYNOPSIS

    use DBIx::Deploy::MySQL;
    use DBI:

    my $deploy = DBIx::Deploy::MySQL->new(
        [ "my_database", "my_database_user" ], [ "postgres", "template1", "password" ],
            "path/to/SQL", { ... });

    my $dbh = DBI->connect($deploy->information); # Database will deploy automatically if it doesn't exist

    # Or you can do it manually:
    
    $deploy->deploy if ! $deploy->database_exists;

=head1 Database administration password

If you need a password to log in as your database admin user, you can either embed the password into your code/configuration or use the special value "<".
If "<" is set, then DBIx::Deploy will prompt via STDIN/STDOUT for the password.

=head1 METHODS

=head2 my $deploy = DBIx::Deploy::MySQL->new( <user>, <superdatabase>, <directory>, ... )

This method will return a L<DBIx::Deploy::Engine::MySQL> object that you can use to deploy your database schema.

<user> and <superdatabase> should be in the proper format to be passed to DBI connect, with the exception that the database
may be passed in name only (that is, "my_database" instead of "DBI:mysql:database=my_database")

The <directory> argument should point to a directory on disk containing something like:

    <directory>/setup.sql
    <directory>/create.sql
    <directory>/populate.sql
    <directory>/teardown.sql

If a file doesn't exist, then it won't be run.

Finally, the content of the trailing (optional) HASH reference will be passed through to the configuration of L<DBIx::Deploy::Engine>

=cut

sub new {
    my $class = shift;

    my $configuration = {};
    $configuration = pop if @_ && ref $_[@_ - 1] eq "HASH";

    defined $_[0] ? $configuration->{user} = shift : shift if @_;
    defined $_[0] ? $configuration->{superdatabase} = shift : shift if @_;
    if (@_) {
        my $dir = shift;
        for my $stage (qw/setup teardown create populate/) {
            next if $configuration->{"skip_${stage}_file"};
            unshift @{ $configuration->{$stage} }, "sqlfile:*?:$dir/$stage";
        }
    }
    
    return DBIx::Deploy::Engine::MySQL->new(configuration => $configuration);
}

1;
