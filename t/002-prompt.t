#!perl -w

use strict;

use constant TRY_IT_OUT => $ENV{TRY_IT_OUT};

unless (TRY_IT_OUT) {
    require Test::More;
    require Test::Deep;
    require t::Test;
    require IO::Scalar;
    Test::More->import(qw/no_plan/);
}

use DBIx::Deploy::Engine;

my $engine = DBIx::Deploy::Engine->new;
my ($input, $output, $got, $in, $out);

unless (TRY_IT_OUT) {
    ok($engine) unless TRY_IT_OUT;
    $in = tie *STDIN, 'IO::Scalar', \$input;
    $out = tie *STDOUT, 'IO::Scalar', \$output;
}

sub got {
    warn "\nGot back: ", shift, "\n" if 0 || TRY_IT_OUT;
}

sub try {
    $input = shift;
    my $expect = ref $_[0] eq "ARRAY" ? $input : shift();

    unless (TRY_IT_OUT) {
        $input .= "\n";
        $output = "";
        $in->setpos(0);
        $out->setpos(0);
    }

    my $prompt = shift;
    my $test = shift;

    $got = $engine->password(@$prompt);
    got $got;

    unless (TRY_IT_OUT) {
        like($output, qr/Enter password for postgres\@template1 \(user\): /);
        is($got, $expect);
        $test->() if $test;
    }
}

try "xyzzy", [ qw/key test save 0/, prompt => "Enter password for postgres\@template1 (user):" ];

try "\nnothing" => "", [ qw/key test save 0/, prompt => "Enter password for postgres\@template1 (user):" ], sub {
    unlike($output, qr/Invalid option/);
};
