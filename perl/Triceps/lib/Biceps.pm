package Biceps;

use 5.008000;
use strict;
use warnings;
use Carp;

require Exporter;
use AutoLoader;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Biceps ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.01';

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    my $constname;
    our $AUTOLOAD;
	#print STDERR "AUTOLOAD '$AUTOLOAD'\n";
    ($constname = $AUTOLOAD) =~ s/.*:://;
    croak "&Biceps::constant not defined" if $constname eq 'constant';
    my ($error, $val) = constant($constname);
    if ($error) { croak $error; }
    {
	no strict 'refs';
	# Fixed between 5.005_53 and 5.005_61
#XXX	if ($] >= 5.00561) {
#XXX	    *$AUTOLOAD = sub () { $val };
#XXX	}
#XXX	else {
	    *$AUTOLOAD = sub { $val };
#XXX	}
    }
    goto &$AUTOLOAD;
}

require XSLoader;
XSLoader::load('Biceps', $VERSION);

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Biceps - Perl interface to the Biceps CEP engine

=head1 SYNOPSIS

  use Biceps;

=head1 DESCRIPTION

Biceps is a Complex Event Processing engine, embeddable into the
scripting language. At the moment the only language supported is Perl
(and of course the native C++).

More details will be added later as the features become available.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Biceps project at SourceForge http://sourceforge.net/projects/biceps/

=head1 AUTHOR

Sergey A. Babkin, E<lt>babkin@users.sf.netE<gt> or E<lt>sab123@hotmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Sergey  A.Babkin

This library distributed under the Lesser GPL license version 3.0.


=cut
