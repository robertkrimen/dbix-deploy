use inc::Module::Install;

name 'DBIx-Deploy';
all_from 'lib/DBIx/Deploy.pm';

{
    require ExtUtils::MakeMaker;
    use strict;
    no strict 'refs';

    my $libscan = \&{"ExtUtils::MM_Any::libscan"};
    *{"ExtUtils::MM_Any::libscan"} = sub {
        return '' unless $libscan->(@_);
        return '' if $_[1] =~ /\.sw[p-z]$/;
        return $_[1];
    };
}

{
    for (grep { ! /^\s*#/ } split m/\n/, <<_END_) {
_END_
        my ($package, $version) = split m/\s/;
        requires $package => $version || 0;
    }
}

build_requires 'Test::More';

requires 'Term::Prompt';

auto_install;

WriteAll;

