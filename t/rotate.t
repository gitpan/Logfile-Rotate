
BEGIN {print "1..22\n";}
END {print "not ok 1\n" unless $loaded;}
use Logfile::Rotate;
$loaded = 1;
print "ok 1\n";

use File::Copy;

###############################################################################
#                    N O   G Z I P   T E S T  2 - 9
###############################################################################
my $i = 2;
my $cnt = 3;
my $file_no = 1;

copy('t/rotate.log', 't/rotate.tmp');

print "not "
	unless $log = new Logfile::Rotate( File  => 't/rotate.tmp', 
	                                   Count => $cnt ,
	                                   Gzip  => 'no' );
print "ok ",$i++,"\n";

while($cnt-- > 0) {
	$log->rotate() or print "not ";
	print "ok ",$i++,"\n";

	my $f = "t/rotate.tmp." . $file_no++;
	print "not "
		unless ( -f $f );
	print "ok ",$i++,"\n";

	copy('t/rotate.log', 't/rotate.tmp');
}

while($file_no-- > 0) {
	my $f = "t/rotate.tmp." . $file_no;
	unlink $f;
}

###############################################################################
#                       S I G N A L  T E S T  10 - 15
###############################################################################
$cnt = 3;
$file_no = 1;

print "not "
	unless $log = new Logfile::Rotate( File  => 't/rotate.tmp', 
	                                   Count => $cnt,
	                                   Gzip  => 'no',
									   Signal => sub { print "ok "; },
									 );
print "ok ",$i++,"\n";

while($cnt-- > 0) {
	$log->rotate() or print "not ";
	print $i++,"\n"; ## rotate print's ok

	my $f = "t/rotate.tmp." . $file_no++;
	print "not " unless ( -f $f );
	print "ok ",$i++,"\n";

	copy('t/rotate.log', 't/rotate.tmp');
}

while($file_no-- > 0) {
	my $f = "t/rotate.tmp." . $file_no;
	unlink $f;
}

###############################################################################
#                       G Z I P   T E S T   16 - 22
###############################################################################
print "the following will fail if perl does not know you have gzip\n";

$cnt = 3;
$file_no = 1;

print "not "
	unless $log = new Logfile::Rotate( File  => 't/rotate.tmp', 
	                                   Count => $cnt );
print "ok ",$i++,"\n";

while($cnt-- > 0) {
	$log->rotate() or print "not ";
	print "ok ",$i++,"\n";

	my $f = "t/rotate.tmp." . $file_no++ . ".gz";
	print "not "
		unless( -f $f );
	print "ok ",$i++,"\n";

	copy('t/rotate.log', 't/rotate.tmp');
}

while($file_no-- > 0) {
	my $f = "t/rotate.tmp." . $file_no . ".gz";
	unlink $f;
}

unlink('t/rotate.tmp');

1;
