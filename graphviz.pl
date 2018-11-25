use warnings;
use strict;
use Data::Dumper;
use Storable;
use GraphViz;
 
sub switch_name {
	my ($networks, $switch_ip) = @_;

	my $linksa = $networks->{$switch_ip};
	my $links = $linksa ->{'switches'};

	my $info = $linksa ->{'info'};

	my $location = $info->{'location'};
	my $sysname = $info->{'sysname'};

	my $name = "Name: $sysname\nLocation: $location\nIP:$switch_ip";
	print "name: $name\n";

	return $name;
}


#my $g = GraphViz->new("directed"=>0,"concentrate"=>1,"overlap"=>"false","layout"=>"twopi");
my $g = GraphViz->new("directed"=>0,"concentrate"=>1,"overlap"=>"false","layout"=>"twopi");

my %networks = %{retrieve("network")};

foreach my $switch(keys %networks){
	my $name = switch_name(\%networks, $switch);
	print "Add node: \"$name\"\n";
	$g->add_node($switch, "label"=>$name);

	my $linksa = $networks{$switch};
	my $links = $linksa ->{'switches'};
	foreach my $link (keys %{$links}){
		$g->add_edge($link => $switch);
	}

	delete $linksa->{'switches'};
	delete $linksa->{'info'};
	foreach my $host (values %{$linksa}){
		my $hosta = @{$host}[0];
		my $hostip = $hosta->{'ip'};
		my $hostname = $hosta->{'hostname'};

		my $nodename = "PC $hostname\n($hostip)";
		$g->add_node($nodename,"shape"=>"box","fillcolor"=>"green","style"=>"filled");
		print "\"$name\" -> \"$nodename\"\n";
		$g->add_edge($nodename=>$switch);
	}

}


print $g->as_png("image.png");
