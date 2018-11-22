use strict;
use warnings;
use Getopt::Long;
use Net::SNMP;
use Data::Dumper;
use Net::SNMP::Interfaces;
    use Socket;
my $ifname;
my $hostname;
my $community;
my $version = 1;
#
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



my $mac_addr = "b8:27:eb:24:ef:63";
my $ip = `/usr/sbin/arp-scan --interface labvpn  --localnet | grep -i $mac_addr | awk '{print \$1}'`;
chomp $ip;
print "mac: $mac_addr => ip: $ip hostname: ";
my $iaddr = inet_aton($ip); # or whatever address
my $name  = gethostbyaddr($iaddr, AF_INET);
print $name."\n";

