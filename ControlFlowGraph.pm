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
    dumpNode($node, $stack);
}

sub dumpNode {
    #
    #  dumpNode 有問題
    #  若一個function被call過一次以上
    #  其最後一個node的nextNode會有兩個內容
    #  trace 時必須要找上一層call此function的filename做區別
    #
    my ($node, $stack, $callerFilename, $callerNodeNum) = @_;
    my @nextNodeArray;
    $node->{_traced} = 1;
    push(@$stack, "$node->{_nodeNum} -> $node->{_label}\n");
    print "$node->{_nodeNum} -> $node->{_label}   -   ";

    if(defined $node->{_subMethod}) {
        $nextNodeArray[0] = $node->{_subMethod}->{_root};
        $callerFilename = $node->{_methodCFG}->{_methodName};
        $callerNodeNum = $node->{_nodeNum};
        print "defined $node->{_subMethod}->{_methodName}\n";
        print "------> $callerFilename:$callerNodeNum\n";
    } 
    else {
        print "notdefined, from nextnode\n";
        @nextNodeArray = @{$node->{_nextNode}};
        if($#nextNodeArray == -1) {
            if(defined $node->{_return}->{"$callerFilename:$callerNodeNum"}) {
                $nextNodeArray[0] = $node->{_return}->{"$callerFilename:$callerNodeNum"};
            }
            else {
                for my $elements (@$stack) {
                    if($elements =~ m/query\(.+\)/) {
                        print for @$stack;
                        print "[0;34m===> path end[0m\n";
                        break;
                    }
                }
#                print for @$stack;
#                print "[0;34m===> path end[0m\n";
                pop @$stack;
                return;
            }
        } 
    }
    foreach my $nextNode (@nextNodeArray) {
        dumpNode($nextNode, $stack, $callerFilename, $callerNodeNum) if $nextNode->{_traced} == 0;
    }
}

1;
