use inc::Module::Install;

name 'DBIx-Deploy';
all_from 'lib/DBIx/Deploy.pm';

build_requires 'Test::More';

auto_install;

WriteAll;

