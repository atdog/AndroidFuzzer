package ControlFlowGraph;

use Data::Dumper;

sub new{
    my $class = shift;
    my $self = {
        _methodName => shift,
        _local => {},
        _root => shift,
        _prevNode => [],
        _nodeArray => shift,
        _traced => 0
    };
    bless $self, $class;
    return $self;
}

sub dumpGraph {
    my ($self) = @_;

    my $node = $self->{_root} ;
    my $stack = [];
    print "Start -> ",$self->{_methodName},"\n";
    dumpNode($node, $stack);
}

sub dumpNode{
    #
    #  dumpNode 有問題
    #  若一個function被call過一次以上
    #  其最後一個node的nextNode會有兩個內容
    #  trace 時必須要找上一層call此function的filename做區別
    #
    my ($node, $stack) = @_;
    my @nextNodeArray;
    $node->{_traced} = 1;
    push(@$stack, "$node->{_nodeNum} -> $node->{_label}\n");
    print "$node->{_nodeNum} -> $node->{_label}\n";

    if(defined $node->{_subMethod}) {
        print "Start -> ",$node->{_subMethod}->{_methodName},"\n";
        dumpNode($node->{_subMethod}->{_root}, $stack) if $nextNode->{_traced} == 0;
    } 
    @nextNodeArray = @{$node->{_nextNode}};
    if($#nextNodeArray == -1) {
        for my $elements (@$stack) {
            if($elements =~ m/query\(.+\)/) {
                print for @$stack;
                print "[0;34m===> path end[0m\n";
                break;
            }
        }
        pop @$stack;
        return;
    } 
    foreach my $nextNode (@nextNodeArray) {
        dumpNode($nextNode, $stack) if $nextNode->{_traced} == 0;
    }
}

1;
