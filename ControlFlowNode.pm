package ControlFlowNode;

sub new{
    my $class = shift;
    my $self = {
        _prevNode => [],
        _nextNode => [],
        _nodeNum => shift,
        _label => shift,
        _subMethod => undef,
        _methodCFG => undef,
        _return => {}
    };
    bless $self, $class;
    return $self;
}

#sub dumpNode {
#    my ($self) = @_;
#    return "$self->{_nodeNum}:$self->{_label}\n";
#}


1;
