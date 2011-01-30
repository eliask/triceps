use 5.008000;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Biceps',
    VERSION_FROM      => 'lib/Biceps.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Biceps.pm', # retrieve abstract from module
       AUTHOR         => 'Sergey Babkin <babkin@users.sf.net>') : ()),
    LIBS              => [''], # e.g., '-lm'
    DEFINE            => '', # e.g., '-DHAVE_SOMETHING'
    INC               => '-I../../core', # e.g., '-I. -I/usr/include/other'
	# Un-comment this if you add C files to link with later:
    # OBJECT            => '$(O_FILES)', # link all the C files too
    MYEXTLIB          => '../../core/build/libbiceps$(LIB_EXT)', # embed the static version into Perl shared module
	CC                => 'g++',
	LD                => 'g++',
);

sub MY::postamble {
"
# This may not work very well on all machines because the Perl parser leaves
# a lot of dynamically allocated stuff unfreed, and your luck with valgrind
# suppressions may vary.
# Also I've copy-pasted the actual command from Makefile target test_dynamic 
# which might not work so well with a different version of MakeMaker
vtest: pure_all
	PERL_DL_NONLAZY=1 valgrind --leak-check=full -v --gen-suppressions=all --suppressions=vg.supp /\$(FULLPERLRUN) \"-MExtUtils::Command::MM\" \"-e\" \"test_harness(1, '\$(INST_LIB)', '\$(INST_ARCHLIB)')\" \$(TEST_FILES) 2>test.vg
	grep \"ERROR SUMMARY: .*[^0].* errors from\" test.vg && { echo \"  FAIL MEMCHK\" >&2; exit 1; } || true
	grep \"are definitely lost\" test.vg && { echo \"  FAIL LEAK\" >&2; exit 1; } || true
	\@echo 'Valgrind test OK'

# the quick test is the default one
qtest: test

clean::
	rm -f core.* *.core core vgcore.* test.vg
";
}

if  (eval {require ExtUtils::Constant; 1}) {
  # If you edit these definitions to change the constants used by this module,
  # you will need to use the generated const-c.inc and const-xs.inc
  # files to replace their "fallback" counterparts before distributing your
  # changes.
  my @names = (qw());
  ExtUtils::Constant::WriteConstants(
                                     NAME         => 'Biceps',
                                     NAMES        => \@names,
                                     DEFAULT_TYPE => 'IV',
                                     C_FILE       => 'const-c.inc',
                                     XS_FILE      => 'const-xs.inc',
                                  );

}
else {
  use File::Copy;
  use File::Spec;
  foreach my $file ('const-c.inc', 'const-xs.inc') {
    my $fallback = File::Spec->catfile('fallback', $file);
    copy ($fallback, $file) or die "Can't copy $fallback to $file: $!";
  }
}
