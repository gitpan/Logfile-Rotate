#!/usr/bin/perl
###############################################################################
#
# $Header: Rotate.pm,v 0.12 98/03/24 12:53:06 paulg Exp $ vim:ts=4
#
# Copyright (c) 1997-98 Paul Gampe. All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it 
# under the same terms as Perl itself. See COPYRIGHT section below.
#
###############################################################################

###############################################################################
##                 L I B R A R I E S / M O D U L E S
###############################################################################

package Logfile::Rotate;

use Config;    # do we have gzip
use Carp;
use IO::File;
use File::Copy;

use strict;

###############################################################################
##                  G L O B A L   V A R I A B L E S
###############################################################################

use vars qw($VERSION $COUNT $GZIP_FLAG);
$VERSION = do { my @r=(q$Revision: 0.12 $=~/\d+/g); sprintf "%d."."%02d"x$#r,@r};

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
                       [, Count  => cnt ]
                       [, Gzip   => \"/path/to/gzip\" or no ]) 
                       [, Signal => \&sub_signal ]) ")
        unless defined($args{'File'});

    my $self = {};
    $self->{'File'}   = $args{'File'};
    $self->{'Count'}  = ($args{'Count'} or 7);
    $self->{'Signal'} = ($args{'Signal'} or sub {1;});

    (ref($self->{'Signal'}) eq "CODE")
        or croak "error: Signal is not a CODE reference.";

    if (defined($args{'Gzip'}) and $args{'Gzip'} eq 'no') {
        $self->{'Gzip'} = undef;
    } else {
        $self->{'Gzip'} = ( $args{'Gzip'} or $Config{'gzip'});
    }
    
    # confirm text file
    croak "error: $self->{'File'} not a text file" unless (-T $self->{'File'});

    # open and lock the file
    $self->{'Fh'} = new IO::File "$self->{'File'}", O_WRONLY|O_EXCL;
    croak "error: can not lock open: ($self->{'File'})" 
        unless defined($self->{'Fh'});

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
            move($prev,$next)	## move will attempt rename for us
                or croak "error: move failed: ($prev,$next)";
        }
    }

    ## copy current to next incremental
    $next = $curr . ".1";
    copy ($curr, $next);        

    ## preserve permissions and status
	my @stat = stat $curr;
    chmod( $stat[2], $next ) or carp "error: chmod failed: ($next)";
    utime( $stat[8], $stat[9], $next ) or carp "error: failed: ($next)";
    chown( $stat[4], $stat[5], $next ) or carp "error: chown failed: ($next)";

    # now truncate the file
    truncate $curr,0 or croak "error: could not truncate $curr: $!";

    # WARNING: may not be safe system call
    if ($self->{'Gzip'}) { 
        ( 0 == (system $self->{'Gzip'}, $GZIP_FLAG, $next) )
            or croak "error: compress failed";
    }
    return &{$self->{'Signal'}};
}

sub DESTROY {
    my ($self, %args) = @_;
    undef $self->{'Fh'};    # auto-close
}

1;


__END__

=head1 NAME

Logfile::Rotate - Perl module to rotate logfiles.

=head1 SYNOPSIS

   use Logfile::Rotate;
   my $log = new Logfile::Rotate( File   => '/var/adm/syslog/syslog.log', 
                                  Count  => 7,
                                  Gzip   => '/usr/local/bin/gzip',
                                  Signal => sub {
                                            my $pid = `cat /var/run/syslog.pid`;
                                            my @args = ('kill', '-HUP', $pid );
                                            system(@args);
                                            }
                                );

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

C<new> accepts four arguments, C<File>, C<Count>, C<Gzip>, C<Signal>
with only C<File> being mandatory.  C<new> will open and lock the file,
so you may coordindate the processing of the file with rotating it.  The
file is closed and unlocked when the object is destroyed, so you can do
this explicity by C<undef>'ing the object.  

The C<Signal> argument allows you to pass a function reference to this
method, which you may use as a callback for any further processing you
want after the rotate is completed. For example, you may notify the
process writing to the file that it has been rotated.

=item rotate()

This method will copy the file passed in C<new> to a file of the same
name, with a numeric extension and truncate the original file to zero
length.  The numeric extension will range from 1 up to the value
specified by Count, or 7 if none is defined, with 1 being the most
recent file.  When Count is reached, the older file is discarded in a
FIFO (first in, first out) fashion. 

The C<Signal> function is the last step executed by the rotate method so
the return code of rotate will be the return code of the function you
proved, or 1 by default.

The copy function is implemented by using the L<File::Copy> package, but
I have had a few people suggest that they would prefer L<File::Move>.
I'm still not decided on this as you would loose data if the move should
fail.  

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

=head1 COPYRIGHT

Copyright (c) 1997-98 Paul Gampe. All rights reserved.
This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

IN NO EVENT SHALL THE AUTHORS OR DISTRIBUTORS BE LIABLE TO ANY PARTY
FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES
ARISING OUT OF THE USE OF THIS SOFTWARE, ITS DOCUMENTATION, OR ANY
DERIVATIVES THEREOF, EVEN IF THE AUTHORS HAVE BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE. 

THE AUTHORS AND DISTRIBUTORS SPECIFICALLY DISCLAIM ANY WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND
NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN ``AS IS'' BASIS, AND
THE AUTHORS AND DISTRIBUTORS HAVE NO OBLIGATION TO PROVIDE
MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS. 

=head1 SEE ALSO

L<File::Copy>, L<Logfile::Base>,
F<Changes> file for change history and credits for contributions.

=head1 RETURN

All functions return 1 on success, 0 on failure.

=head1 AUTHOR

Paul Gampe <paulg@twics.com>

=cut

