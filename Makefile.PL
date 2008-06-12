use inc::Module::Install;

name 'DBIx-Deploy';
all_from 'lib/DBIx/Deploy.pm';

build_requires 'Test::More';

requires 'Term::Prompt';

auto_install;

WriteAll;

