package Audio::Wav;

use strict;
use vars qw( $VERSION );
use Audio::Wav::Tools;
$VERSION = '0.01';

=head1 NAME

Audio::Wav - Modules for reading & writing Microsoft Wav files.

=head1 SYNOPSIS

	use Audio;

	my $buffer = 512;

	my $wav = new Audio::Wav;

	my $read = $wav -> read( 'testout.wav' );

	my $write = $wav -> write( 'testcopy.wav', $read -> details() );

	my $total = 0;

	my $length = $read -> length();
	while ( $total < $length ) {
		my $left = $length - $total;
		$buffer = $left unless $left > $buffer;
		my $data = $read -> read_raw( $buffer );
		last unless defined( $data );
		$write -> write_raw( $data, $buffer );
		$total += $buffer;
	}

	$write -> finish();

=head1 NOTES

All sample positions used are in byte offsets
(L<Audio::Tools::Time> for conversion utilities)

=head1 DESCRIPTION

These modules provide a method of reading & writing uncompressed Microsoft Wav files.
It was developed on mswin32 so I'm not sure if this version has the correct byte order for big endian machines.

=head1 AUTHOR

Nick Peskett - nick@soup.demon.co.uk

=head1 SEE ALSO

	L<Audio::Tools>

	L<Audio::Wav::Read>

	L<Audio::Wav::Write>


=head1 METHODS

=head2 new

Returns a blessed Audio::Wav object.

	my $wav = new Audio::Wav;

=cut

sub new {
	my $class = shift;
	my $self =	{
				'tools'	=> new Audio::Wav::Tools,
			};
	bless $self, $class;
	return $self;
}

=head2 write

Returns a blessed Audio::Wav::Write object.

	my $details =	{
			'bits_sample'	=> 16,
			'sample_rate'	=> 44100,
			'channels'	=> 2,
			};

	my $write = $wav -> write( 'testout.wav', $details );

See L<Audio::Wav::Write> for methods.

=cut

sub write {
	my $self = shift;
	my( $out_file, $write_details ) = @_;
	require Audio::Wav::Write;
	my $write = Audio::Wav::Write -> new( $out_file, $write_details, $self -> {'tools'} );
	return $write;
}

=head2 read

Returns a blessed Audio::Wav::Read object.

	my $read = $wav -> read( 'testout.wav' );

See L<Audio::Wav::Read> for methods.

=cut

sub read {
	my $self = shift;
	my $file = shift;
	require Audio::Wav::Read;
	my $read = new Audio::Wav::Read $file, $self -> {'tools'};
	return $read;
}

1;
__END__
