package DBIx::Deploy::Stash;

use strict;
use warnings;

# Stolen from Catalyst::Utils
# "Code to recursively merge two hashes together with right-hand precedence."
sub merge {
    shift unless ref $_[0] eq "HASH";
    my ($left, $right) = @_;

    return $left unless defined $right;

    my %union = %$left;
    for my $key ( keys %$right ) {
        my $right_ref = ( ref $right->{ $key } || '' ) eq 'HASH';
        my $left_ref  = ( ( exists $left->{ $key } && ref $left->{ $key } ) || '' ) eq 'HASH';
        if( $right_ref and $left_ref ) {
            $union{ $key } = merge_hashes(
                $left->{ $key }, $right->{ $key }
            );
        }
        else {
            $union{ $key } = $right->{ $key };
        }
    }

    return \%union;
}

1;
