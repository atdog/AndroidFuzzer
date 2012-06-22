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
    #GetRemainPathFromQ($self->{_root}, [], []);
    FindAllQueryAPINode($self->{_root}, $CandidateNodeArray, $CandidatePathArray, $PathToCandidateNode, []); 
    #GetRemainPath($CandidateNodeArray,$AllPathArray);
    

    print "Start -> ",$self->{_methodName},"\n";
    #dumpNode($node, $stack);
}

sub GetRemainPath {
    my ($CandidateNodeArray, $AllPathArray) = @_;
    for $candidateNode (@$CandidateNodeArray) {
        my $path = [];
        GetRemainPathFromQ($candidateNode, $path, []);
    }
}

sub GetRemainPathFromQ {
    my ($node, $path, $returnStack) = @_;
    # stop condition
    #  1. find circle
    #  2. no next node
    $node->{_pathID} = $PATH_ID;
    push @$path, $node;
    #print "$node->{_nodeNum}: $node->{_label} nextNode:$#{$node->{_nextNode}}, nextUINode: $#{$node->{_nextUINode}}, file:$node->{_methodCFG}->{_methodName}\n";
    # check the stop condition
    if($#{$node->{_nextNode}} == -1 && $#{$node->{_nextUINode}} == -1 && $#{$returnStack} == -1) {
        # find the end point
        # dump and save the candidate node
        for my $nodeInPath (@$path) {
            if($nodeInPath->{_label} =~ m/\.query\(.+\)/) {
                print "^[[0;34m===> path start^[[0m\n";
                #print "$_->{_nodeNum}: $_->{_label}\n" for @$path;
                #print "^[[0;34m===> path end^[[0m\n";
                break;
            }
        }
        $PATH_ID ++;
        return;
    }
    # submethod call 
    my $nextNodeArray;
    if($#{$node->{_nextNode}} == -1 && $#{$returnStack} > -1) {
        $lastReturn = pop @$returnStack;
        push @$nextNodeArray, @$lastReturn;
    }
    else {
        if(defined $node->{_subMethod} && ( not defined $node->{_subMethodUIEvent} )&& $node->{_subMethod}->{_root}->{_pathID} < $PATH_ID) {
            push @$nextNodeArray, $node->{_subMethod}->{_root};
            push @$returnStack, $node->{_nextNode};
        } 
        else {
            $nextNodeArray = GetNextNodeArray($node, 0);
        }
    }
    # include the condition - no next node
    # will be an array reference
    for my $nextNode (@$nextNodeArray) {
        # include the condition - circle found
        GetRemainPathFromQ($nextNode, $path, $returnStack) if $nextNode->{_pathID} < $PATH_ID;
        pop @$path;
    }
}

sub FindAllQueryAPINode {
    my ($node, $CandidateNodeArray, $CandidatePathArray, $PathToCandidateNode, $returnStack) = @_;

    # stop condition
    #  1. find circle
    #  2. no next node
    $node->{_scanQueryID} = 1;
    push @$PathToCandidateNode, $node;
    # check the label is 'ContentResolver.query' api or not
    if($node->{_label} =~ m/\.query\(.+\)/) {
        push @{$CandidateNodeArray}, $node;
        # find the end point
        # dump and save the candidate node
        my @path = @$PathToCandidateNode; # this will copy the array to @path
        push @$CandidatePathArray, \@path;
        print "^[[0;34m===> path start^[[0m\n";
        print "$_->{_nodeNum}: $_->{_label}\n" for @$PathToCandidateNode;
        print "^[[0;34m===> path end^[[0m\n";
    }
    if($#{$node->{_nextNode}} == -1 && $#{$node->{_nextUINode}} == -1 && $#{$returnStack} == -1) {
        return ;
    }
    # include the condition - no next node
    # will be an array reference
    my $nextNodeArray;
    if($#{$node->{_nextNode}} == -1 && $#{$returnStack} > -1) {
        $lastReturn = pop @$returnStack;
        push @$nextNodeArray, @$lastReturn;
    }
    else {
        if(defined $node->{_subMethod} && ( not defined $node->{_subMethodUIEvent} )&& $node->{_subMethod}->{_root}->{_pathID} < $PATH_ID) {
            push @$nextNodeArray, $node->{_subMethod}->{_root};
            push @$returnStack, $node->{_nextNode};
        } 
        else {
            $nextNodeArray = GetNextNodeArray($node, 0);
        }
    }
    for my $nextNode (@{$nextNodeArray}) {
        # include the condition - circle found
        FindAllQueryAPINode($nextNode, $CandidateNodeArray, $CandidatePathArray, $PathToCandidateNode, $returnStack) if $nextNode->{_scanQueryID} == 0;
        pop @$PathToCandidateNode;
    }
}

sub GetNextNodeArray {
    my ($node, $getSubmethod) = @_;

    # next node
    my $nextNodeArray = $node->{_nextNode};
    my $nextUINodeArray = $node->{_nextUINode};

    # submethod call 
    if($getSubmethod == 1) {
        if(defined $node->{_subMethod} && (not defined $node->{_subMethodUIEvent})) {
            push @{$nextNodeArray}, $node->{_subMethod}->{_root};
        } 
    }

    # event callback function 
    if($#nextUINodeArray > -1) {
        for my $UINodeHash (@{$node->{_nextUINode}}) {
            push @{$nextNodeArray}, $UINodeHash->{node};
        }
    }

    return $nextNodeArray;
}

sub dumpNode {
    my ($node, $stack) = @_;

    #Stop Condition
    # 1. circle found
}

sub dumpNodeOld{
    #
    #  dumpNode 有問題
    #  若一個function被call過一次以上
    #  其最後一個node的nextNode會有兩個內容
    #  trace 時必須要找上一層call此function的filename做區別
    #
    my ($node, $stack) = @_;
    my @nextNodeArray;
    # check circle first

    #push(@$stack, "$node->{_nodeNum} -> $node->{_label}\n");
    push(@$stack, $node);
    #print "$node->{_nodeNum} -> $node->{_label}\n";

    if(defined $node->{_subMethod} && ( not defined $node->{_subMethodUIEvent} )) {
        #print "Start -> ",$node->{_subMethod}->{_methodName},"\n";
        dumpNode($node->{_subMethod}->{_root}, $stack);
    } 
    @nextNodeArray = @{$node->{_nextNode}};
    @nextUINodeArray = @{$node->{_nextUINode}};
    if($#nextNodeArray == -1 && $#nextUINodeArray == -1 && ( not defined $node->{_return})) {
        for my $elements (@$stack) {
            if($elements->{_label} =~ m/\.query\(.+\)/) {
                # conditional path building - start
                my @conditionalPath;
                for my $stackNode (@$stack) {
                    @stackNodeArray = @{$stackNode->{_nextNode}};
                    if($#stackNodeArray > 0 && (not defined $stackNode->{_subMethod})) {
                        my $isExceptionBranch = 0;
                        for my $innerStackNode (@stackNodeArray) {
                            if($innerStackNode->{_label} =~ m/\@caughtexception/) {
                                $isExceptionBranch = 1;
                            }
                        }
                        if($isExceptionBranch == 0) {
                            #print "$stackNode->{_label}: $stackNode->{_methodCFG}->{_methodName}\n";
                            push(@conditionalPath, $stackNode)
                        }
                    }
                }
                # conditional path building - finish
                purePath(\@conditionalPath);
                print "[0;34m===> path end[0m\n";
                break;
            }
        }
        pop @$stack;
        return;
    } 
    elsif($#nextNodeArray == -1 && $#nextUINodeArray > -1) {
        for my $UINodeHash (@{$node->{_nextUINode}}) {
            dumpNode($UINodeHash->{node}, $stack) ;
        }
    }
    foreach my $nextNode (@nextNodeArray) {
        dumpNode($nextNode, $stack) ;
    }
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
