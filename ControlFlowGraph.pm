package ControlFlowGraph;

use Data::Dumper;

sub new{
    my $class = shift;
    my $self = {
        _methodName => shift,
        _local => {},
        _root => shift,
        _prevNode => []
    };
    bless $self, $class;
    return $self;
}

sub dumpGraph {
    my ($self) = @_;

    my $node = $self->{_root} ;
    my $stack = [];
    dumpNode($node, $stack);
}

sub dumpNode {
    my ($node, $stack) = @_;
    my @nextNodeArray = @{$node->{_nextNode}};
    push(@$stack, "$node->{_nodeNum} -> $node->{_label}\n");
    if($#nextNodeArray == -1) {
        print for @$stack;
        print "[0;34m===> path end[0m\n";
        pop @$stack;
        return;
    } 
    foreach my $nextNode (@nextNodeArray) {
        dumpNode($nextNode, $stack);
    }
}

1;
