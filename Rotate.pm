#!/usr/bin/perl
###############################################################################
#
# $Header: Rotate.pm,v 0.7 98/02/18 16:03:45 paulg Exp $
# Copyright (c) 1997-98 Paul Gampe and TWICS. All Rights Reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
# 
###############################################################################

###############################################################################
##                 L I B R A R I E S / M O D U L E S
###############################################################################

package Logfile::Rotate;

use Config;	# do we have gzip
use Carp;
use Fcntl qw(:flock);
use IO::File;
use File::Copy;

use strict;

###############################################################################
##                  G L O B A L   V A R I A B L E S
###############################################################################

use vars qw($VERSION $COUNT $GZIP_FLAG);
$VERSION = do { my @r=(q$Revision: 0.7 $=~/\d+/g); sprintf "%d."."%02d"x$#r,@r};

$COUNT=7; # default to keep 7 copies
$GZIP_FLAG='-qf'; # force writing over old logfiles

###############################################################################
##                         E X P O R T S
###############################################################################

###############################################################################
##                             M A I N
###############################################################################

sub new {
	my ($class, %args) = @_;

	croak("usage: new( File => filename 
	                   [, Count => cnt ]
					   [, Gzip => \"/path/to/gzip\" or no ]) ")
		unless (defined($args{'File'}));

	my $self = {};
	$self->{'File'}  = $args{'File'};
	$self->{'Count'} = ($args{'Count'} or 7);

	if (defined($args{'Gzip'}) and $args{'Gzip'} eq 'no') {
		$self->{'Gzip'} = undef;
	} else {
		$self->{'Gzip'} = ( $args{'Gzip'} or 
		                    $Config{'gzip'});
	}
	
	# confirm text file
	croak "error: $self->{'File'} not a text file" unless (-T $self->{'File'});

	# open the file
	$self->{'Fh'} = new IO::File "$self->{'File'}";
	croak "error: can not open $self->{'File'}" 
		unless (defined $self->{'Fh'});

	# lock the file
	croak "error: could not lock $self->{'File'}" 
		if (flock($self->{'Fh'}, LOCK_EX));
	

	bless $self, $class;
}

sub rotate {
	my ($self, %args) = @_;

	my ($prev,$next,$i,$j);

	# check we still have a filehandle
	croak "error: lost file handle, may have called rotate twice ?"
		unless defined($self->{'Fh'});

	my $curr = $self->{'File'};
	my $ext  = $self->{'Gzip'} ? '.gz' : '';

	for($i = $self->{'Count'}; $i > 1; $i--) {
		$j = $i - 1;
			$next = "$curr." . $i . $ext;
			$prev = "$curr." . $j . $ext;
		if ( -r $prev && -f $prev ) {
			croak "error: copy failed" unless copy($prev,$next);
		}
	}

	$next = $curr . ".1";
	copy ($curr, $next);

	# now truncate the file
	truncate $curr,0 or croak "error: could not truncate $curr: $!";

	# WARNING: may not be safe system call
	if ($self->{'Gzip'}) { 
		croak "error: compress failed" unless 
			( 0 == (system $self->{'Gzip'}, $GZIP_FLAG, $next) );
	}
	return 0;
}

sub DESTROY {
	my ($self, %args) = @_;

	flock $self->{'Fh'}, LOCK_UN;	# unlock the file 
	undef $self->{'Fh'};	# auto-close
}

1;


__END__

=head1 NAME

Logfile::Rotate - Perl module to rotate logfiles.

=head1 SYNOPSIS

   use Logfile::Rotate;
   my $log = new Logfile::Rotate( File  => '/var/adm/syslog', 
                                  Count => 7,
								  Gzip  => '/usr/local/bin/gzip' );

   # process log file 

   $log->rotate();

   or
   
   my $log = new Logfile::Rotate( File  => '/var/adm/syslog', 
								  Gzip  => 'no' );
   
   # process log file 

   $log->rotate();
   undef $log;

=head1 DESCRIPTION

I have used the name space of L<Logfile::Base> package by I<Ulrich Pfeifer>, 
as the use of this module closely relates to the processing logfiles.

=over 4

=item new

C<new> accepts three arguments, C<File>, C<Count>, C<Gzip>, with only
C<File> being mandatory.  C<new> will open and lock the file, so you may
coordindate the your processing of the file with rotating it.  The file
is closed and unlocked when the object is destroyed, so you can do
this explicity by C<undef>'ing the object.  

=item rotate()

It will copy the file passed in C<new> to a file of the same name, with 
a numeric extension and truncate the original file to zero length.  
The numeric extension will range from 1 up to the value specified by 
Count, or 7 if none is defined, with 1 being the most recent file.  
When Count is reached, the older file is discarded in a FIFO 
(first in, first out) fashion. 

The copy function is implemented by using the L<File::Copy> package.

=back 

=head2 Optional Compression

If available C<rotate> will also compress the file with the 
L<gzip> program or the program passed as the C<Gzip> argument.  
If no argument is defined it will also check the perl L<Config> 
to determine if gzip is available on your system. In this case 
the L<gzip> must be in your current path to succeed, and accept
the CB<-f> option.  


See the L<"WARNING"> section below.

=head1 WARNING

A system call is made to F<gzip> this makes this module vulnerable to
security problems if a rogue gzip is in your path or F<gzip> has been 
sabotaged.  For this reason a STRONGLY RECOMMEND you DO NOT use this 
module while you are ROOT, or specify the C<Gzip> argument.

=head1 DEPENDANCIES

See L<File::Copy>.

If C<Gzip> is being used it must create files with an extension 
of C<.gz> for the file to be picked by the rotate cycle.

=head1 SEE ALSO

L<File::Copy>, L<Logfile::Base>.

=head1 RETURN

All functions return 1 on success, 0 on failure.

=head1 AUTHOR

Paul Gampe <paulg@twics.com>

=cut

