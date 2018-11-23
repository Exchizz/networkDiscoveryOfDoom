#!/usr/bin/perl

use strict;
use warnings;
use Carp;
use Getopt::Long;
use Net::SNMP;
use Data::Dumper;
use Net::SNMP::Interfaces;
use Socket;
my $ifname;
my $hostname;
my $community;
my $version = 1;



# Make sure this script is run as root (required by arp-scan :> )
die("This script must be run as root") unless  $> == 0;



#GetOptions( "ifname=s"      => \$ifname,
#            "host=s"        => \$hostname,
#            "community=s"   => \$community,
#            "protocol:s"    => \$version);
#
#print "Running\n";
#my $interfaces = Net::SNMP::Interfaces->new(Hostname => $hostname, Community => $community);
#my @interfaces = $interfaces->all_interfaces();
#my $inter = $interfaces->interface($ifname);
#
#
##We get the index of $ifname
#my $ifindex = $inter->index();
##Speed
#my $vitesse = $inter->ifHighSpeed();
##Alias
#my $ifalias = $inter->ifAlias();
#my $ifdescr = $inter->ifDescr();
#my $ifstatus = $inter->ifOperStatus();
#
#foreach my $interface (@interfaces) {
#	print "index: ", $interface->index(), " speed: ",$interface->ifHighSpeed(), " ifalias: ", $interface->ifAlias()," description: ",$interface->ifDescr(), " status: ", $interface->ifOperStatus()."\n";
#}
#
#my $session = $interfaces->session();
#
#my $result = $session->get_table("1.3.6.1.2.1.17.7.1.2.2.1.2");
#print Dumper $result;



#my $mac_addr = "b8:27:eb:24:ef:63";
#print $host."\n";

my @ifaces = ("labvpn","mgmtvpn");


my $mac = "b8:27:eb:b1:9b:d2";

my $name = mac2hostname($mac);
print "name: ".$name."\n";

sub valid_mac {
	my ($input_mac) = @_;

	# TODO: Check capital 
	return $input_mac =~ /^([0-9a-f]{2}([:-]|$)){6}$/i;
}

sub mac2hostname {
	my ($mac_addr) = @_;
        croak("MAC address is invalid: $mac_addr") unless valid_mac($mac_addr);

	my $ip;
	foreach my $iface (@ifaces){
		$ip = mac2ip($mac_addr, $iface);
		last if $ip;
	}

	unless($ip){
		print "No IP found to MAC: $mac\n";
		return undef;
	}

	my $host = ip2hostname($ip);
	return $host;
}

sub mac2ip {
	my ($mac_addr, $interface) = @_;

	my $cmd = "/usr/sbin/arp-scan --interface $interface  --localnet | grep -i $mac_addr | awk '{print \$1}'";
	my $ip = `$cmd`;
	chomp $ip;
	return $ip;
}

sub ip2hostname {
	my ($ip) = @_;

	my $iaddr = inet_aton($ip); # or whatever address
	my $name  = gethostbyaddr($iaddr, AF_INET);
	unless ($name){
		print "No hostname is available for IP: ". $ip."\n";
		return undef;
	}
	return $name;
}
