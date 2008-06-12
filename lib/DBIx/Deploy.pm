package DBIx::Deploy;

use warnings;
use strict;

=head1 NAME

DBIx::Deploy - Setup, create, populate, and teardown database schema with DBI

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

use Class::Inspector;
use Carp;

sub create {
    my $class = shift;
    local %_ = @_;

    my $engine = delete $_{engine};

    my $engine_class = $engine || '';

    if      (0)                                         {}
    elsif   ($engine_class =~ m/^SQLite$/i)             { $engine_class = "SQLite" }
    elsif   ($engine_class =~ m/^PostgreS(?:QL)?$/i)    { $engine_class = "PostgreSQL" }
    elsif   ($engine_class =~ m/^MySQL$/i)              { $engine_class = "MySQL" }

    if ($engine_class) {
        $engine_class = "DBIx::Deploy::Engine::$engine" unless $engine_class =~ s/^\+//;
    }
    else {
        $engine_class = "DBIx::Deploy::Engine";
    }

    unless (Class::Inspector->loaded($engine_class)) {
        eval "require $engine_class;" or croak "Couldn't find engine: $engine_class: $@";
    }

    my $configure = delete $_{configure} || delete $_{config};
    if (! $configure) {
        $configure = { %_ };
        %_ = ();
    }

    return $engine_class->new(configure => $configure, %_);
}

=head1 Scripting deployment

A SCRIPT is a list (array reference) composed of steps. The steps are run through in order.

SQL referenced in a step will be first processed via Template Toolkit.  The result will be split using L<SQL::Script> with the following pattern: C</\n\s*-{2,4}\n/>

That is, a newline, followed by optional whitespace, followed by 2 to 4 dashes and another newline. For example:

    CREATE TABLE album (...)

    --

    CREATE TABLE artist (...)

    --

A step can be:

=head2 ~<connection> 

Set the connection for the following STEP to be <connection>

After the following STEP, the connection will revert to the default connection

    ..., ~user => \"CREATE TABLE ...", ...

    ..., ~superuser => \"CREATE TABLE ...", ...

=head2 <file>

Execute the SQL in the <file> using the current connection

    ..., /path/to/sql/extra.sql, ...

=head2 <directory>

Execute the SQL in the file <directory>/<stage>{.sql, .tt2.sql, .tt.sql, .tt2, .tt} using the current connection

    ..., /path/to/sql/, ...

    # If the current stage is "create", then the above will use /path/to/sql/create.sql (or one of the other extensions)

=head2 SCALAR

Execute the SQL contained in SCALAR using the current connection. Again, statements should be separated using a double dash at the
beginning of the line (as described above).

=cut

    #=head2 CODE

    #Execute CODE, passing in: the engine,  the remaining script (as an array reference) 

    #=head2 ARRAY

=head1 AUTHOR

Robert Krimen, C<< <rkrimen at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-dbix-deploy at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=DBIx-Deploy>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc DBIx::Deploy


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=DBIx-Deploy>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/DBIx-Deploy>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/DBIx-Deploy>

=item * Search CPAN

L<http://search.cpan.org/dist/DBIx-Deploy>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2008 Robert Krimen

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of DBIx::Deploy
