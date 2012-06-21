#!/usr/bin/perl 

#use strict;
use ControlFlowGraph;
use ControlFlowNode;
use XML::Simple;
use Data::Dumper;

$DB::deep = 8000;

if($#ARGV != 1) {
    print "$0 path preload\n";
    print "\n";
    print "[Usage] \n";
    print "\t   apk: the file path of the android apk\n";
    print "\tpeload: 0 market app \n";
    print "\t        1 preload app \n";
    exit;
}
my $RECORD_MODE = 0;
my ($APK_FILE_PATH, $IS_PRELOAD) = @ARGV ;
my $PACKAGE;
my %APP_ENTRY_POINTS = (
    activity => [],
    service => [],
    receiver => [],
    provider => [],
);
my %PRIMITIVE_TYPE = (
    int => "I",
    byte => "B",
    short => "S",
    long => "J",
    float => "F",
    double => "D",
    boolean => "Z",
    char => "C"
);
my %JIMPLE_PRIMITIVE_TYPE = (
    i =>     "int",
    b =>     "int",
    l =>     "long",
    z =>     "boolean",
    f =>     "float",
    c =>     "char",
);
my %PRIMITIVE_TYPE_RESOLVE = (
    I =>     "int",
    B =>     "byte",
    S =>     "short",
    J =>     "long",
    F =>     "float",
    D =>     "double",
    Z =>     "boolean",
    C =>     "char",
);
my %ENTRY_POINT = (
    activity => [{
            name => "onCreate",
            paras => "android.os.Bundle"
        }],
#    service => [{
#            name => "onStartCommand",
#            paras => "android.content.Intent,int,int"
#        },{
#            name => "onBind",
#            paras => "android.content.Intent"
#        },{
#            name => "onCreate",
#            paras => ""
#        }],
#    receiver => [{
#            name => "onReceive",
#            paras => "android.content.Context,android.content.Intent" 
#        }],
#    provider => [{
#            name => "onCreate",
#            paras => ""
#        }]
);
my %ALL_VIEW_ID = ();
my %ALL_METHOD_CFG = ();
my %ALL_METHOD_TYPE = ();
my %ALL_UI_EVENT = ();
my $DIR_PATH = $APK_FILE_PATH;
my $APK_FILE_NAME = $APK_FILE_PATH;
my $APP_PATH_IN_ANDROID;
$DIR_PATH =~ s/\.apk//;
$APK_FILE_NAME =~ s/.*\/([^\/]*\.apk)/$1/;

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
                if(checkIntentFilterS($applications->{$component}->{'intent-filter'}) >= 1) {
                    push(@{$APP_ENTRY_POINTS{$component}}, {classname=>$componentSet->{'android:name'}});
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
                    if(checkIntentFilterS($eachComponent->{'intent-filter'}) >= 1) {

                        push(@{$APP_ENTRY_POINTS{$component}}, {classname=>$eachComponent->{'android:name'}}) ;
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

sub checkIntentFilter {
    my ($intentFilter) = @_;
    my $referenceAction = ref($intentFilter->{action});
    my $referenceCategory = ref($intentFilter->{category});
    if($referenceAction eq 'HASH') {
        if($intentFilter->{action}->{'android:name'} eq 'android.intent.action.MAIN') {
            if($referenceCategory eq 'HASH') {
                if($intentFilter->{category}->{'android:name'} eq 'android.intent.category.LAUNCHER') {
                    return 1;
                }
            }
            elsif($referenceCategory eq 'ARRAY') {
                for my $category ( @{$intentFilter->{category}}) {
                    if($category->{'android:name'} eq 'android.intent.category.LAUNCHER') {
                        return 1;
                    }
                }
            }
        }
    }
    elsif($referenceAction eq 'Array') {
        for my $action (@{$intentFilter->{action}}) {
            if($action->{'android:name'} eq 'android.intent.action.MAIN') {
                if($referenceCategory eq 'HASH') {
                    if($intentFilter->{category}->{'android:name'} eq 'android.intent.category.LAUNCHER') {
                        return 1;
                    }
                }
                elsif($referenceCategory eq 'ARRAY') {
                    for my $category ( @{$intentFilter->{category}}) {
                        if($category->{'android:name'} eq 'android.intent.category.LAUNCHER') {
                            return 1;
                        }
                    }
                }
            }
        }
    }
    return 0;
}

sub checkIntentFilterS {
    my ($intentFilterHashOrArray) = @_;
    my $reference = ref($intentFilterHashOrArray);
    my $count = 0;
    if($reference eq 'HASH') {
        my $intentFilter = $intentFilterHashOrArray;
        $count += checkIntentFilter($intentFilter);
    }
    elsif($reference eq 'ARRAY') {
        for my $intentFilter (@$intentFilterHashOrArray) {
            $count += checkIntentFilter($intentFilter);
        }
    }
    return $count;
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
            elsif($entryPoint =~ m/^[^\.]*$/) {
                $entryPoint = "$PACKAGE.$entryPoint";
            }
            my $fileName;
            my $classPath;
            for my $j (0..@{$ENTRY_POINT{$comName}}-1) {
                $classPath = "$DIR_PATH/sootOutput/$entryPoint";
                if( not -d $classPath) {
                    print "-------------> [0;31m$classPath.$entryPoint not found[0m\n";
                    return;
                }
                $fileName = getMethodDot($entryPoint,$ENTRY_POINT{$comName}[$j]->{name},$ENTRY_POINT{$comName}[$j]->{paras});
                if($fileName !~ m/ERROR/) {
                    parseMethodDotFile($entryPoint, $entryPoint, $ENTRY_POINT{$comName}[$j]->{name},$ENTRY_POINT{$comName}[$j]->{paras}, $fileName);
                }
                else {
                    print "-------------> [0;31m$classPath $ENTRY_POINT{$comName}[$j]->{name} not found[0m\n";
                }
            }
        }
    }
}
sub parseMethodDotFile {
    my ($activityName, $entryPointClass, $entryPointMethod, $entryPointMethodParas, $dotFileName) = @_;
    ###
    # parse the full fileName
    ###
    my $methodCFG = {};
    my @nodeArray = ();
    my $endNodeNum;
    print $dotFileName, "\n";
    open(my $FILE, "< $dotFileName");
    while(<$FILE>) {
        if($_ =~ m/label="(.*)";/) {
            my $node = new ControlFlowNode(-1,$1);
            #$methodCFG->{_root} = $node;
            push(@{$node->{_prevNode}}, $node);
            $methodCFG = new ControlFlowGraph($dotFileName,$node,\@nodeArray);
            $node->{_methodCFG} = $methodCFG;
            $ALL_METHOD_CFG->{$dotFileName} = $methodCFG;
        }
        elsif($_ =~ m/.*\"(\d+)\"->\"(\d+)\".*/) {
            push(@{$nodeArray[$1]->{_nextNode}},$nodeArray[$2]);
            push(@{$nodeArray[$2]->{_prevNode}},$nodeArray[$1]);
            if(defined $nodeArray[$1]->{_subMethod} and not defined $nodeArray[$1]->{_subMethodUIEvent}) {
                for my $subMethodNode (@{$nodeArray[$1]->{_subMethod}->{_nodeArray}}) {
                    if(not defined $subMethodNode->{_nextNode}[0]) {
                        #print "$1->$2\n";
                        $subMethodNode->{_return}->{"$dotFileName:$1"} = $nodeArray[$2];
                    }
                }
            }
        }
        elsif($_ =~ m/.*\"(\d+)\" \[.*label=\"(.*)\",\];/) {
            my $node = new ControlFlowNode($1,$2);
            $node->{_methodCFG} = $methodCFG;
            my $nodeNum = $1;
            $nodeArray[$nodeNum]=$node;
            if($1 == 0) {
                push(@{$methodCFG->{_root}->{_nextNode}}, $nodeArray[$1]);
                push(@{$node->{_prevNode}}, $methodCFG->{_root});
            }
            my $statement = $2;
            print "[1;35m$statement[0m\n";
            ###
            #  find the invokation to the next method CFG
            ###
            if($statement =~ m/^(?:label\d+: )?(?:specialinvoke )?([^ ]*\(.*\))$/){ 
                my $invokation = $1;
                if($invokation =~ m/^(?:new )?([^\.]*)\.([^\.\(\)]*)\((.*)\)$/) {
                    my $parasOfInvokation = parseParas($methodCFG,$3,1);
                    my $subMethodFile = "";
                    my $classNameOfInvokation;
                    my $methodNameOfInvokation = $2;
                    if(exists $methodCFG->{_local}->{$1}) {
                        $classNameOfInvokation = $methodCFG->{_local}->{$1};
                    }
                    else {
                        $classNameOfInvokation = $1;
                    }
                    # check whether UIrelated - API call occurs
                    UIEventAPIParser($activityName, $dotFileName, $1, $methodNameOfInvokation, $parasOfInvokation, \@nodeArray, $nodeNum);
                    #
                    print "-=-=-=-> invokation: $classNameOfInvokation.$methodNameOfInvokation($parasOfInvokation)\n";
                    if($classNameOfInvokation =~ m/$PACKAGE/) {
                        $subMethodFile = getMethodDot("$classNameOfInvokation",$methodNameOfInvokation,$parasOfInvokation);
                        print "-=-=-=-> invoke file: $subMethodFile\n";
                        if($subMethodFile !~ /^ERROR$/) {
                            ####
                            # create sub method CFG
                            ####
                            parseMethodDotFile($activityName, $classNameOfInvokation, $methodNameOfInvokation, $parasOfInvokation, $subMethodFile) if not exists $ALL_METHOD_CFG->{$subMethodFile};
                            if(isRecursive($entryPointClass,$entryPointMethod,$entryPointMethodParas,$classNameOfInvokation,$methodNameOfInvokation,$parasOfInvokation) == 0) {
                                $nodeArray[$nodeNum]->{_subMethod} = $ALL_METHOD_CFG->{$subMethodFile};
                                push(@{$ALL_METHOD_CFG->{$subMethodFile}->{_prevNode}}, $nodeArray[$nodeNum]);
                            }
#                            push(@{$ALL_METHOD_CFG{$subMethodFile}->{_nodeArray}[$#{@{$ALL_METHOD_CFG{$subMethodFile}->{_nodeArray}}}]->{_nextNode}}, $nodeArray[$nodeNum]);
                            print "-=-=-=-> subMethod parsing done.\n";
                        }
                    }
                    else {
                        print "-=-=-=-> Dot file not exist.\n";
                    }
                }
            }
            elsif($statement =~ m/^(?:label\d+: )?return(.*)$/) {
                $endNodeNum = $nodeNum;
            }
            ###
            #  need find the type of local vars
            #  need to discard array assignment
            ###
            elsif($statement =~ m/^(?:label\d+: )?([^\[\] ]*) :?= (.*)$/) {
                # r0 = this
                my $localVar = $1;
                my $varType = $2;
                if(exists $methodCFG->{_local}->{$varType}) {
                    if(isInViewId($dotFileName, $varType)) {
                        setViewId($dotFileName,$localVar, getViewId($dotFileName, $varType));
                    }
                    $varType = $methodCFG->{_local}->{$varType};
                    print "-=-=-=-> Found in table: $varType\n";
                } else {
                    # a.b.c = xxx  variable(or constant)
                    if($localVar =~ m/^(.*)\.([^.\(\)]*)$/) {
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
                    # primitive data type
                    elsif($localVar =~ m/^(?:label\d+: )?\$?(f|l|b|i|z|c)\d+.*$/) {
                        my $priVar = $1;
                        if($varType =~ m/^(?:label\d+: )?(?:specialinvoke )?([^\(\)]*)\.([^\.\(\)]*)\((.*)\)$/){
                            my $parentType = $1;
                            my $apiName = $2;
                            my $parameter = $3;
                            my $className;
                            # check whether the view appear
                            if($apiName eq "findViewById") {
                                setViewId($dotFileName,$localVar,$parameter);
                            }
                            #
                            print "-=-=-=-> Local var: $parentType\n";
                            if(exists $methodCFG->{_local}->{$parentType}) {
                                $className = $methodCFG->{_local}->{$parentType};
                            }
                            # rx = classname.api()
                            elsif($parentType =~ m/^[a-zA-Z0-9\.\$]*$/) {
                                    $className = $parentType;
                            }
                            # parse parameter
                            my $parasToCheck = parseParas($methodCFG,$parameter,0);
                            print "-=-=-=-> className: $className\n";
                            print "-=-=-=-> apiName: $apiName($parameter)\n";

                            my $fileName = getMethodDot($className,$apiName,$parasToCheck);
                            if($fileName !~ m/ERROR/) {
                                parseMethodDotFile($activityName, $className, $apiName,$parasToCheck, $fileName) if not exists $ALL_METHOD_CFG->{$fileName};
                                if(isRecursive($entryPointClass,$entryPointMethod,$entryPointMethodParas,$className,$apiName,$parasToCheck) == 0) {
                                    push(@{$ALL_METHOD_CFG->{$fileName}->{_prevNode}}, $nodeArray[$nodeNum]);
                                    $nodeArray[$nodeNum]->{_subMethod} = $ALL_METHOD_CFG->{$fileName};
                                }
#                                    push(@{$ALL_METHOD_CFG{$fileName}->{_nodeArray}[$#{@{$ALL_METHOD_CFG{$fileName}->{_nodeArray}}}]->{_nextNode}}, $nodeArray[$nodeNum]);
                                print "-=-=-=-> subMethod parsing done.\n";
                            }
                            else {
                                print "-------------> [0;31m$className $apiName not found[0m\n";
                            }
                        }
                        $varType = $JIMPLE_PRIMITIVE_TYPE{$priVar};
                        print "-=-=-=-> primitive data type\n";
                        print "-=-=-=-> type: $varType\n";
                    }
                    elsif($localVar =~ m/^(?:label\d+: )?\$?(r)\d+.*$/) {
                        print "-=-=-=-> type: Class\n";
                        if($varType eq '@this') {
                           $varType = "$entryPointClass";
                           print "-=-=-=-> \@this: $varType\n";
                        }
                        # rx = @caughtexception
                        elsif($varType =~ m/\@caughtexception/) {
                            $varType = "java.lang.Throwable";
                            print "-=-=-=-> \@caughtexception: $varType\n";
                        }
                        # rx = @parameterX
                        elsif($varType =~ m/\@parameter(\d+)/) {
                            my $numOfPara = $1;
                            my ($parameter) = $dotFileName =~ m/.*\((.*)\)/;
                            for my $i (1..$numOfPara) {
                                $parameter =~ s/^[^,]*,(.*)$/$1/;
                            }
                            $parameter =~ s/^([^,]*),.*$/$1/;
                            $varType = toJimpleType($parameter);
                            print "-=-=-=-> \@parameter: $varType\n";
                        }
                        # rx = newarray (java.lang.String)[2]
                        elsif($varType =~ m/^newarray \((.*)\)\[.*\]$/) {
                            my $type = $1;
                            if($type =~ m/\./) {
                                $varType = "[L$type;";
                            }
                            else {
                                $varType = "[$PRIMITIVE_TYPE{$type}";
                            }
                            print "-=-=-=-> newarray: $varType\n";
                        }
                        # rx = rx[]
                        elsif($varType =~ m/^(.*)\[.*\]$/) {
                            if(exists $methodCFG->{_local}->{$1}) {
                                my $arrayType = $methodCFG->{_local}->{$1};
                                # [Lcom.android.htcdialer.util.SpeedDialUtils$SpeedDialEntry;'
                                if($arrayType =~ m/^\[(\[*L.*;)$/) {
                                    $varType = $1;
                                    if($varType =~ m/^L(.*);$/) {
                                        $varType = $1;
                                    }
                                }
                                elsif($arrayType =~ m/^\[(\[*.*)$/) {
                                    $varType = $1;
                                    if($varType =~ m/^[^\[]*$/) {
                                        $varType = $PRIMITIVE_TYPE_RESOLVE{$varType};
                                    }
                                }
                                else {
                                    $varType = "ArrayError";
                                }
                            }
                            else {
                                $varType = $1;
                            }
                            print "-=-=-=-> rx[]: $varType\n";
                        }
                        # rx = (Typecast) ry
                        elsif($varType =~ m/^\((.*)\) (.*)$/) {
                            $varType = toJimpleType($1);
                            if(isInViewId($dotFileName, $2)) {
                                setViewId($dotFileName,$localVar, getViewId($dotFileName, $2));
                            }
                            print "-=-=-=-> Casting $varType\n";
                        }
                        # rx = \"string\"
                        elsif($varType =~ m/^\\"(.*)\\"$/) {
                            $varType = "java.lang.String";
                            print "-=-=-=-> \"string\": $varType\n";
                        }
                        # rx = new classname
                        elsif($varType =~ m/^new ([a-zA-Z0-9\.\$]*)$/) {
                            $varType = $1;
                            print "-=-=-=-> new: $varType\n";
                        }
                        # rx = a.b.c    variable(or constant)
                        elsif($varType =~ m/^(.*)\.([^.\(\)]*)$/) {
                            my $className = $1;
                            my $fieldName = $2;
                            if(isInViewId($dotFileName, "$1.$2")) {
                                setViewId($dotFileName,$localVar, getViewId($dotFileName, "$1.$2"));
                            }
                            if(exists $methodCFG->{_local}->{$className}) {
                                $className = $methodCFG->{_local}->{$className};
                            }
                            my $returnType = fieldChecker($className, $fieldName);
                            chomp($returnType);
                            $varType = $returnType;
                            print "-=-=-=-> className: $className\n";
                            print "-=-=-=-> fieldName: $fieldName\n";
                            print "-=-=-=-> returnType: $returnType\n";
                            $methodCFG->{_local}->{"$className.$fieldName"} = $returnType;
                            print "-=-=-=-> assign $className.$fieldName to $returnType\n"
                        }
                        # rx = rx.api()
                        elsif($varType =~ m/^(?:label\d+: )?(?:specialinvoke )?([^\(\)]*)\.([^\.\(\)]*)\((.*)\)$/) 
                        {
                            my $parentType = $1;
                            my $apiName = $2;
                            my $parameter = $3;
                            my $className;
                            # check whether the view appear
                            if($apiName eq "findViewById") {
                                setViewId($dotFileName,$localVar,$parameter);
                            }
                            #
                            print "-=-=-=-> Local var: $parentType\n";
                            if(exists $methodCFG->{_local}->{$parentType}) {
                                $className = $methodCFG->{_local}->{$parentType};
                            }
                            # rx = classname.api()
                            elsif($parentType =~ m/^[a-zA-Z0-9\.\$]*$/) {
                                    $className = $parentType;
                            }
                            # parse parameter
                            my $parasToCheck = parseParas($methodCFG,$parameter,0);
                            print "-=-=-=-> className: $className\n";
                            print "-=-=-=-> apiName: $apiName($parameter)\n";
                            # run typeChecker.jar
                            my $returnType;
                            if($parasToCheck eq "") {
                                $returnType = methodChecker($className, $apiName);
                                print "-=-=-=-> returnType: $returnType\n";
                            }
                            else {
                                print "-=-=-=-> parameter: $parasToCheck\n";
                                $returnType = methodChecker($className, $apiName, $parasToCheck);
                                print "-=-=-=-> returnType: $returnType\n";
                            }
                            if( $returnType !~ m/^NotFound-/) {
                                my $fileName = getMethodDot($className,$apiName,$parasToCheck);
                                if($fileName !~ m/ERROR/) {
                                    parseMethodDotFile($activityName, $className, $apiName,$parasToCheck, $fileName) if not exists $ALL_METHOD_CFG->{$fileName};
                                    if(isRecursive($entryPointClass,$entryPointMethod,$entryPointMethodParas,$className,$apiName,$parasToCheck) == 0) {
                                        push(@{$ALL_METHOD_CFG->{$fileName}->{_prevNode}}, $nodeArray[$nodeNum]);
                                        $nodeArray[$nodeNum]->{_subMethod} = $ALL_METHOD_CFG->{$fileName};
                                    }
#                                    push(@{$ALL_METHOD_CFG{$fileName}->{_nodeArray}[$#{@{$ALL_METHOD_CFG{$fileName}->{_nodeArray}}}]->{_nextNode}}, $nodeArray[$nodeNum]);
                                    print "-=-=-=-> subMethod parsing done.\n";
                                }
                                else {
                                    print "-------------> [0;31m$className $apiName not found[0m\n";
                                }
                                $varType = $returnType;
                            }
                        }
                            #}
                    }
                    else {
                        print "***** miss varType\n";
                    }
                }
                $methodCFG->{_local}->{$localVar} = $varType;
                ####
                # special case, 
                ####
            }

            ###
        }
    }
    close $FILE;
    print "==== data ====" , "\n";
    print Dumper($methodCFG->{_local});

    ###
    #  for android activity lifecycle
    ###
    my $method = "";
    if($entryPointMethod eq "onCreate" && $entryPointMethodParas eq "android.os.Bundle") {
        $method = "onStart";
        $entryPointMethodParas = "";
    }
    elsif($entryPointMethod eq "onStart" && $entryPointMethodParas eq "") {
        $method = "onResume";
        $entryPointMethodParas = "";
    }
    if($method ne "") {
        $subMethodFile = getMethodDot($entryPointClass,$method,$entryPointMethodParas);
        if($method eq "onStart" && $subMethodFile =~ m/^ERROR$/) {
            $subMethodFile = getMethodDot($entryPointClass,"onResume",$entryPointMethodParas);
        }
        print "-=-=-=-> invoke file: $subMethodFile\n";
        if($subMethodFile !~ m/^ERROR$/) {
            parseMethodDotFile($activityName, $entryPointClass, $method, "", $subMethodFile) if not exists $ALL_METHOD_CFG->{$subMethodFile};
            push(@{$ALL_METHOD_CFG->{$subMethodFile}->{_prevNode}}, $nodeArray[$endNodeNum]);
            push(@{$nodeArray[$endNodeNum]->{_nextNode}}, $ALL_METHOD_CFG->{$subMethodFile}->{_root});
            print "-=-=-=-> subMethod parsing done.\n";
        }
        # activity initial finish
        # add ui event branch
        for $UIEventHash (@{$ALL_UI_EVENT->{$activityName}}) {
            # relate to sub UIEventAPIParser
            my $UINode = $UIEventHash->{node}->{_subMethod}->{_root};
            my $UIEvent = $UIEventHash->{event};
            my $UIView = $UIEventHash->{node}->{_subMethodUIEvent};
            push(@{$nodeArray[$endNodeNum]->{_nextUINode}}, {node=>$UINode, event=>$UIEvent, view=>$UIView});
        }
    }
}

sub UIEventAPIParser {
    my($activityName, $dotFileName, $localVar, $apiName, $parasToCheck, $nodeArray, $nodeNum) = @_;
    my @nodes = @$nodeArray;
    if(exists $ALL_VIEW_ID->{$dotFileName}->{$localVar}) {
        my $newMethod = "";
        my $newParas = "";
        # parse api
        if($apiName eq "setAdapter") {
            $newMethod = "instantiateItem";
            $newParas = "android.view.View,int";
        }
        elsif($apiName eq "setOnClickListener") {
            $newMethod = "onClick";
            $newParas = "android.view.View";
            # this mean u must fire the event click to toggle this subMethod(onClick)
            $nodes[$nodeNum]->{_subMethodUIEvent} = $ALL_VIEW_ID->{$dotFileName}->{$localVar};
            push(@{$ALL_UI_EVENT->{$activityName}}, {node=>$nodes[$nodeNum],event=>"click"});
        }
        # parse dot file
        if($newMethod ne ""){ 
            my $fileName = getMethodDot($parasToCheck,$newMethod,$newParas);
            if($fileName !~ m/ERROR/) {
                parseMethodDotFile($activityName, $parasToCheck, $newMethod, $newParas, $fileName) if not exists $ALL_METHOD_CFG->{$fileName};
                push(@{$ALL_METHOD_CFG->{$fileName}->{_prevNode}}, $nodes[$nodeNum]);
                $nodes[$nodeNum]->{_subMethod} = $ALL_METHOD_CFG->{$fileName};
                print "-=-=-=-> subMethod parsing done.\n";
            }
            else {
                print "-------------> [0;31m$className $apiName not found[0m\n";
            }
        }
    }
}

sub setViewId {
    my($file,$var,$viewId) = @_; 
    $ALL_VIEW_ID->{$file}->{$var} = $viewId;
}

sub getViewId {
    my($file,$var) = @_; 
    if(isInViewId($file,$var)) {
        return $ALL_VIEW_ID->{$file}->{$var};
    }
}

sub isInViewId {
    my($file,$var) = @_; 
    if(defined $ALL_VIEW_ID->{$file}->{$var}) {
        return 1;
    }
    return 0;
}

sub toJimpleType {
    my ($parameter) = @_;
    my $varType;
    # int[]...
    if($parameter =~ m/^.*(\[\])+$/) {
        my $dimension = 0;
        my $array = $1;
        while($array =~ m/\[\]/) {
            $dimension++;
            $array =~ s/^\[\](.*)$/$1/;
        }
        $varType = "";
        for my $i (1..$dimension) {
            $varType = "${varType}[";
        }
        if($parameter =~ m/(int|byte|short|long|float|double|boolean|char)(?:\[\])+/) {
            $varType = "$varType$PRIMITIVE_TYPE{$1}";
        }
        # a.b.c[]...
        elsif($parameter =~ m/([\$a-zA-Z\.0-9]*)(?:\[\])+/) {
            $varType = "${varType}L$1;";
        }
    }
    # normal parameter
    else{ 
        $varType = $parameter;
    }
    return $varType;
}

sub parseParas{
    my ($methodCFG, $parameter, $toFileMode) = @_;
    my $parasToCheck = "";
    if($parameter ne "") {
        my @paras = split(/, /,$parameter);
        ###
        #  append the string
        ###
        my @newParas;
        my $startAppend = 0;
        for my $i (0..$#paras) {
            if($paras[$i] =~ m/^\\".*$/ && $paras[$i] !~ m/^.*\\"$/) {
                $startAppend = 1;    
                push @newParas, $paras[$i];
            }
            elsif($paras[$i] !~ m/^\\".*$/ && $paras[$i] =~ m/^.*\\"$/) {
                $startAppend = 0;
                $newParas[$#newParas] .= $paras[$i];
            }
            else {
                if($startAppend == 1) {
                    $newParas[$#newParas] .= $paras[$i];
                }
                else {
                    push @newParas, $paras[$i];
                }
            }
        }
        ###
        for my $para (@newParas) {
            if(exists $methodCFG->{_local}->{$para}) {
                # to file mode: translate [Ljava.lang.String;  [I  -> java.lang.String[] int[]
                if($methodCFG->{_local}->{$para} =~ m/^(\[+)(.*)$/ && $toFileMode == 1) {
                    my $array = $1;
                    my $arrayType = $2;
                    my $dimension = "";
                    while($array =~ m/^\[+$/) {
                        $array =~ s/^\[(\[*)$/$1/;
                        $dimension .= "[]";
                    }
                    if($arrayType =~ m/^L([a-zA-Z0-9\$\.]*);$/ ) {
                        $parasToCheck="$parasToCheck,$1$dimension";
                    }
                    elsif($arrayType =~ m/^(I|B|S|J|F|D|Z|C)$/ ) {
                        $parasToCheck="$parasToCheck,$PRIMITIVE_TYPE_RESOLVE{$1}$dimension";
                    }
                }
                else {
                    $parasToCheck="$parasToCheck,$methodCFG->{_local}->{$para}";
                } 
            }
            elsif($para =~ m/^-?\d+$/) {
                $parasToCheck="$parasToCheck,int";
            }
            elsif($para =~ m/^-?\d+L$/) {
                $parasToCheck="$parasToCheck,long";
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
    my $c = $_[0];
    my $m = $_[1];
    my $p = defined $_[2] ? $_[2] : "";
    my $return;
    if(exists $ALL_METHOD_TYPE{"$c.$m($p)"}) {
        $return = $ALL_METHOD_TYPE{"$c.$m($p)"};
    }
    else {
        my $command;
        if($p ne "") {
            $command="adb shell am startservice -a 'lab.mobile.ntu.TYPE_CHECKER' --es 'classname' '$c' --es 'methodname' '$m' --es 'appname' '$APP_PATH_IN_ANDROID' --es 'parameter' '$p'";
        } 
        else {
            $command="adb shell am startservice -a 'lab.mobile.ntu.TYPE_CHECKER' --es 'classname' '$c' --es 'methodname' '$m' --es 'appname' '$APP_PATH_IN_ANDROID'";
        }
        $command =~ s/\$/\\\$/g;
        $command =~ s/;/\\;/g;
        if(! -d "$DIR_PATH/sootOutput/$c") {
            $command .= " --ez 'private' 'false'";
        }
        system("adb logcat -c");
        system($command);
        #$return = `adb -d logcat -d -v raw -s typeCheckerResult:D | tail -1`;
        my $pid = open my $logcatHandler, "adb logcat -v raw -s typeCheckerResult:D |";
        while(<$logcatHandler>) {
            if($_ !~ m/^--------- beginning of.*/) {
                $return = $_;
                kill 'TERM', $pid;
                close $logcatHandler;
                break;
            }
        }
        $return =~ s/[\r\n]//g;
        $ALL_METHOD_TYPE{"$c.$m($p)"} = $return;
    }
    return $return;
}
sub fieldChecker{
    my($c,$f) = @_;
    my $return;
    my $command="adb shell am startservice -a 'lab.mobile.ntu.TYPE_CHECKER' --es 'classname' '$c' --es 'fieldname' '$f' --es 'appname' '$APP_PATH_IN_ANDROID'";
    $command =~ s/\$/\\\$/g;
    $command =~ s/;/\\;/g;
    if(! -d "$DIR_PATH/sootOutput/$c") {
        $command .= " --ez 'private' 'false'";
    }
    system("adb logcat -c");
    system($command);
    #$return = `adb -d logcat -d -v raw -s typeCheckerResult:D | tail -1`;
    my $pid = open my $logcatHandler, "adb logcat -v raw -s typeCheckerResult:D |";
    while(<$logcatHandler>) {
        if($_ !~ m/^--------- beginning of.*/) {
            $return = $_;
            kill 'TERM', $pid;
            close $logcatHandler;
            break;
        }
    }
    $return =~ s/[\r\n]//g;
    return $return;
}

sub isRecursive {
    my ($class,$method,$paras,$newClass,$newMethod,$newParas) = @_;
    if($class eq $newClass) {
        if($method eq $newMethod && $paras eq $newParas) {
                return 1;
        }
    }
    return 0;
}

sub getMethodDot {
    my ($class, $method_name, $paras) = @_;
    my @passParas = split ",", $paras;
    my $is_found = 0;
    my $file = "ERROR";
    my $class_dir_path = "$DIR_PATH/sootOutput/$class";

    if( -d $class_dir_path) {
        # special invoke
        # e.g. sendMessage(android.os.message)
        if($method_name eq "sendMessage" && $paras eq "android.os.Message") {
            $method_name = "handleMessage";
        }
        elsif($method_name eq "sendMessageAtFrontOfQueue" && $paras eq "android.os.Message") {
            $method_name = "handleMessage";
        }
        elsif($method_name eq "sendMessageAtTime" && $paras eq "android.os.Message,long") {
            $method_name = "handleMessage";
            @passParas = split ",", "android.os.Message";
        }
        elsif($method_name eq "sendMessageDelayed" && $paras eq "android.os.Message,long") {
            $method_name = "handleMessage";
            @passParas = split ",", "android.os.Message";
        }
        elsif($method_name eq "start" and $paras eq "") {
            $method_name = "run";
        }
        open my $command, "ls -1 '$class_dir_path'| grep ' $method_name(' |";
        while(<$command>) {
            my $method = $_;
            chomp $method;
            if($method =~ m/[^ ]* [^ ]*\((.*)\)/) {
                my @realParas = split ",", $1;
                if($#realParas == $#passParas) {
                    $is_found = 1;
                    for my $i (0..$#realParas) {
                        # change array
                        my $varType;
                        my $parameter = $realParas[$i];
                        if($varType =~ m/^.*(\[\])+$/) {
                            my $dimension = 0;
                            my $array = $1;
                            while($array =~ m/\[\]/) {
                                $dimension++;
                                $array =~ s/^\[\](.*)$/$1/;
                            }
                            $varType = "";
                            for my $i (1..$dimension) {
                                $varType = "${varType}[";
                            }
                            if($parameter =~ m/(int|byte|short|long|float|double|boolean|char)(?:\[\])+/) {
                                $parameter = "$PRIMITIVE_TYPE{$varType}$1";
                            }
                            # a.b.c[]...
                            elsif($parameter =~ m/([a-zA-Z\.0-9]*)(?:\[\])+/) {
                                $parameter = "${varType}L$1;";
                            }
                        }
                        #my $compareResult = `java -jar ./tools/paraChecker.jar -e $JARPATH -1 '$parameter' -2 '$passParas[$i]'`;
                        my $command="adb shell am startservice -a 'lab.mobile.ntu.TYPE_CHECKER' --es 'comp1' '$parameter' --es 'comp2' '$passParas[$i]' --es 'appname' '$APP_PATH_IN_ANDROID'";
                        $command =~ s/\$/\\\$/g;
                        $command =~ s/;/\\;/g;
                        system("adb logcat -c");
                        system($command);
                        #$return = `adb -d logcat -d -v raw -s typeCheckerResult:D | tail -1`;
                        my $pid = open my $logcatHandler, "adb logcat -v raw -s typeCheckerResult:D |";
                        while(<$logcatHandler>) {
                            if($_ !~ m/^--------- beginning of.*/) {
                                $return = $_;
                                kill 'TERM', $pid;
                                close $logcatHandler;
                                break;
                            }
                        }
                        $compareResult =~ s/[\r\n]//g;

                        if($compareResult =~ m/false/) {
                            $is_found = 0;
                            break;
                        }
                        else { #true
                            $is_found = 1;
                        }
                    }
                    if($is_found) {
                        $file = `grep -lR '$method_name' '$class_dir_path/$method' | grep -v .swp`; 
                        chomp $file;
                        break;
                    }
                }
            }
        }
        close $command;
    }
    return $file;
}
sub Main{
    ######
    # use analyzeapk to retrieve the source file and java bytecode cfg dot file
    ######
    #getSourceFromAPK($APK_FILE_PATH);

    ######
    # parse AndroidManifest to find entry point for each component
    ######
    #$JARPATH = "$JARPATH:$DIR_PATH/classes_dex2jar.jar";
    #$ANDROID_PATH = "$ANDROID_PATH:$DIR_PATH/classes_dex2jar.jar";
    parseAndroidManifest("$DIR_PATH/AndroidManifest.xml");

    ######
    # parse each dot file of Method to CFG
    ######
    if($IS_PRELOAD) {
        $APP_PATH_IN_ANDROID = "/system/app/$APK_FILE_NAME";
    }
    else {
        $APP_PATH_IN_ANDROID = "/data/app/$PACKAGE-1.apk";
    }
    print $APP_PATH_IN_ANDROID,"\n";
    parseDotFileFromEntryPoint();

    #parseMethodDotFile('com.android.htcdialer.DialerService', 'onCreate', '', '/Users/atdog/work/evo/app/HtcDialer/sootOutput/com.android.htcdialer.DialerService/void onCreate()/jb.uce-ExceptionalUnitGraph-0.dot');
    #parseMethodDotFile('com.android.htcdialer.search.SearchablePhone', '<init>', 'long,int,java.lang.String,java.lang.String', '/Users/atdog/work/evo/app/HtcDialer/sootOutput/com.android.htcdialer.search.SearchablePhone/void <init>(long,int,java.lang.String,java.lang.String)/jb.uce-ExceptionalUnitGraph-0.dot');

    print Dumper(%ALL_METHOD_TYPE);
    print "-=-=-=-> All parsed files\n";
    for my $methodFile (keys %$ALL_METHOD_CFG) {
        print "$methodFile\n";
    }
    $ALL_METHOD_CFG->{'/Users/atdog/Desktop/ReverseAPK/com.mywoo.clog-59/sootOutput/com.mywoo.clog.Clog/void onCreate(android.os.Bundle)/jb.uce-ExceptionalUnitGraph-0.dot'}->dumpGraph;
    #$ALL_METHOD_CFG{'/Users/atdog/work/evo/app/HtcDialer/sootOutput/com.android.htcdialer.DialerService/void onCreate()/jb.uce-ExceptionalUnitGraph-0.dot'}->dumpGraph;
    #$ALL_METHOD_CFG{'/Users/atdog/work/evo/app/HtcDialer/sootOutput/com.android.htcdialer.search.SearchablePhone/void <init>(long,int,java.lang.String,java.lang.String)/jb.uce-ExceptionalUnitGraph-0.dot'}->dumpGraph;
}
