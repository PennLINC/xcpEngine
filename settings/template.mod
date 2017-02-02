#!/usr/bin/env bash

###################################################################
#  ✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡ #
###################################################################

###################################################################
# Constants
###################################################################





###################################################################
###################################################################
# BEGIN GENERAL MODULE HEADER
###################################################################
###################################################################
# Read in:
#  * path to localised design file
#  * overall context in pipeline
#  * whether to explicitly trace all commands
# Trace status is, by default, set to 0 (no trace)
###################################################################
trace=0
while getopts "d:c:t:" OPTION
   do
   case $OPTION in
   d)
      design_local=${OPTARG}
      ;;
   c)
      cxt=${OPTARG}
      ! [[ ${cxt} =~ $POSINT ]] && ${XCPEDIR}/xcpModusage mod && exit
      ;;
   t)
      trace=${OPTARG}
      if [[ ${trace} != "0" ]] && [[ ${trace} != "1" ]]
         then
         ${XCPEDIR}/xcpModusage mod
         exit
      fi
      ;;
   *)
      echo "Option not recognised: ${OPTARG}"
      ${XCPEDIR}/xcpModusage mod
      exit
   esac
done
shift $((OPTIND-1))
###################################################################
# Ensure that the compulsory design_local variable has been defined
###################################################################
[[ -z ${design_local} ]] && ${XCPEDIR}/xcpModusage mod && exit
###################################################################
# Set trace status, if applicable
# If trace is set to 1, then all commands called by the pipeline
# will be echoed back in the log file.
###################################################################
[[ ${trace} == "1" ]] && set -x
###################################################################
# Initialise the module.
###################################################################
echo ""; echo ""; echo ""
echo "###################################################################"
echo "#   ✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡ #"
echo "#                                                                 #"
echo "#  ☭                EXECUTING [modname] MODULE                 ☭  #"
echo "#                                                                 #"
echo "#   ✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡✡  #"
echo "###################################################################"
echo ""
###################################################################
# Source the design file.
###################################################################
source ${design_local}
###################################################################
# Create a directory for intermediate outputs.
###################################################################
outdir=${out}/${cxt}_[modname]
[[ ! -e ${outdir} ]] && mkdir -p ${outdir}
echo "Output directory is $outdir"
###################################################################
# Define paths to all potential outputs.
###################################################################

###################################################################
# * Initialise a pointer to the image.
# * Ensure that the pointer references an image, and not something
#   else such as a design file.
# * On the basis of this, define the image extension to be used for
#   this module (for operations, such as AFNI, that require an
#   extension).
# * Localise the image using a symlink, if applicable.
# * Define the base output path for intermediate files.
###################################################################
img=${out}/${prefix}
imgpath=$(ls ${img}.*)
for i in ${imgpath}
   do
   [[ $(imtest ${i}) == 1 ]] && imgpath=${i} && break
done
ext=$(echo ${imgpath}|sed s@${img}@@g)
outbase=${outdir}/${prefix}~TEMP~
#img=${outdir}/${prefix}~TEMP~
#if [[ $(imtest ${img}) != "1" ]] \
#   || [ "${prestats_rerun[${cxt}]}" == "Y" ]
#   then
#   rm -f ${img}
#   ln -s ${out}/${prefix}${ext} ${img}${ext}
#fi
#imgpath=$(ls ${img}.*)
###################################################################
# Prime the localised design file so that any outputs from this
# module appear beneath the correct header.
###################################################################
echo "" >> $design_local
echo "# *** outputs from [modname][${cxt}] *** #" \
   >> $design_local
echo "" >> $design_local
###################################################################
# Verify that the module should be run:
#  * Test whether the final output already exists.
#  * Determine whether the user requested the module to be re-run.
# If it is determined that the module should not be run, then any
#  outputs must be written to the local design file.
###################################################################
if [[ $(imtest ${final[${cxt}]}) == "1" ]] \
   && [[ "${[modname]_rerun[${cxt}]}" == "N" ]]
   then
   echo "[modname] has already run to completion."
   echo "Writing outputs..."
   ################################################################
   # Since it has been determined that the module does not need to
   # be executed, exit the module.
   ################################################################
   echo "Module complete"
   exit 0
fi
###################################################################
###################################################################
# END GENERAL MODULE HEADER
###################################################################
###################################################################
