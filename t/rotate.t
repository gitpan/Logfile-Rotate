
BEGIN {print "1..15\n";}
END {print "not ok 1\n" unless $loaded;}
use Logfile::Rotate;
$loaded = 1;
print "ok 1\n";

use File::Copy;

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
	print "not "
		if $log->rotate();
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

print "the following will fail if perl does not know you have gzip\n";

$cnt = 3;
$file_no = 1;

print "not "
	unless $log = new Logfile::Rotate( File  => 't/rotate.tmp', 
	                                   Count => $cnt );
print "ok ",$i++,"\n";

while($cnt-- > 0) {
	print "not "
		if $log->rotate();
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
