use warnings;
use strict;
use Data::Dumper;
use Storable;
use GraphViz;
 
my $g = GraphViz->new("directed"=>0,"concentrate"=>1,"overlap"=>"false","layout"=>"twopi");
 


my %networks = %{retrieve("network")};

foreach my $switch(keys %networks){
	$g->add_node($switch);
	print "switch: $switch\n";
	my $linksa = $networks{$switch};
	my $links = $linksa ->{'switches'};
	foreach my $link (keys %{$links}){
		$g->add_edge($switch => $link);
	}

	delete $linksa->{'switches'};
	foreach my $host (values %{$linksa}){
		my $hosta = @{$host}[0];
		my $hostip = $hosta->{'ip'};
		my $hostname = $hosta->{'hostname'};

		my $nodename = "PC\n$hostname\n$hostip";
		$g->add_node($nodename,"shape"=>"box","fillcolor"=>"green","style"=>"filled");
		$g->add_edge($switch=>$nodename);
	}

}


#$g->add_node('London');
#$g->add_node('Paris', label => 'City of\nlurve');
#$g->add_node('New York');
# 
#$g->add_edge('London' => 'Paris');
#$g->add_edge('London' => 'New York', label => 'Far');
#$g->add_edge('Paris' => 'London');
 
print $g->as_png("image.png");
