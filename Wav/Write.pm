package Audio::Wav::Write;

use strict;
use FileHandle;
use Audio::Wav::Write::Header;

my @needed = qw( bits_sample channels sample_rate );
my @wanted = qw( block_align bytes_sec );

=head1 NAME

Audio::Wav::Write - Module for writing Microsoft Wav files.

=head1 SYNOPSIS

	use Audio::Wav;

	my $wav = new Audio::Wav;

	my $sample_rate = 44100;
	my $bits_sample = 16;

	my $details =	{
			'bits_sample'	=> $bits_sample,
			'sample_rate'	=> $sample_rate,
			'channels'	=> 1,
			};

	my $write = $wav -> write( 'testout.wav', $details );

	&add_sine( 200, 1 );

	sub add_sine {
		my $hz = shift;
		my $length = shift;
		my $pi = ( 22 / 7 ) * 2;
		$length *= $sample_rate;
		my $max_no =  ( 2 ** $bits_sample ) / 2;
		for my $pos ( 0 .. $length ) {
			$time = $pos / $sample_rate;
			$time *= $hz;
			my $val = sin $pi * $time;
			my $samp = $val * $max_no;
			$write -> write( $samp );
		}
	}

	$write -> finish();

=head1 DESCRIPTION

Currently only writes to a file.

=head1 AUTHOR

Nick Peskett - nick@soup.demon.co.uk

=head1 SEE ALSO

L<Audio::Wav>

L<Audio::Wav::Read>

=head1 NOTES

This module shouldn't be used directly, a blessed object can be returned from L<Audio::Wav>.

=head1 METHODS

=cut

sub new {
	my $class = shift;
	my $out_file = shift;
	my $details = shift;
	my $tools = shift;

	my $handle = new FileHandle join( '', '>', $out_file );
	unless ( defined $handle ) {
		my $error = $!;
		chomp( $error );
		die "unable to open file '$out_file' ($error)"
	}
	binmode $handle;
	print "creating wav file '$out_file'\n";

	$details = &_init( $details );

	my $self =	{
				'write_cache'	=> undef,
				'out_file'	=> $out_file,
				'cache_size'	=> 4096,
				'handle'	=> $handle,
				'details'	=> $details,
				'block_align'	=> $details -> {'block_align'},
				'tools'		=> $tools,
			};
	$self -> {'pack'} = $tools -> packing_data( map $details -> {$_}, qw( channels bits_sample ) );
	bless $self, $class;
	$self -> _start_file();
	return $self;
}

=head2 finish

Finishes off & closes the current wav file.

	$write -> finish();

=cut

sub finish {
	my $self = shift;
	$self -> _purge_cache();
	my $length = $self -> {'pos'};
	my $header = $self -> {'header'};
	$header -> finish( $length );
#	$self -> {'details'} -> {'data_length'} = $length;
	$self -> {'handle'} -> close();
	my $filename = $self -> {'out_file'};
	print "closing wav file '$filename'\n";
}

=head2 add_cue

Adds a cue point to the wav file.

	$write -> add_cue( $byte_offset, "label", "note"  );

=cut

sub add_cue {
	my $self = shift;
	my $pos = shift;
	my $label = shift;
	my $note = shift;
	my $block_align = $self -> {'details'} -> {'block_align'};
	my $output =	{
			'pos'	=> $pos / $block_align,
			};
	$output -> {'label'} = $label if $label;
	$output -> {'note'} = $note if $note;
	$self -> {'header'} -> add_cue( $output );
}

=head2 file_name

Returns the current filename (silly, I know).

	my $file = $write -> file_name();

=cut

sub file_name {
	my $self = shift;
	return $self -> {'out_file'};
}

=head2 write

Adds a sample to the current file.

	$write -> write( @sample_channels );

Each element in @sample_channels should be in the range of;

	where $samp_max = ( 2 ** bits_per_sample ) / 2
	-$samp_max to +$samp_max

=cut

sub write {
	my $self = shift;
	my @data = @_;
	my( $pack, $offset ) = @{ $self -> {'pack'} };
	@data = map $_ + $offset, @data;
	my $data = pack( $pack, @data );
	return $self -> write_raw( $data );
}

=head2 write_raw

Adds a some pre-packed data to the current file.

	$write -> write_raw( $data, $data_length );

Where;

	$data is the packed data
	$data_length (optional) is the length in bytes of the data

=cut

sub write_raw {
	my $self = shift;
	my $data = shift;
	my $len = shift;
	my $no_cache = shift;
	$len = length( $data ) unless $len;
	my $wrote = $len;

	if ( $no_cache ) {
		$wrote = syswrite $self -> {'handle'}, $data, $len;
	} else {
		$self -> {'write_cache'} .= $data;
		my $cache_len = length( $self -> {'write_cache'} );
		$self -> _purge_cache( $cache_len ) unless $cache_len < $self -> {'cache_size'};
	}

	$self -> {'pos'} += $wrote;
	return $wrote;
}

sub _start_file {
	my $self = shift;
	my( $details, $tools, $handle ) = map $self -> {$_}, qw( details tools handle );
	my $header = new Audio::Wav::Write::Header $details, $tools, $handle;
	$self -> {'header'} = $header;
	my $data = $header -> start();
	$self -> write_raw( $data );
	$self -> {'pos'} = 0;
}

sub _purge_cache {
	my $self = shift;
	my $len = shift;
	return unless $self -> {'write_cache'};
	my $cache = $self -> {'write_cache'};
	$len = length( $cache ) unless $len;
	my $res = syswrite( $self -> {'handle'}, $cache, $len );
	$self -> {'write_cache'} = undef;
}

#sub DESTROY {
#	my $self = shift;
#	$self -> finish();
#}

####################

sub _init {
	my $details = shift;
	my $output = {};
	my @missing;
	foreach my $need ( @needed ) {
		if ( exists( $details -> {$need} ) && $details -> {$need} ) {
			$output -> {$need}  = $details -> {$need};
		} else {
			push @missing, $need;
		}
	}
	die "I need the following parameters supplied: ", join( ', ', @missing ) if @missing;
	foreach my $want ( @wanted ) {
		next unless ( exists( $details -> {$want} ) && $details -> {$want} );
		$output -> {$want} = $details -> {$want};
	}
	unless ( exists $details -> {'block_align'} ) {
		my( $channels, $bits ) = map $output -> {$_}, qw( channels bits_sample );
		my $mod_bits = $bits % 8;
		$mod_bits = 1 if $mod_bits;
		$mod_bits += int( $bits / 8 );
		$output -> {'block_align'} = $channels * $mod_bits;
	}
	unless ( exists $output -> {'bytes_sec'} ) {
		my( $rate, $block ) = map $output -> {$_}, qw( sample_rate block_align );
		$output -> {'bytes_sec'} = $rate * $block;
	}
	return $output;
}

1;
