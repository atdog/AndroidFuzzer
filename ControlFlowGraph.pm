package ControlFlowGraph;

use Data::Dumper;

my $PATH_ID = 1;

sub new{
    my $class = shift;
    my $self = {
        _methodName => shift,
        _local => {},
        _root => shift,
        _prevNode => [],
        _nodeArray => shift,
    };
    bless $self, $class;
    return $self;
}

sub dumpGraph {
    my ($self) = @_;

    # part 1 find all ContentResolver.query() node
    # part 2 find S -> Q
    #       choose one path to reach it
    # part 3 find Q -> T
    # part 4 combine S->Q->T
    
    my $stack = [];
    my $CandidateNodeArray = []; # query node
    my $CandidatePathArray = []; # S->Q
    my $AllPathArray = []; # Q->T
    my $PathToCandidateNode = [];
    FindAllQueryAPINode($self->{_root}, $CandidateNodeArray, $CandidatePathArray, $PathToCandidateNode, ()); 
    

    print "Start -> ",$self->{_methodName},"\n";
}

sub FindAllQueryAPINode {
    my ($node, $CandidateNodeArray, $CandidatePathArray, $PathToCandidateNode, @returnStack) = @_;
    my $uiHashNode = $node;
    if(defined $node->{node}) {
        $node = $node->{node};
    }
    # stop condition
    #  1. find circle
    #  2. no next node
    $node->{_scanQueryID} = 1;
    push @$PathToCandidateNode, $uiHashNode;
    # check the label is 'ContentResolver.query' api or not
    #print "$node->{_nodeNum}: $node->{_label} - $node->{_methodCFG}->{_methodName}\n" ;
    if($node->{_label} =~ m/\.query\(.+\)/) {
        # find the end point
        # dump and save the candidate node
        print "^[[0;34m===> path start^[[0m\n";
        for my $n (@$PathToCandidateNode) {
            my $nHash = $n;
            if(defined $n->{node}) {
                $nHash = $n->{node};
                print "[1;35m$n->{event}:$n->{view}[0m\n";
            }
            print "$nHash->{_nodeNum}: $nHash->{_label} - $nHash->{_methodCFG}->{_methodName}\n" ;
        }
        print "[0;34m===> path end[0m\n";
    }
    ## stop condition
    #if($#{$node->{_nextNode}} == -1 && $#{$node->{_nextUINode}} == -1 && $#returnStack == -1) {
    #    pop @$PathToCandidateNode;
    #    return ;
    #}
    # include the condition - no next node
    # will be an array reference
    my $nextNodeArray;
    if(defined $node->{_subMethod} && ( not defined $node->{_subMethodUIEvent} )&& $node->{_subMethod}->{_root}->{_scanQueryID} == 0) {
        push @$nextNodeArray, $node->{_subMethod}->{_root};
        push @returnStack, $node->{_nextNode};
    } 
    else {
        $nextNodeArray = GetNextNodeArray($node);
    }
    if($#{$nextNodeArray} == -1 && $#returnStack > -1) {
        $lastReturn = pop @returnStack;
        push @$nextNodeArray, @$lastReturn;
    }
    for my $nextNode (@$nextNodeArray) {
        # include the condition - circle found
        my $hashNode = $nextNode;
        if(defined $nextNode->{node}) {
            $hashNode = $nextNode->{node};
        }
        FindAllQueryAPINode($nextNode, $CandidateNodeArray, $CandidatePathArray, $PathToCandidateNode, @returnStack) if $hashNode->{_scanQueryID} == 0;
    }
    pop @$PathToCandidateNode;
}

sub GetNextNodeArray {
    my ($node) = @_;

    # next node
    my $nextNodeArray = $node->{_nextNode};
    my $nextUINodeArray = $node->{_nextUINode};

    # event callback function 
    if($#{$nextUINodeArray} > -1) {
        for my $UINodeHash (@$nextUINodeArray) {
            push @$nextNodeArray, $UINodeHash;
        }
    }

    return $nextNodeArray;
}

sub dumpNode {
    my ($node, $stack) = @_;

    #Stop Condition
    # 1. circle found
}

sub purePath {
    my ($conditionalPathReference) = @_;
    
    my @conditionalPath = @$conditionalPathReference;
    my %pureConditinalPath = ();
    for my $conditionalNode (@conditionalPath) {
        # label20: if i0 != 0 goto label21: 
        if($conditionalNode->{_label} =~ m/(?:label\d+: )?if (\S+) (\S+ \S+) goto label\d+/) {
            my $nodeDotFile = $conditionalNode->{_methodCFG}->{_methodName};
            my $varName = $1;
            my $condition = $2;
            $pureConditinalPath->{$nodeDotFile}->{$varName}->{"condition"} = [];
            my $localPureConditionalPath = $pureConditinalPath->{$nodeDotFile}->{$varName}->{"condition"};
            # check whether the condition is duplicated
            my $isDuplicated = 0;
            for my $oldCondition (@$localPureConditionalPath) {
                if($oldCondition eq $condition) {
                    $isDuplicated = 1;
                }
            }
            if($isDuplicated == 0) {
                push(@$localPureConditionalPath, $condition);
            }
        }
    }
    for my $UINode (@conditionalPath) {
        #if(defined $UINode->{_nextUINode}[]) {
        #}
        print "$UINode->{_label}: $UINode->{_methodCFG}->{_methodName}\n";
    }
}

1;
