#!/usr/bin/env perl

use strict;
use warnings;
use sigtrap 'handler', \&trap_sigs, 'normal-signals';
use IO::Socket;
use IO::Interface::Simple;

# These packets are absurdly large...
my $Proto_Header = '2420' ;
my $Pre_Door_Header = '00000000000000c8b63819008102000d7e1e001e001e001e00';
my $Post_Door_Header = '000000000102030400000000ff00ff000000000008fa006400ff55011e00007e1e1e';
$Post_Door_Header .= ('f'x24) . '000432' . ('f'x22) . '8494' . ('f'x80);
$Post_Door_Header .= 'c0a80000ffff0000c0a8000060ea000000000000010027001e00020027001e00040027001e0010000038b80b0a00000d';
$Post_Door_Header .= ('0'x82) . ('f'x14) . '49ee4aee000000000000' . ('f'x36) . ('0'x1570);
my $Trailer = ('0'x252);

# Four doors allowed by controller
# Status -> Zero = closed, One = open
my %Door_Data = (
	'1' => { 'open' => { 'o_code' => 'f98501', 'o_comm' => '01030303' },
			'close' => { 'c_code' => '796c01', 'c_comm' => '02030303' },
			'status' => 0, 'magic' => '04' }, 
	'2' => { 'open' => { 'o_code' => '853001', 'o_comm' => '03010303' },
			'close' => { 'c_code' => 'e73101', 'c_comm' => '03020303' },
			'status' => 0, 'magic' => '08' }, 
	'3' => { 'open' => { 'o_code' => 'bac601', 'o_comm' => '03030103' },
			'close' => { 'c_code' => 'b9e401', 'c_comm' => '03030203' },
			'status' => 0, 'magic' => '10' }, 
	'4' => { 'open' => { 'o_code' => 'e8ef01', 'o_comm' => '03030301' },
			'close' => { 'c_code' => '90ec01', 'c_comm' => '03030302' },
			'status' => 0, 'magic' => '20' }
	); 


sub send_data {
	my $info = shift;
	my $iface = IO::Interface::Simple->new('eth0');
	my $sock = IO::Socket::INET->new(
		Proto => 'udp',
		PeerPort => '60000',
		PeerAddr => '255.255.255.255',
		LocalAddr => $iface->address,
		Broadcast => 1,
		autoflush => 1,
	) or warn "Error opening socket: $!\n";

	if ( defined $info and $sock )
	{ 
		$sock->send(pack("H*", $info)) or warn "Send error: $!\n"; 
		close( $sock );
		return 0; 
	}
	else
	{ return 1; }
}

sub trap_sigs {
	print ("\n${0}: Received an exit signal!\n");
	exit 0;
}

while (1){

	my $delay = int(rand(300)+120);
	my $door = int(rand(3)+1);
	my $door_magic = $Door_Data{$door}{magic};
	my $door_code;
	my $door_comm;
	if ( 1 == $Door_Data{$door}{status} )
	{
		$door_code = $Door_Data{$door}{close}{c_code};
		$door_comm = $Door_Data{$door}{close}{c_comm};
		$Door_Data{$door}{status} = 0;
	}
	elsif ( 0 == $Door_Data{$door}{status} )
	{
		$door_code = $Door_Data{$door}{open}{o_code};
		$door_comm = $Door_Data{$door}{open}{o_comm};
		$Door_Data{$door}{status} = 1;
	}

	sleep($delay);
	
	my $post_data = $Proto_Header . $door_code . $Pre_Door_Header;
	$post_data .= $door_comm . $Post_Door_Header . $door_magic . $Trailer;

	send_data( $post_data );
}

# Shouldn't hit this code...
exit 99;
