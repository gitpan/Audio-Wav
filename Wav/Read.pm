package Audio::Wav::Read;

use strict;
use FileHandle;
use Audio::Wav::Tools;

=head1 NAME

Audio::Wav::Read - Module for reading Microsoft Wav files.

=head1 SYNOPSIS

	use Audio::Wav;
	my $wav = new Audio::Wav;
	my $read = $wav -> read( 'filename.wav' );
	my $details = $read -> details();

=head1 DESCRIPTION

Reads Microsoft Wav files.

=head1 AUTHOR

Nick Peskett - nick@soup.demon.co.uk

=head1 SEE ALSO

L<Audio::Wav>

L<Audio::Wav::Write>

=head1 NOTES

This module shouldn't be used directly, a blessed object can be returned from L<Audio::Wav>.

=head1 METHODS

=cut

sub new {
	my $class = shift;
	my $file = shift;
	my $tools = shift;
	$file =~ s#//#/#g;
	my $size = -s $file;
	my $handle = new FileHandle "<$file";
	die "unable to open file '$file' ($!)" unless defined( $handle );
	binmode $handle;
	my $self =	{
				'real_size'	=> $size,
				'file'		=> $file,
				'handle'	=> $handle,
				'tools'		=> $tools,
			};
	$self -> {'formats'} = $tools -> pack_format();

	bless $self, $class;

	$self -> {'data'} = $self -> _read_file();
	my $details = $self -> details();
	$self -> {'pos'} = $details -> {'data_start'};

	$self -> {'pack'} = $tools -> packing_data( map $details -> {$_}, qw( channels bits_sample ) );

	$self -> move_to();
	return $self;
}


=head2 file_name

Returns the file name.

	my $file = $read -> file_name();

=cut

sub file_name {
	my $self = shift;
	return $self -> {'file'};
}

=head2 get_info

Returns information contained within the wav file.

	my $info = $read -> get_info();

Returns a reference to a hash containing;
(for example, a file marked up for use in Audio::Mix)

	{
          keywords => 'bpm:126 key:a',
          name => 'Mission Venice',
          artist => 'Nightmares on Wax'
        };

=cut

sub get_info {
	my $self = shift;
	return undef unless exists( $self -> {'data'} -> {'info'} );
	return $self -> {'data'} -> {'info'};
}

=head2 get_cues

Returns the cuepoints marked within the wav file.

	my $cues = $read -> get_cues();

Returns a reference to a hash containing;
(for example, a file marked up for use in Audio::Mix)
(position is byte offset)

	{
          1 => {
                 label => 'sig',
                 position => 764343,
                 note => 'first'
               },
          2 => {
                 label => 'fade_in',
                 position => 1661774,
                 note => 'trig'
               },
          3 => {
                 label => 'sig',
                 position => 18033735,
                 note => 'last'
               },
          4 => {
                 label => 'fade_out',
                 position => 17145150,
                 note => 'trig'
               },
          5 => {
                 label => 'end',
                 position => 18271676
               }
        }

=cut

sub get_cues {
	my $self = shift;
	return undef unless exists( $self -> {'data'} -> {'cue'} );
	my $data = $self -> {'data'};
	my $cues = $data -> {'cue'};
	my $output;
	foreach my $id ( keys %$cues ) {
		my $record = { 'position' => $cues -> {$id} -> {'position'} };
		$record -> {'label'} = $data -> {'labl'} -> {$id} if ( exists $data -> {'labl'} -> {$id} );
		$record -> {'note'} = $data -> {'note'} -> {$id} if ( exists $data -> {'note'} -> {$id} );
		$output -> {$id} = $record;
	}
	return $output;
}

=head2 read_raw

Reads raw packed bytes from the current audio data position in the file.

	my $data = $self -> read_raw( $byte_length );

=cut

sub read_raw {
	my $self = shift;
	my $len = shift;
	my $data;
	$self -> {'pos'} += read( $self -> {'handle'}, $data, $len );
	return $data;
}

=head2 read

Returns the current audio data position sample across all channels.

	my @channels = $self -> read();

Returns an array of unpacked samples.
Each element is a channel i.e ( left, right ).
The numbers will be in the range;

	where $samp_max = ( 2 ** bits_per_sample ) / 2
	-$samp_max to +$samp_max

=cut

sub read {
	my $self = shift;
	my $data = $self -> {'data'};
	my( $pack, $offset ) = @{ $self -> {'pack'} };
	my $val = $self -> read_raw( $data -> {'block_align'} );
	return undef unless defined( $val );
	my @output = unpack( $pack, $val );
	@output = map( $_ - $offset, @output ) if $offset;
	return @output;
}

=head2 position

Returns the current audio data position (as byte offset).

	my $byte_offset = $read -> position();

=cut

sub position {
	my $self = shift;
	return $self -> {'pos'} - $self -> {'data'} -> {'data_start'};
}

=head2 move_to

Moves the current audio data position to byte offset.

	$read -> move_to( $byte_offset );

=cut

sub move_to {
	my $self = shift;
	my $pos = shift;
	$pos = $self -> {'data'} -> {'data_start'} unless defined( $pos );
	if ( seek $self -> {'handle'}, $pos, 0 ) {
		$self -> {'pos'} = $pos;
		return 1;
	} else {
		die "can't move to position '$pos'";
	}
}

=head2 length

Returns the number of bytes of audio data in the file.

	my $audio_bytes = $read -> length();

=cut

sub length {
	my $self = shift;
	return $self -> {'data'} -> {'data_length'};
}

=head2 details

Returns a reference to a hash of lots of details about the file.
Too many to list here, try it with Data::Dumper.....

	use Data::Dumper;
	my $details = $read -> details();
	print Data::Dumper->Dump([ $details ]);

=cut

sub details {
	my $self = shift;
	return $self -> {'data'};
#	my %output = map { $_ => $data -> {$_} } qw( block_align data_start data_length channels bits_sample length sample_rate );
#	return \%output;
}

#########

sub _read_file {
	my $self = shift;
	my $handle = $self -> {'handle'};
	my %details;
	my $type = $self -> read_raw( 4 );
	my $length = $self -> _read_long( );
	my $subtype = $self -> read_raw( 4 );

	$details{'total_length'} = $length;

	unless ( $type eq 'RIFF' && $subtype eq 'WAVE' ) {
		die $self -> {'file'}, " doesn't seem to be a wav file";
	}

	my %done;
	while ( ! eof $handle && $self -> {'pos'} < $length ) {
		my $head = $self -> read_raw( 4 );
		my $chunk_len = $self -> _read_long();
#		print "head($head) len($chunk_len)\n";
		$done{$head} = 1;
		if ( $head eq 'fmt ' ) {
			my $format = $self -> _read_fmt( $chunk_len );
			my $comp = delete( $format -> {'format'} );
			unless ( $comp == 1 ) {
				die $self -> {'file'}, " seems to be compressed";
			}
			%details = ( %details, %$format );
			next;
		} elsif ( $head eq 'cue ' ) {
			$details{'cue'} = $self -> _read_cue( $chunk_len, \%details );
			next;
		} elsif ( $head eq 'smpl' ) {
			$details{'sampler'} = $self -> _read_sampler( $chunk_len );
			next;
		} elsif ( $head eq 'LIST' ) {
			my $list = $self -> _read_list( $chunk_len, \%details );
			next;
		} elsif ( $head eq 'data' ) {
			$details{'data_start'} = $self -> {'pos'};
			$details{'data_length'} = $chunk_len;
		} else {
			$head =~ s/[^\w]+//g;
			warn $self -> {'file'}, ") ignored unknown block type: $head\n";
			next if $chunk_len > 100;
		}
		seek $handle, $chunk_len, 1;
		$self -> {'pos'} += $chunk_len;
	}
	$details{'length'} = $details{'data_length'} / $details{'bytes_sec'};
	return \%details;
}


sub _read_list {
	my $self = shift;
	my $length = shift;
	my $details = shift;
	my $note = $self -> read_raw( 4 );
#	print $self -> read_raw( $length - 4 );
#	exit;
	my $pos = 4;
	if ( $note eq 'adtl' ) {
		my %allowed = map { $_, 1 } qw( ltxt note labl );
		while ( $pos < $length ) {
			my $head = $self -> read_raw( 4 );
			$pos += 4;
			next unless $allowed{$head};
			if ( $head eq 'ltxt' ) {
				my $record = $self -> _decode_block( [ 1 .. 6 ] );
				$pos += 24;
			} elsif ( $head eq 'labl' || $head eq 'note' ) {
				my $bits = $self -> _read_long();
				$pos += $bits + 4;
				my $id = $self -> _read_long();
				my $text = $self -> read_raw( $bits - 4 );
				$text =~ s/\0+$//;
				$details -> {$head} -> {$id} = $text;
			}
		}
	} elsif ( $note eq 'INFO' ) {
		my %allowed =	(
				'IART'	=> 'artist',
				'IKEY'	=> 'keywords',
				'ICMT'	=> 'comments',
				'ICOP'	=> 'copyright',
				'IENG'	=> 'engineers',
				'IGNR'	=> 'genre',
				'IMED'	=> 'medium',
				'INAM'	=> 'name',
				'ISRC'	=> 'supplier',
				'ITCH'	=> 'digitizer',
				'ISBJ'	=> 'subject',
				'ISRF'	=> 'source',
				);
		while ( $pos < $length ) {
			my $head = $self -> read_raw( 4 );
			$pos += 4;
			next unless $allowed{$head};
			my $bits = $self -> _read_long();
			$pos += $bits + 4;
			my $text = $self -> read_raw( $bits );
			$text =~ s/\0+$//;
			$details -> {'info'} -> { $allowed{$head} } = $text;
		}
	} else {
		my $data = $self -> read_raw( $length - 4 );
		return;
	}

}

sub _read_cue {
	my $self = shift;
	my $length = shift;
	my $details = shift;
	my $cues = $self -> _read_long();
	my @fields = qw( id position chunk cstart bstart offset );
	my @plain = qw( chunk );
	my $output;
	for ( 1 .. $cues ) {
		my $record = $self -> _decode_block( \@fields, \@plain );
		my $id = delete( $record -> {'id'} );
		$output -> {$id} = $record;
	}
#	print "cue:: ",  Data::Dumper->Dump([ $output ]);
	return $output;
}

sub _read_sampler {
	my $self = shift;
	my $length = shift;
	my $pos = $self -> {'pos'};
	my @fields = qw( manufacturer product sample_period midi_unity_note midi_pitch_fraction smpte_format smpte_offset sample_loops sample_data );
	my $record = $self -> _decode_block( \@fields );
	for my $id ( 0 .. $record -> {'sample_loops'} ) {
		my @loop_fields = qw( id type start end fraction play_count );
		push @{ $record -> {'loop'} }, $self -> _decode_block( \@loop_fields );

	}
	return $record;
}

sub _decode_block {
	my $self = shift;
	my $fields = shift;
	my $plain = shift;
	my %plain;
	if ( $plain ) {
		foreach my $field ( @$plain ) {
			for my $id ( 0 .. $#$fields ) {
				next unless $fields -> [$id] eq $field;
				$plain{$id} = 1;
			}
		}
	}

	my $no_fields = scalar( @$fields );
	my %record;
	for my $id ( 0 .. $#$fields ) {
		if ( exists $plain{$id} ) {
			$record{ $fields -> [$id] } = $self -> read_raw( 4 );
		} else {
			$record{ $fields -> [$id] } = $self -> _read_long();
		}
	}
	return \%record;
}

sub _read_fmt {
	my $self = shift;
	my $length = shift;
	my $data = $self -> read_raw( $length );
	my @fields = qw( format channels sample_rate bytes_sec block_align bits_sample );

	my $types = $self -> {'tools'} -> get_wav_pack();

	my $pack_str = '';

	my $fields = $types -> {'order'};

	foreach my $type ( @$fields ) {
		$pack_str .= $types -> {'types'} -> {$type};
	}

	my @data = unpack( $pack_str, $data );
	my %record;
	for my $id ( 0 .. $#$fields ) {
		$record{ $fields -> [$id] } = $data[$id];
	}
	return { %record };
}

sub _read_long {
	my $self = shift;
	my $data = $self -> read_raw( 4 );
	return unpack( $self -> {'formats'} -> {'long'}, $data );
#	return unpack( "l4", $data );
}

1;
