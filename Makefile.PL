use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
	'NAME'		=> 'Date::Handler',
	'VERSION_FROM'	=> 'Handler.pm', 
	'AUTHOR'       => 'Benoit Beausejour <bbeausej\@pobox.com>',
	'clean'        => { 'FILES' => 'pod2html*', },
	'dist'    	=> { 'PREOP' => 'pod2text Handler.pod > README; pod2html Handler.pod > README.html', },
);

