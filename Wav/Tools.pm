package Audio::Wav::Tools;

use strict;
use Audio::Tools::ByteOrder;

sub new {
	my $class = shift;
	# qw( channels bits_sample );
	my $pack_order = new Audio::Tools::ByteOrder;
	my $self =	{
				'pack_type'	=> $pack_order -> pack_type(),
			};
	bless $self, $class;
	return $self;
}

sub packing_data {
	my $self = shift;
	my $channels = shift;
	my $bits = shift;
	my( $pack_pic, $offset );
	my $pack_type = $self -> {'pack_type'};
	if ( $bits <= 8 ) {
		$pack_pic = $pack_type -> {'uchar'};
		$offset = ( 2 ** $bits ) / 2;
	} elsif ( $bits <= 16 ) {
		$pack_pic = $pack_type -> {'short'};
		$offset = 0;
	} else {
		die "unknown bit format ($bits)";
	}
#	$pack_pic = $pack_pic x $channels;
	$pack_pic = $pack_pic . $channels;
	return [ $pack_pic, $offset ];
}

sub pack_format {
	my $self = shift;
	return $self -> {'pack_type'};
}

sub get_wav_pack {
	my $self = shift;
	my $pack_type = $self -> {'pack_type'};
	return	{
			'order'	=> [ qw( format channels sample_rate bytes_sec block_align bits_sample ) ],
			'types' => {
					'format'	=> $pack_type -> {'short'},
					'channels'	=> $pack_type -> {'ushort'},
					'sample_rate'	=> $pack_type -> {'ulong'},
					'bytes_sec'	=> $pack_type -> {'ulong'},
					'block_align'	=> $pack_type -> {'ushort'},
					'bits_sample'	=> $pack_type -> {'ushort'},
				   },
		};
}


1;