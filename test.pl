$| = 1;

my $out_dir = 'test_output';

unless ( -d $out_dir ) {
	mkdir( $out_dir, 0777 ) ||
		die "unable to make test output directory '$out_dir' - ($!)";
}

my %mods	= (
		  'wav'		=> 'Audio::Wav',
		  'tools'	=> 'Audio::Tools',
		  'byteorder'	=> 'Audio::Tools::ByteOrder',
		  'time'	=> 'Audio::Tools::Time',
		  );

my %present;
foreach my $type ( keys %mods ) {
	$present{$type} = eval "require $mods{$type}";
}

my $tests = 4;

print "1..$tests\n";

my $cnt;
foreach $type ( qw( wav tools ) ) {
	$cnt ++;
	unless ( $present{$type} ) {
		print "not ok $cnt, unable to load $mods{$type}\n";
		die;
	} else {
		print "ok $cnt, $mods{$type} loadable\n";
	}
}

print "\nTesting wav creation\n";

my $wav = new Audio::Wav;

my $file_out = $out_dir . '/testout.wav';
my $file_copy = $out_dir . '/testcopy.wav';
#my $sample_rate = 44100;
my $sample_rate = 11025;
my $bits_sample = 16;
my $length = 1;

my $time = new Audio::Tools::Time $sample_rate, $bits_sample, 1;

my $details =	{
		'bits_sample'	=> $bits_sample,
		'sample_rate'	=> $sample_rate,
		'channels'	=> 1,
		};

my $write = $wav -> write( $file_out, $details );

my $marks = $length / 3;
foreach my $xpos ( 1 .. 2 ) {
	my $ypos = $time -> seconds_to_bytes( $xpos * $marks );
	$write -> add_cue( $ypos, "label $xpos", "note $xpos" );
}

&add_slide( 50, 1000, $length );

$write -> finish();

$cnt ++;
print "ok $cnt\n";

print "\nTesting wav copying\n";

my $read = $wav -> read( $file_out );

$write = $wav -> write( $file_copy, $read -> details() );

my $buffer = 512;
my $total = 0;
$length = $read -> length();

while ( $total < $length ) {
	my $left = $length - $total;
	$buffer = $left unless $left > $buffer;
	my $data = $read -> read_raw( $buffer );
	last unless defined( $data );
	$write -> write_raw( $data, $buffer );
	$total += $buffer;
}

$write -> finish();

print "wav files $file_out & $file_copy should be identical\n";
$cnt ++;
print "ok $cnt\n";


sub add_slide {
	my $from_hz = shift;
	my $to_hz = shift;
	my $length = shift;
	my $diff_hz = $to_hz - $from_hz;
	my $pi = ( 22 / 7 ) * 2;
	$length *= $sample_rate;
	my $max_no =  ( 2 ** $bits_sample ) / 2;
	my $pos = 0;

	while ( $pos < $length ) {
		$pos ++;
		my $prog = $pos / $length;
		my $hz = $from_hz + ( $diff_hz * $prog );
		my $cycle = $sample_rate / $hz;
		my $mult = $pos / $cycle;
		my $samp = sin( $pi * $mult ) * $max_no;
		if ( $dir ) {
			$write -> write( 0, $samp );
		} else {
			$write -> write( $samp, 0 );
		}
	}
}

