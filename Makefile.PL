use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	    => 'HTML::Navigation',
    'VERSION_FROM'  => 'Navigation.pm',
    'ABSTRACT_FROM' => 'Navigation.pm',
    'PREREQ_PM'     => { 'URI::Escape' => 0 },
);
