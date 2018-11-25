use warnings;
use strict;
use Data::Dumper;
use Storable;
use GraphViz;
 
my $g = GraphViz->new();
 


my %networks = %{retrieve("network")};

foreach my $switch(keys %networks){
	$g->add_node($switch);
	print "switch: $switch\n";
	my $linksa = $networks{$switch};
	my $links = $linksa ->{'switches'};
	foreach my $link (keys %{$links}){
		$g->add_edge($switch => $link);
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
