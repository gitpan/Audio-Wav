package Audio::Wav::Write::Header;

use strict;

sub new {
	my $class = shift;
	my $details = shift;
	my $tools = shift;
	my $handle = shift;
	my $self =	{
				'data'		=> undef,
				'details'	=> $details,
				'tools'		=> $tools,
				'formats'	=> $tools -> pack_format(),
				'handle'	=> $handle,
				'whole_offset'	=> 4,
			};
	bless $self, $class;
	return $self;
}

sub start {
	my $self = shift;
	my $long = $self -> {'formats'} -> {'long'};
	my $output = 'RIFF';
	$output .= pack( $long, 0 );
	$output .= 'WAVE';

	my $format = $self -> _format();
	$output .= 'fmt ' . pack( $long, length( $format ) ) . $format;
	$output .= 'data';
	my $data_off = length( $output );
	$output .= pack( $long, 0 );

	$self -> {'data_offset'} = $data_off;
	$self -> {'total'} = length( $output ) - 8;

	return $output;
}

sub finish {
	my $self = shift;
	my $data_size = shift;
	my $handle = $self -> {'handle'};

	my $extra = $self -> _write_cues();
	$extra += $self -> _write_list();

	my $long = $self -> {'formats'} -> {'long'};

	my $whole_num = pack( $long, $self -> {'total'} + $data_size + $extra );
	my $len_long = length( $whole_num );


	my $seek_to = $self -> {'whole_offset'};
	seek( $handle, $seek_to, 0 ) || die "unable to seek to $seek_to ($!)";;
	syswrite( $handle, $whole_num, $len_long );

	$seek_to = $self -> {'data_offset'};
	seek( $handle, $seek_to, 0 ) || die "unable to seek to $seek_to ($!)";
	my $data_num = pack( $long, $data_size );
	syswrite( $handle, $data_num, $len_long );
}

sub add_cue {
	my $self = shift;
	my $record = shift;
	push @{ $self -> {'cues'} }, $record;
}


sub _write_list {
	my $self = shift;
	return 0 unless $self -> {'cues'};
	my $cues = $self -> {'cues'};
	my $long = $self -> {'formats'} -> {'long'};

	my %adtl;

	foreach my $id ( 0 .. $#$cues ) {
		my $cue = $cues -> [$id];
		my $cue_id = $id + 1;
		if ( exists $cue -> {'label'} ) {
			$adtl{'labl'} -> {$cue_id} = $cue -> {'label'};
		}
		if ( exists $cue -> {'note'} ) {
			$adtl{'note'} -> {$cue_id}  = $cue -> {'note'};
		}
	}
	return 0 unless ( keys %adtl );
	my $adtl = 'adtl';
	my $sub = sub {
			my $id = shift;
			my $type = shift;
			my $text = shift;
			my $str =  pack( $long, $id ) . $text;
			# nasty hack that cooledit requires for some reason
			$str .= "\0" unless $type eq 'note';
			my $str_len = length $str;
			return $type . pack( $long, $str_len ) . $str;
	};
	foreach my $type ( keys %adtl ) {
		foreach my $id ( sort { $a <=> $b } keys  %{ $adtl{$type} } ) {
			$adtl .= &$sub( $id, $type, $adtl{$type} -> {$id} );
		}
	}
	my $ad_length = length $adtl;
	my $output = 'LIST' . pack( $long, $ad_length ) . $adtl;
	my $data_len = length( $output );
	syswrite( $self -> {'handle'}, $output, $data_len );
	return $data_len;
}

sub _write_cues {
	my $self = shift;
	return 0 unless $self -> {'cues'};
	my $cues = $self -> {'cues'};

	my $long = $self -> {'formats'} -> {'long'};
	my @fields = qw( id position chunk cstart bstart offset );
	my %plain = map { $_, 1 } qw( chunk );

	my %defaults;
	my $output = pack( $long, scalar( @$cues ) );
	foreach my $id ( 0 .. $#$cues ) {
		my $cue = $cues -> [$id];
		my $pos = $cue -> {'pos'};
		my %record =	(
				'id'		=> $id + 1,
				'position'	=> $pos,
				'chunk'		=> 'data',
				'cstart'	=> 0,
				'bstart'	=> 0,
				'offset'	=> $pos,
				);
		foreach my $field ( @fields ) {
			my $data = $record{$field};
			$data = pack( $long, $data ) unless exists( $plain{$field} );
			$output .= $data;
		}
	}

	my $data_len = length( $output );
	return 0 unless $data_len;
	$output = 'cue ' . pack( $long, $data_len ) . $output;
	$data_len += 8;
	syswrite( $self -> {'handle'}, $output, $data_len );
	return $data_len;
}

sub _format {
	my $self = shift;
	my $details = $self -> {'details'};
	my $types = $self -> {'tools'} -> get_wav_pack();
	$details -> {'format'} = 1;
	my $output;
	foreach my $type ( @{ $types -> {'order'} } ) {
		$output .= pack( $types -> {'types'} -> {$type}, $details -> {$type} );
	}
	return $output;
}

1;

