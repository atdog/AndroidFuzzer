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
my $JARPATH = "/Users/atdog/Desktop/evo/framework/core-solve.jar,/Users/atdog/Desktop/evo/framework/bouncycastle-solve.jar,/Users/atdog/Desktop/evo/framework/ext-solve.jar,/Users/atdog/Desktop/evo/framework/framework-solve.jar,/Users/atdog/Desktop/evo/framework/android.policy-solve.jar,/Users/atdog/Desktop/evo/framework/services-solve.jar,/Users/atdog/Desktop/evo/framework/core-junit-solve.jar,/Users/atdog/Desktop/evo/framework/com.htc.commonctrl-solve.jar,/Users/atdog/Desktop/evo/framework/com.htc.framework-solve.jar,/Users/atdog/Desktop/evo/framework/com.htc.android.pimlib-solve.jar,/Users/atdog/Desktop/evo/framework/com.htc.android.easopen-solve.jar,/Users/atdog/Desktop/evo/framework/com.scalado.util.ScaladoUtil-solve.jar,/Users/atdog/Desktop/evo/framework/com.orange.authentication.simcard-solve.jar,/Users/atdog/Desktop/evo/framework/android.supl-solve.jar,/Users/atdog/Desktop/evo/framework/kafdex-solve.jar,../../CallRecorder/classes_dex2jar.jar";
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
            $entryPoint = "$PACKAGE.$entryPoint";
            $entryPoint =~ s/\.\./\./g;
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
            print "[1;35m$statement[0m\n";
            if($statement =~ m/([^ ]*) :?= (.*)/) {
                # r0 = this
                my $localVar = $1;
                my $varType = $2;
                if(exists $methodCFG->{_local}->{$varType}) {
                    $varType = $methodCFG->{_local}->{$varType};
                } else {
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
                    # rx = \"string\"
                    elsif($varType =~ m/^\\"(.*)\\"$/) {
                        $varType = "java.lang.String";
                    }
                    # rx = a.b.c    variable(or constant)
                    elsif($varType =~ m/^([a-zA-Z0-9\.]*)\.([^.\(\)]*)$/) {
                        my $className = $1;
                        my $fieldName = $2;
                        if(exists $methodCFG->{_local}->{$className}) {
                            $className = $methodCFG->{_local}->{$className};
                        }
                        my $returnType = `java -jar typeChecker.jar -c '$className' -f $fieldName -e $JARPATH`;
                        chomp($returnType);
                        $varType = $returnType;
                        print "-=-=-=-> className: $className\n";
                        print "-=-=-=-> fieldName: $fieldName\n";
                        print "-=-=-=-> returnType: $returnType\n";
                    }
                    # rx = new classname
                    elsif($varType =~ m/^new ([a-zA-Z0-9\.]*)$/) {
                        $varType = $1;
                    }
                    # rx = rx.()
                    elsif($varType =~ m/(?:[^ ]* )?(.*)\.([^\.]*)\((.*)\)/) {
                        my $parentType = $1;
                        my $apiName = $2;
                        my $parameter = $3;
                        my $className;
                        print "-=-=-=-> Local var: $parentType\n";
                        if(exists $methodCFG->{_local}->{$parentType}) {
                            $className = $methodCFG->{_local}->{$parentType};
                        }
                        # rx = classname.api()
                        elsif($parentType =~ m/^[a-zA-Z0-9\.]*$/) {
                                $className = $parentType;
                        }
                        # parse parameter
                        my $parasToCheck = "";
                        if(! $parameter eq "") {
                            my @paras = split(/, /,$parameter);
                            for my $para (@paras) {
                                if(exists $methodCFG->{_local}->{$para}) {
                                    $parasToCheck="$parasToCheck,$methodCFG->{_local}->{$para}";
                                }
                                elsif($para =~ m/^\d+$/) {
                                    $parasToCheck="$parasToCheck,int";
                                }
                                elsif($para =~ m/^\\".*\\"$/) {
                                    $parasToCheck="$parasToCheck,java.lang.String";
                                }
                                elsif($para eq "null") {
                                    $parasToCheck="$parasToCheck,null";
                                }
                                # new classname
                                elsif($para =~ m/class \\"(.*)\\"/) {
                                    my $paraClass = $1;
                                    $paraClass =~ s/\//\./g;
                                    $parasToCheck="$parasToCheck,$paraClass";
                                }
                            }
                        }
                        print "-=-=-=-> className: $className\n";
                        print "-=-=-=-> apiName: $apiName($parameter)\n";
                        # run typeChecker.jar
                        my $returnType;
                        if($parasToCheck eq "") {
                            $returnType = `java -jar typeChecker.jar -c '$className' -m $apiName -e $JARPATH`;
                            print "-=-=-=-> returnType: $returnType";
                        }
                        else {
                            $parasToCheck =~ s/^,(.*)$/$1/;
                            print "-=-=-=-> parameter: $parasToCheck\n";
                            $returnType = `java -jar typeChecker.jar -c '$className' -m $apiName -e $JARPATH -p $parasToCheck`;
                            print "-=-=-=-> returnType: $returnType";
                        }
                        chomp ($returnType);
                        if( $returnType !~ m/^NotFound-/) {
                            $varType = $returnType;
                        }
                    }
                }
                $methodCFG->{_local}->{$localVar} = $varType;
            }

            ###
        }
    }
    close $FILE;
    print "==== data ====" , "\n";
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
