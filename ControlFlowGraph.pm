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
    #push(@$stack, "$node->{_nodeNum} -> $node->{_label}\n");
    push(@$stack, $node);
    #print "$node->{_nodeNum} -> $node->{_label}\n";

    if(defined $node->{_subMethod}) {
        #print "Start -> ",$node->{_subMethod}->{_methodName},"\n";
        dumpNode($node->{_subMethod}->{_root}, $stack) if $nextNode->{_traced} == 0;
    } 
    @nextNodeArray = @{$node->{_nextNode}};
    if($#nextNodeArray == -1) {
        for my $elements (@$stack) {
            if($elements->{_label} =~ m/\.query\(.+\)/) {
                # conditional path building - start
                my @conditionalPath;
                for my $stackNode (@$stack) {
                    @stackNodeArray = @{$stackNode->{_nextNode}};
                    if($#stackNodeArray > 0 && not defined $stackNode->{_subMethod}) {
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
    foreach my $nextNode (@nextNodeArray) {
        dumpNode($nextNode, $stack) if $nextNode->{_traced} == 0;
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
    print "$_->{_label}: $_->{_methodCFG}->{_methodName}\n" for @conditionalPath;
}

1;
