#!/usr/bin/perl -w

use strict;
use ControlFlowGraph;
use ControlFlowNode;
use XML::Simple;
use Data::Dumper;

if($#ARGV != 0) {
    print "$0 path\n";
    exit;
}
my ($APK_FILE_PATH) = @ARGV ;
my $PACKAGE;
my %APP_ENTRY_POINTS = (
    activity => [],
    service => [],
    receiver => [],
    provider => [],
);
my %ENTRY_POINT = (
    activity => ["onCreate"],
    service => ["onStartCommand"],
    receiver => ["onReceive"],
    provider => ["onUpdate"]
);
my @METHOD_CFG;
my $DIR_PATH = $APK_FILE_PATH;
$DIR_PATH =~ s/\.apk//;

Main();

sub getSourceFromAPK {
    my ($apkFilePath) = @_;
    system("./analyzeAPK.sh $apkFilePath");

}
sub parseAndroidManifest {
    my ($androidManifestXML) = @_;

    my $data = new XML::Simple->XMLin("$androidManifestXML");
    ###
    # assign global variable
    ###
    $PACKAGE = $data->{package};
    my $applications = $data->{application};
    ###
    #  I get the entry method first (for each component)
    ###
    for my $component (keys %APP_ENTRY_POINTS) {
        if (exists $applications->{$component}) {
            my $componentSet = $applications->{$component};
            my $reference = ref($componentSet);
            if($reference eq 'HASH') {
                push(@{$APP_ENTRY_POINTS{$component}}, {classname=>$componentSet->{'android:name'}});
                # record provider name
                #if($component eq "provider") {
                #    recordProviderNameToFile($componentSet->{'android:name'});
                #}
            }
            elsif($reference eq 'ARRAY'){
                ###
                #  each will be one of components
                ###
                my @cSet = @{$componentSet};
                for my $i (0..@cSet-1) {
                    my $eachComponent = $cSet[$i];
                    push(@{$APP_ENTRY_POINTS{$component}}, {classname=>$eachComponent->{'android:name'}});
                    # record provider name
                    #if($component eq "provider") {
                    #    recordProviderNameToFile($eachComponent->{'android:name'});
                    #}
                }
            }
        }
    }
   #print Dumper(%APP_ENTRY_POINTS);
}

sub recordProviderNameToFile {
    ###
    #  preload app provider need to be recorded
    ###
    my ($providerName) = @_;
    open (my $providerNameFile,">> providerNameList.txt");
    my $checkData = `grep $providerName providerNameList.txt`;
    if ( ! ($checkData =~ m/^$providerName$/) ) {
        print $providerNameFile "$providerName\n";
    }
    close $providerNameFile;
}

sub parseDotFileFromEntryPoint {
    for my $comName (keys %APP_ENTRY_POINTS) {
        for my $i (0..@{$APP_ENTRY_POINTS{$comName}}-1) {
            my $entryPoint = $APP_ENTRY_POINTS{$comName}[$i]->{classname};
            if($entryPoint =~ m/^\..*$/) {
                $entryPoint = "$PACKAGE$entryPoint";
            }
            for my $j (0..@{$ENTRY_POINT{$comName}}-1) {
                parseMethodDotFile($entryPoint, $ENTRY_POINT{$comName}[$j]);
            }
        }
    }
}
sub parseMethodDotFile {
    my ($entryPointClass, $entryPointMethod) = @_;
    
    ###
    # parse the full fileName
    ###
    my $classPath = "$DIR_PATH/sootOutput/$entryPointClass";
    my $methodName = `ls -1 '$classPath' | grep '$entryPointMethod('`;
    chomp($methodName);
    my $fileName = `grep -lR $entryPointMethod '$classPath/$methodName'`;
    chomp($fileName);
    $fileName =~ s/\r+//g;
    my $methodCFG;
    my @nodeArray;
    print $fileName, "\n";
    open(my $FILE, "< $fileName");
    while(<$FILE>) {
        if($_ =~ m/label="(.*)";/) {
            my $node = new ControlFlowNode(-1,$1);
            $methodCFG->{_root} = $node;
            push(@{$node->{_prevNode}}, $node);
            $methodCFG = new ControlFlowGraph($methodName,$node);
        }
        elsif($_ =~ m/.*\"(\d+)\"->\"(\d+)\".*/) {
            push(@{$nodeArray[$1]->{_nextNode}},$nodeArray[$2]);
            push(@{$nodeArray[$2]->{_prevNode}},$nodeArray[$1]);
        }
        elsif($_ =~ m/.*\"(\d+)\" \[.*label=\"(.*)\",\];/) {
            my $node = new ControlFlowNode($1,$2);
            $nodeArray[$1]=$node;
            if($1 == 0) {
                push(@{$methodCFG->{_root}->{_nextNode}}, $nodeArray[$1]);
                push(@{$node->{_prevNode}}, $methodCFG->{_root});
            }
            ###
            #  need find the type of local vars
            ###
            my $statement = $2;
            if($statement =~ m/(.*) :?= (.*)/) {
                # r0 = this
                my $localVar = $1;
                my $varType = $2;
                if($varType eq '@this') {
                   $varType = "$entryPointClass";
                }
                # rx = @parameterX
                elsif($varType =~ m/\@parameter(\d+)/) {
                    my $numOfPara = $1;
                    my ($parameter) = $methodName =~ m/.*\((.*)\)/;
                    for my $i (1..$numOfPara) {
                        $parameter =~ s/^[^,]*,(.*)$/$1/;
                    }
                    $parameter =~ s/^([^,]*),.*$/$1/;
                    $varType = $parameter;
                }
                # rx = (Typecast) ry
                elsif($varType =~ m/\((.*)\) .*/) {
                    $varType = $1;
                }
                $methodCFG->{_local}->{$localVar} = $varType;
            }

            ###
        }
    }
    close $FILE;
    #$methodCFG->dumpGraph;
    print Dumper($methodCFG->{_local});
}

sub Main{
    ######
    # use analyzeapk to retrieve the source file and java bytecode cfg dot file
    ######
    #getSourceFromAPK($APK_FILE_PATH);

    ######
    # parse AndroidManifest to find entry point for each component
    ######
    parseAndroidManifest("$DIR_PATH/AndroidManifest-real.xml");

    ######
    # parse each dot file of Method to CFG
    ######
    parseDotFileFromEntryPoint();

}
