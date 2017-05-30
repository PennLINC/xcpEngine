#!/usr/bin/env bash


###################################################################
# Adaptation of Dr. Mark Elliott's force_RPI.sh script
###################################################################
input=$1
output=$2
orient=$($AFNI_PATH/@GetAfniOrient ${input})

case ${orient} in
    RAI)
        echo "Converting RAI to RPI orientation."
        fslreorient2std ${input} ${output}
        fslswapdim ${output} -x y z ${output}   # This intermediate result has INCONSISTENT data/header!!
        fslorient -swaporient ${output}              # now it is correct
        ;;
    RAS)
        echo "Converting RAS to RPI orientation."
        fslreorient2std ${input} ${output}
        ;;
    RSA)
        echo "Converting RSA to RPI orientation."
        fslreorient2std ${input} ${output}
        fslswapdim ${output} -x y z ${output}   # This intermediate result has INCONSISTENT data/header!!
        fslorient -swaporient ${output}              # now it is correct
       ;;
    RIA)
        echo "Converting RIA to RPI orientation."
        fslreorient2std ${input} ${output}
        ;;
    ASR)
        echo "Converting ASR to RPI orientation."
        fslreorient2std ${input} ${output}
        ;;
    AIL)
        echo "Converting AIL to RPI orientation."
        fslreorient2std ${input} ${output}
        ;;
    ASL)
        echo "Converting ASL to RPI orientation."
        fslreorient2std ${input} ${output}
        fslswapdim ${output} -x y z ${output}   # This intermediate result has INCONSISTENT data/header!!
        fslorient -swaporient ${output}              # now it is correct
        ;;
    LPI)
        echo "Converting LPI to RPI orientation."
        fslswapdim ${input} -x y z ${output}   			# This intermediate result has INCONSISTENT data/header!!
        fslorient -swaporient ${output}              # now it is correct
        ;;
    *)
        echo "Warning: $orient may be unsupported."
        echo "Applying 3dresample : unexpected results are possible."
        echo "Oblique data will not be handled appropriately."
        echo "Please verify that the output is correctly oriented."
        $AFNI_PATH/3dresample \
            -overwrite \
            -orient RPI \
            -inset ${input} \
            -prefix ${output}
        ;;
esac
