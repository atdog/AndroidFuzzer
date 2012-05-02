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
my $RECORD_MODE = 0;
my $ANDROID_PATH = "/System/Library/Frameworks/JavaVM.framework/Classes/classes.jar:/Users/atdog/Desktop/myWork/tools/lib/android-4.0.3.jar";
my $JARPATH = "/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/core/classes_dex2jar.jar:/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/bouncycastle/classes_dex2jar.jar:/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/ext/classes_dex2jar.jar:/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/framework/classes_dex2jar.jar:/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/android.policy/classes_dex2jar.jar:/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/services/classes_dex2jar.jar:/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/core-junit/classes_dex2jar.jar:/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/com.htc.commonctrl/classes_dex2jar.jar:/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/com.htc.framework/classes_dex2jar.jar:/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/com.htc.android.pimlib/classes_dex2jar.jar:/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/com.htc.android.easopen/classes_dex2jar.jar:/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/com.scalado.util.ScaladoUtil/classes_dex2jar.jar:/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/com.orange.authentication.simcard/classes_dex2jar.jar:/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/android.supl/classes_dex2jar.jar:/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/kafdex/classes_dex2jar.jar";
my ($APK_FILE_PATH) = @ARGV ;
my $PACKAGE;
my %APP_ENTRY_POINTS = (
    activity => [],
    service => [],
    receiver => [],
    provider => [],
);
my %ENTRY_POINT = (
    activity => [{
            name => "onCreate",
            paras => "android.os.Bundle"
        }],
    service => [{
            name => "onStartCommand",
            paras => "android.content.Intent,int,int"
        }],
    receiver => [{
            name => "onReceive",
            paras => "android.content.Context,android.content.Intent" 
        }],
    provider => [{
            name => "onCreate",
            paras => ""
        }]
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
                if ($componentSet->{'android:name'} =~ m/^\..*$/) {
                    push(@{$APP_ENTRY_POINTS{$component}}, {classname=>$componentSet->{'android:name'}});
                }
                else {
                    print "* ignore some component: $componentSet->{'android:name'}\n";
                }
                # record provider name
                if($component eq "provider") {
                    recordProviderNameToFile($componentSet->{'android:name'},$PACKAGE, $componentSet->{'android:authorities'});
                }
            }
            elsif($reference eq 'ARRAY'){
                ###
                #  each will be one of components
                ###
                my @cSet = @{$componentSet};
                for my $i (0..@cSet-1) {
                    my $eachComponent = $cSet[$i];
                    if( $eachComponent->{'android:name'} =~ m/^\..*$/) {
                        push(@{$APP_ENTRY_POINTS{$component}}, {classname=>$eachComponent->{'android:name'}}) ;
                    }
                    else {
                        print "* ignore some component: $eachComponent->{'android:name'}\n";
                    }
                    # record provider name
                    if($component eq "provider") {
                        recordProviderNameToFile($eachComponent->{'android:name'},$PACKAGE, $eachComponent->{'android:authorities'});
                    }
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
    my ($providerName, $packageName, $authorities) = @_;
    if($RECORD_MODE == 0) {
        return;
    }
    open (my $providerNameFile,">> providerNameList.txt");
    my $checkData = `grep $providerName providerNameList.txt`;
    if ( ! ($checkData =~ m/^$providerName$/) ) {
        print $providerNameFile "Provider: $providerName\n";
        print $providerNameFile "    Package:     $packageName\n";
        print $providerNameFile "    Authorities: $authorities\n";
    }
    close $providerNameFile;
}

sub parseDotFileFromEntryPoint {
    for my $comName (keys %APP_ENTRY_POINTS) {
        for my $i (0..@{$APP_ENTRY_POINTS{$comName}}-1) {
            my $entryPoint = $APP_ENTRY_POINTS{$comName}[$i]->{classname};
            if($entryPoint =~ m/^\..*$/ ) {
                $entryPoint = "$PACKAGE$entryPoint";
            }
            my $fileName;
            my $classPath;
            for my $j (0..@{$ENTRY_POINT{$comName}}-1) {
                $classPath = "$DIR_PATH/sootOutput/$entryPoint";
                if( not -d $classPath) {
                    print "-------------> [0;31m$classPath not found[0m\n";
                    return;
                }
                $fileName = `./getMethodDot.pl '$classPath' '$ENTRY_POINT{$comName}[$j]->{name}' '$ENTRY_POINT{$comName}[$j]->{paras}' '$JARPATH'`;
                parseMethodDotFile($entryPoint, $ENTRY_POINT{$comName}[$j]->{name},$ENTRY_POINT{$comName}[$j]->{paras}, $fileName);
            }
        }
    }
}
sub parseMethodDotFile {
    my ($entryPointClass, $entryPointMethod, $entryPointMethodParas, $dotFileName) = @_;
    ###
    # parse the full fileName
    ###
    my $methodCFG;
    my @nodeArray;
    print $dotFileName, "\n";
    open(my $FILE, "< $dotFileName");
    while(<$FILE>) {
        if($_ =~ m/label="(.*)";/) {
            my $node = new ControlFlowNode(-1,$1);
            $methodCFG->{_root} = $node;
            push(@{$node->{_prevNode}}, $node);
            $methodCFG = new ControlFlowGraph($dotFileName,$node);
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
            my $statement = $2;
            print "[1;35m$statement[0m\n";
            ###
            #  find the invokation to the next method CFG
            ###
            if($statement =~ m/^(?:specialinvoke )?([^ ]*\(.*\))$/){ 
                my $invokation = $1;
                if($invokation =~ m/^(?:new )?([^\.]*)\.([^\.]*)\((.*)\)$/) {
                    my $parasOfInvokation = parseParas($methodCFG,$3);
                    my $subMethodFile = "";
                    if(exists $methodCFG->{_local}->{$1}) {
                        print "-=-=-=-> invokation: $methodCFG->{_local}->{$1}.$2($parasOfInvokation)\n";
                        $subMethodFile = `./getMethodDot.pl '$DIR_PATH/sootOutput/$methodCFG->{_local}->{$1}' '$2' '$parasOfInvokation' '$JARPATH'`;
                    }
                    else {
                        print "-=-=-=-> invokation: $1.$2($parasOfInvokation)\n";
                        $subMethodFile = `./getMethodDot.pl '$DIR_PATH/sootOutput/$1' '$2' '$parasOfInvokation' '$JARPATH'`;
                    }
                    print "-=-=-=-> invoke file: $subMethodFile\n";
                    if($subMethodFile !~ /^ERROR$/) {
                        ####
                        # create sub method CFG
                        ####
                    }
                }
            }
            ###
            #  need find the type of local vars
            ###
            elsif($statement =~ m/([^ ]*) :?= (.*)/) {
                # r0 = this
                my $localVar = $1;
                my $varType = $2;
                if(exists $methodCFG->{_local}->{$varType}) {
                    $varType = $methodCFG->{_local}->{$varType};
                } else {
                    if($varType eq '@this') {
                       $varType = "$entryPointClass";
                    }
                    # rx = @caughtexception
                    elsif($varType =~ m/\@caughtexception/) {
                        $varType = "java.lang.Throwable";
                    }
                    # rx = @parameterX
                    elsif($varType =~ m/\@parameter(\d+)/) {
                        my $numOfPara = $1;
                        my ($parameter) = $dotFileName =~ m/.*\((.*)\)/;
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
                        my $returnType = fieldChecker($className, $fieldName);
                        chomp($returnType);
                        $varType = $returnType;
                        print "-=-=-=-> className: $className\n";
                        print "-=-=-=-> fieldName: $fieldName\n";
                        print "-=-=-=-> returnType: $returnType\n";
                    }
                    # rx = new classname
                    elsif($varType =~ m/^new ([a-zA-Z0-9\.\$]*)$/) {
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
                        my $parasToCheck = parseParas($methodCFG,$parameter);
                        print "-=-=-=-> className: $className\n";
                        print "-=-=-=-> apiName: $apiName($parameter)\n";
                        # run typeChecker.jar
                        my $returnType;
                        if($parasToCheck eq "") {
                            $returnType = methodChecker($className, $apiName);
                            print "-=-=-=-> returnType: $returnType";
                        }
                        else {
                            print "-=-=-=-> parameter: $parasToCheck\n";
                            $returnType = methodChecker($className, $apiName, $parasToCheck);
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

sub parseParas{
    my ($methodCFG, $parameter) = @_;
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
        $parasToCheck =~ s/^,(.*)$/$1/;
    }
    return $parasToCheck;
}

sub methodChecker{
    my($c,$m,$p) = @_;
    my $return;
    if(defined $p) {
        $return = `java -jar tools/typeChecker.jar -c '$c' -m $m -e $JARPATH -p $p`;
    } 
    else {
        $return =  `java -jar tools/typeChecker.jar -c '$c' -m $m -e $JARPATH `;
    }
    if($return =~ m/NotFound-JNI/ && defined $p) {
        $return = `java -jar tools/typeChecker.jar -c '$c' -m $m -e $ANDROID_PATH -p $p`;
    }
    elsif($return =~ m/NotFound-JNI/ && not defined $p){
        $return = `java -jar tools/typeChecker.jar -c '$c' -m $m -e $ANDROID_PATH`;
    }
    return $return;
}
sub fieldChecker{
    my($c,$f) = @_;
    my $return;
    $return = `java -jar tools/typeChecker.jar -c '$c' -f $f -e $JARPATH`;
    if($return =~ m/NotFound-JNI/) {
        $return = `java -jar tools/typeChecker.jar -c '$c' -f $f -e $ANDROID_PATH`;
    }
    return $return;
}
sub Main{
    ######
    # use analyzeapk to retrieve the source file and java bytecode cfg dot file
    ######
    #getSourceFromAPK($APK_FILE_PATH);

    ######
    # parse AndroidManifest to find entry point for each component
    ######
    $JARPATH = "$JARPATH:$DIR_PATH/classes_dex2jar.jar";
    $ANDROID_PATH = "$ANDROID_PATH:$DIR_PATH/classes_dex2jar.jar";
    parseAndroidManifest("$DIR_PATH/AndroidManifest-real.xml");

    ######
    # parse each dot file of Method to CFG
    ######
    parseDotFileFromEntryPoint();

}
