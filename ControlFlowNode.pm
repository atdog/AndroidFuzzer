package ControlFlowNode;

sub new{
    my $class = shift;
    my $self = {
        _prevNode => [],
        _nextNode => [],
        _nextUINode => [],
        _nodeNum => shift,
        _label => shift,
        _subMethod => undef,
        _subMethodUIEvent => undef,
        _methodCFG => undef,
        _return => undef,
        _pathID => 0,
        _scanQueryID => 0
    };
    bless $self, $class;
    return $self;
}

#sub dumpNode {
#    my ($self) = @_;
#    return "$self->{_nodeNum}:$self->{_label}\n";
#}


1;
