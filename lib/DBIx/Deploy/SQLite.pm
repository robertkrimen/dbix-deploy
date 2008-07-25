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
            "path/to/SQL", { ... });

    my $dbh = DBI->connect($deploy->information); # Database will deploy automatically if it doesn't exist

    # Or you can do it manually:
    
    $deploy->deploy if ! $deploy->database_exists;

=head1 METHODS

=head2 my $deploy = DBIx::Deploy::SQLite->new( <filename>, <directory>, ... )

This method will return a L<DBIx::Deploy::Engine::SQLite> object that you can use to deploy your database schema.

The <filename> argument should be the file that does-contain/should-contain your SQLite database.

The <directory> argument should point to a directory on disk containing something like:

    <directory>/create.sql
    <directory>/populate.sql

Finally, the content of the trailing (optional) HASH reference will be passed through to the configuration of L<DBIx::Deploy::Engine>

=cut

sub new {
    my $class = shift;

    my $configuration = {};
    $configuration = pop if @_ && ref $_[@_ - 1] eq "HASH";

    defined $_[0] ? $configuration->{database} = shift : shift if @_;
    if (@_) {
        my $dir = shift;
        for my $stage (qw/create populate/) {
            next if $configuration->{"skip_${stage}_file"};
            unshift @{ $configuration->{$stage} }, "sqlfile:*?:$dir/$stage";
        }
    }
    
    return DBIx::Deploy::Engine::SQLite->new(configuration => $configuration);
}

1;
