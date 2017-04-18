#!/usr/bin/perl -w

use strict;

my $usage = qq{
  
  $0 <imageToLabel> <outputRoot> <brainExtracted> <keepWarps> <subset> 

  imageToLabel - Target head or brain image

  outputRoot - prepended to output

  brainExtracted - if 1, target is brain extracted and we will use brain extracted atlases. 

  keepWarps - if 1, keep all warps and deformed images. If 0, keep only the final MALF labeling

  This script requires ANTSPATH to be set. To use a version of ANTs customized to run Malf on the 
  cluster (somewhat faster than the default), set
  
  ANTSPATH=/data/joy/BBL/applications/ANTsJLF_201603/bin/

  This is a "minimal" ANTs so you can easily copy and modify as needed. 


  Available subsets:


  YoungAdult22 - Age range of 18-34

  Sex         Age     
  F:14   Min.   :18.00
  M: 8   1st Qu.:20.00
         Median :22.00
         Mean   :23.45
         3rd Qu.:25.75
         Max.   :34.00


  Older18 - Age range of 23-90

  Sex         Age     
  F:12   Min.   :23.00
  M: 6   1st Qu.:26.50
         Median :32.00
         Mean   :43.67
         3rd Qu.:59.25
         Max.   :90.00


  SexBalanced20 - All male subjects (ages 20-68) plus 10 of the female subjects.

  Sex         Age       
  F:10   Min.   :20.00  
  M:10   1st Qu.:22.00  
         Median :25.00  
         Mean   :32.45  
         3rd Qu.:31.00  
         Max.   :75.00

  sexBalanced20\$Sex: F
   Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
  20.00   21.50   25.50   32.30   29.75   75.00 
  ------------------------------------------------------------ 
  sexBalanced20\$Sex: M
   Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
  20.00   22.00   24.00   32.60   32.75   68.00 
   

  Subset24 - A subset for general use, fairly wide age range, slightly more balanced on sex.

  Sex         Age
  F:14   Min.   :20.0
  M:10   1st Qu.:22.0
         Median :25.5
         Mean   :32.5
         3rd Qu.:35.0
         Max.   :75.0


  Younger24 - Maintains the same 2:1 female:male ratio of the original, but biased towards younger subjects

  Sex         Age
  F:16   Min.   :18.00
  M: 8   1st Qu.:20.00
         Median :22.50
         Mean   :24.96
         3rd Qu.:28.25
         Max.   :45.00

 All - Everyone

  Sex         Age       
  F:20   Min.   :18.00  
  M:10   1st Qu.:20.25  
         Median :25.00  
         Mean   :34.33  
         3rd Qu.:37.00  
         Max.   :90.00  
                       

};


if ($#ARGV < 0) {
  print $usage;
  exit 1;  
}

my $antsPath = $ENV{"ANTSPATH"} || "";

my ($target, $outputRoot, $brainExtracted, $keepWarps, $subset) = @ARGV;

if (! -f "${antsPath}antsJointLabelFusion.sh") {
    print " Can't find script - is ANTSPATH defined? \n";
    exit 1;
}

my $brainDir="/data/joy/BBL/labelSets/OASIS30/Heads";

if ($brainExtracted > 0) {
    $brainDir="/data/joy/BBL/labelSets/OASIS30/Brains";
}

my $segDir="/data/joy/BBL/labelSets/OASIS30/Segmentations";

my @subjects = ();


$subset = lc($subset);


if ($subset eq "youngadult22") {
    @subjects = qw/1000 1001 1002 1006 1007 1008 1009 1010 1011 1012 1013 1014 1015 1036 1017 1003 1004 1005 1018 1019 1101 1104/;
}
elsif ($subset eq "older18") {
    @subjects = qw/1001 1006 1010 1013 1014 1003 1004 1005 1019 1104 1107 1110 1113 1116 1119 1122 1125 1128/;
}
elsif ($subset eq "sexbalanced20") {
    @subjects = qw/1000 1001 1002 1003 1004 1005 1006 1007 1009 1010 1013 1015 1017 1019 1036 1104 1113 1116 1119 1122/;
}
elsif ($subset eq "subset24") {
    @subjects = qw/1001 1002 1006 1008 1009 1010 1012 1013 1014 1015 1036 1017 1003 1004 1005 1018 1019 1104 1107 1110 1113 1116 1119 1122/;
}
elsif ($subset eq "younger24") {
    @subjects = qw/1000 1001 1002 1006 1007 1008 1009 1010 1011 1012 1013 1014 1015 1036 1017 1003 1004 1005 1018 1019 1101 1104 1107 1110/;
}
elsif ($subset eq "all") {
    @subjects = qw/1000 1001 1002 1006 1007 1008 1009 1010 1011 1012 1013 1014 1015 1036 1017 1003 1004 1005 1018 1019 1101 1104 1107 1110 1113 1116 1119 1122 1125 1128/;
}
else {
    die " Unrecognized subset - see usage for available options\n";
}


my $atlasString = "";


foreach my $subject (@subjects) {
    $atlasString .= "-g ${brainDir}/${subject}_3.nii.gz -l ${segDir}/${subject}_3_seg.nii.gz ";
}


system("${antsPath}antsJointLabelFusion.sh -d 3 -q 0 -f 0 -j 2 -k $keepWarps -t $target -o $outputRoot -c 0 $atlasString");
