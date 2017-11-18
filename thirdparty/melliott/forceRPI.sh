#!/usr/bin/env bash

###################################################################
# Adaptation of Dr. Mark Elliott's force_RPI.sh script
###################################################################

###################################################################
# Constants
###################################################################
source ${XCPEDIR}/core/constants
source ${XCPEDIR}/core/functions/library.sh

###################################################################
# Usage function
###################################################################
Usage(){
cat << endstream
___________________________________________________________________


Usage: forceRPI <input> <output>

forceRPI converts the input image to RPI orientation:
q/sform_xorient  Right-to-Left
q/sform_yorient  Posterior-to-Anterior
q/sform_zorient  Inferior-to-Superior

forceRPI is an adaptation of Dr. Mark Elliott's force_RPI.sh script

endstream
}

input=$1
output=$2
orient=$($AFNI_PATH/@GetAfniOrient ${input})

case ${orient} in
    RAI)
        subroutine         @u.1              Converting RAI to RPI orientation
        exec_fsl           fslreorient2std   ${input} ${output}
        exec_fsl           fslswapdim        ${output} \
                           -x y z            ${output}
                           # This intermediate result has INCONSISTENT data/header!!
        exec_fsl           fslorient         -swaporient ${output}
                           # now it is correct
        ;;
    RAS)
        subroutine         @u.2              Converting RAS to RPI orientation
        exec_fsl           fslreorient2std   ${input} ${output}
        ;;
    RSA)
        subroutine         @u.3              Converting RSA to RPI orientation
        exec_fsl           fslreorient2std   ${input} ${output}
        exec_fsl           fslswapdim        ${output} \
                           -x y z            ${output}
                           # This intermediate result has INCONSISTENT data/header!!
        exec_fsl           fslorient         -swaporient ${output}
                           # now it is correct
       ;;
    RIA)
        subroutine         @u.4              Converting RAI to RPI orientation
        exec_fsl           fslreorient2std   ${input} ${output}
        ;;
    ASR)
        subroutine         @u.5              Converting ASR to RPI orientation
        exec_fsl           fslreorient2std   ${input} ${output}
        ;;
    AIL)
        subroutine         @u.6              Converting AIL to RPI orientation
        exec_fsl           fslreorient2std   ${input} ${output}
        ;;
    ASL)
        subroutine         @u.7              Converting ASL to RPI orientation
        exec_fsl           fslreorient2std   ${input} ${output}
        exec_fsl           fslswapdim        ${output} \
                           -x y z            ${output}
                           # This intermediate result has INCONSISTENT data/header!!
        exec_fsl           fslorient         -swaporient ${output}
                           # now it is correct
        ;;
    LPI)
        subroutine         @u.8              Converting LPI to RPI orientation
        fslswapdim ${input} -x y z ${output}   			# This intermediate result has INCONSISTENT data/header!!
        fslorient -swaporient ${output}              # now it is correct
        ;;
    *)
        echo "Warning: $orient may be unsupported."
        echo "Applying 3dresample : unexpected results are possible."
        echo "Oblique data will not be handled appropriately."
        echo "Please verify that the output is correctly oriented."
        exec_afni    3dresample  \
            -overwrite           \
            -orient  RPI         \
            -inset   ${input}    \
            -prefix  ${output}
        ;;
esac
