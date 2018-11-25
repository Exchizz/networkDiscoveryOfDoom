#!/usr/bin/perl

use strict;
use warnings;
use Carp;
use Getopt::Long;
use Net::SNMP;
use Data::Dumper;
use Net::SNMP::Interfaces;
use Socket;
use Net::Subnet;
use Storable;
use SNMP::Info;



my $ifname;
my $community;
my $version = 1;
my $entryswitch = "";
my $loadfromlist = 0;

# Make sure this script is run as root (required by arp-scan :> )
die("This script must be run as root") unless  $> == 0;

GetOptions( "ifname=s"      => \$ifname,
            "entryswitch=s"        => \$entryswitch,
            "community=s"   => \$community,
            "loadfromlist!"   => \$loadfromlist,
            "protocol:s"    => \$version);






#my $host = snmp_port2lag("25");
#print "port g25 is connected to ldap:  $host\n";
#lldp_get_switches("192.168.254.15");


my @ifaces = ("labvpn","mgmtvpn");

# ======== Load from file - save time during development ========== #
my %network;

my @to_be_discovered = ($entryswitch);
my %is_discovered = ($entryswitch => 1);

while(@to_be_discovered){
	my $ip = shift @to_be_discovered;
	print "Discovering $ip\n";
	my %tmp = discover_switch($ip);
	store \%tmp, 'debug';
	#my %tmp = %{retrieve('debug')};
	foreach my $s (keys %tmp){
		my $a = $tmp{$s};
		my $ip = $a->{'IP'};
		print "Uplink ip: $ip\n";
		if(!exists $is_discovered{$ip}){
			print "Adding $ip to \"to_be_discovered\"\n";
			push @to_be_discovered, $ip;
			$is_discovered{$ip} = 1;
		}
	}
	
	store \%network, 'network';
}




sub discover_switch {
	my ($switch_ip) = @_;
	
	my $interface_map = snmp_get_ifnames($switch_ip);
	my %rsp = snmp_get_mac_addr_list($switch_ip);
	
	my %management_interfaces;
	
	foreach my $ifaze (keys %rsp){
		my $port = $rsp{$ifaze};
		foreach my $mac (@{$port}){
			my $mac = $mac->{'mac'};
			my $ip;
			foreach my $iface (@ifaces){
				$ip = mac2ip($mac, $iface);
				last if $ip;
			}
			unless($ip){
				print "No IP found to MAC: $mac\n";
				next;
			}
	
			if(ip_is_mgmt($ip, $switch_ip)){
				print "$ip is mgmt - don't track this interface: $ifaze\n";
				$management_interfaces{$ifaze} = 1;
			} else {
				print "$ip is not mgmt\n";
				push @{$network{$switch_ip}{$ifaze}}, {"ip" => $ip, "mac" => $mac};
			}
			#		my $hostname = ip2hostname($ip);
			#		print "debug: ".$mac."\tIP:".$ip."\tHostname:".$hostname."\n";
			#		#		print "debug: ".%{@{$mac}[0]}{'mac'}."\n";
		}
	
	}
	print "Cleaning network (removing interface if connected to switch)\n";
	
	foreach my $mgmt_iface (keys %management_interfaces){
		if (exists $network{$switch_ip}{$mgmt_iface}){
			delete $network{$switch_ip}{$mgmt_iface};
		}
	}
	my %uplinks = lldp_get_switches($switch_ip, $interface_map);
	$network{$switch_ip}{'switches'} = \%uplinks;
	
	print Dumper \%network;
	return %uplinks;
}




sub lldp_get_switches {
	my ($ip, $interface_map) = @_;
	my $lldp = new SNMP::Info (
                            AutoSpecify => 1,
                            Debug       => 0,
                            DestHost    => $ip,
                            Community   => 'public',
                            Version     => 2
                          );

			  #my $class = $lldp->class();
	# print " Using device sub class : $class\n";
	
	#	my $haslldp   = $lldp->hasLLDP() ? 'yes' : 'no';
	
	# Print out a map of device ports with LLDP neighbors:
	my $interfaces    = $lldp->interfaces();
	my $lldp_if       = $lldp->lldp_if();
	my $lldp_ip       = $lldp->lldp_ip();
	my $lldp_port     = $lldp->lldp_port();

	my %uplinks;
	foreach my $lldp_key (keys %$lldp_ip){
	   my $iid           = $lldp_if->{$lldp_key};
	   my $port          = $interfaces->{$iid};
	   my $neighbor      = $lldp_ip->{$lldp_key};
	   my $neighbor_port = $lldp_port->{$lldp_key};
	   my $LAG = snmp_port2lag($ip,$port, $interface_map);
	   $uplinks{$LAG}{'IP'} = $neighbor;
	   push @{$uplinks{$LAG}{'ports'}}, {"port" => $port};
	}
	return %uplinks;
}

#die();
#
#
#foreach my $mac (keys %rsp){
#
#	my $ip;
#	foreach my $iface (@ifaces){
#		$ip = mac2ip($mac, $iface);
#		last if $ip;
#	}
#
#	#unless($ip){
#	#	print "No IP found to MAC: $mac_addr\n";
#	#	return undef;
#	#}
#	if(ip_is_mgmt($ip)){
#		print "$ip ss on mgmt network!\n";
#		next;
#	}
#
#	my $hostname = ip2hostname($ip);
#	print "Mac. $mac\tHostname: $hostname\tIP: $ip\n";
#}
#

sub port_is_uplink {
	my ($mac_addr) = @_;
	my $ip = mac2ip($mac_addr);	

	my $interfaces = Net::SNMP::Interfaces->new(Hostname => $ip, Community => $community);
	unless ($interfaces){
		print "Unable to connect to IP: $ip, does not seem to be a switch" ;
		return undef;
	}
}


sub valid_mac {
	my ($input_mac) = @_;

	# TODO: Check capital 
	return $input_mac =~ /^([0-9a-f]{2}([:-]|$)){6}$/i;
}

sub mac2ip {
	my ($mac_addr, $interface) = @_;

        croak("MAC address is invalid: $mac_addr") unless valid_mac($mac_addr);
	my $cmd = "/usr/sbin/arp-scan --interface $interface  --localnet | grep -i $mac_addr | awk '{print \$1}'";
	my $ip = `$cmd`;
	chomp $ip;
	return $ip;
}

sub ip2hostname {
	my ($ip) = @_;

	my $iaddr = inet_aton($ip); # or whatever address
	unless ($iaddr) {
		return "N/A";
	}
	my $name  = gethostbyaddr($iaddr, AF_INET);
	unless ($name){
		#print "No hostname is available for IP: ". $ip."\n";
		return "N/A";
	}
	return $name;
}



sub snmp_port2lag {
	my ($ip,$port,$interface_map) = @_;

	($port) = $port =~ /([\d]+)/;
	my $session = Net::SNMP->session(-hostname => $ip, -community => "public");

	my $oid = "1.2.840.10006.300.43.1.2.1.1.13.".$port;
	my $result = $session->get_request($oid);

	my $name = $interface_map->{$result->{$oid}};
	unless($name){
		$name = "N/A";
	}
	return  $name;
}


sub snmp_get_ifnames {
	my ($ip) = @_;

	my $interfaces = Net::SNMP::Interfaces->new(Hostname => $ip, Community => "public");
	unless ($interfaces){
		print "Unable to connect to IP: $ip, does not seem to be a switch" ;
		return undef;
	}
	my @interfaces = $interfaces->all_interfaces();
	#my $inter = $interfaces->interface($ifname);
	
	
	#We get the index of $ifname
	#my $ifindex = $inter->index();
	##Speed
	#my $vitesse = $inter->ifHighSpeed();
	##Alias
	#my $ifalias = $inter->ifAlias();
	#my $ifdescr = $inter->ifDescr();
	#my $ifstatus = $inter->ifOperStatus();
	
	my %interfaces_map = map { $_->index() => $_->ifDescr() } @interfaces;

	return \%interfaces_map;
}


sub snmp_get_mac_addr_list {
	my ($ip) = @_;

	my $interfaces = Net::SNMP::Interfaces->new(Hostname => $ip, Community => $community);
	unless ($interfaces){
		print "Unable to connect to IP: $ip, does not seem to be a switch" ;
		return undef;
	}
	my @interfaces = $interfaces->all_interfaces();
	#my $inter = $interfaces->interface($ifname);
	
	
	#We get the index of $ifname
	#my $ifindex = $inter->index();
	##Speed
	#my $vitesse = $inter->ifHighSpeed();
	##Alias
	#my $ifalias = $inter->ifAlias();
	#my $ifdescr = $inter->ifDescr();
	#my $ifstatus = $inter->ifOperStatus();
	#
	my %interfaces_map = map { $_->index() => $_->ifDescr() } @interfaces;
	print Dumper \%interfaces_map;
	#	foreach my $interface (@interfaces) {
	#		print "index: ", $interface->index(), " speed: ",$interface->ifHighSpeed(), " ifalias: ", $interface->ifAlias()," description: ",$interface->ifDescr(), " status: ", $interface->ifOperStatus()."\n";
	#	}	

	my $session = $interfaces->session();
	

	my $oid = "1.3.6.1.2.1.17.7.1.2.2.1.2";
	my $results = $session->get_table($oid);

	my $regex_vlan = "(\\d{1,3})";
	my $regex_mac_dec = "((?>[\\d]+[\.]?){6})";

	#my @ret = ();
	my %ret;
	foreach my $result (keys %{$results}){
		my $iface_index = $results->{$result};
	        my ($vlan, $mac_dec) = $result =~ /^$oid\.$regex_vlan\.$regex_mac_dec$/;

		# Convert dec to hex
	        my $mac_hex = $mac_dec =~ s/([\d]{1,3})[\s]?/sprintf("%02x", $1)/gre;	
		
		# Replace '.' with ':'
		$mac_hex =~ s/\./:/g;
		#		unless (exists $ret{$iface_index}) {
		#			$ret{$iface_index} = ();
		#		}
		push @{$ret{$interfaces_map{$iface_index}}}, {"mac" => $mac_hex};
#		push @ret, $mac_hex;
	}
	return %ret;
}



 
sub ip_is_mgmt {
	my ($ip, $switch_ip) = @_;
	
	# Mixed IPv4 and IPv6
	my $mgmt_subnet = subnet_matcher ($switch_ip."/24");
	 
	return $mgmt_subnet->($ip);
}


