.. _combineoutput:

Combine output files 
======================

The ``xcpEgine`` provides a standalone script that help users to assemble results from each subject 
and combine to a single file for further analysis in any other platform such as Excel, MATLAB or SPSS.
 There is ``${XCPEDIR}/utils/combineOutput`` that combine inidcated file from all the subject in the output 
 directory. This can be  very important to assemble  especially quality control file (`/{prefix}_quality.csv`)
  and ``roiquant`` outputs::
  
  *  ${XCPEDIR}/utils/combineOutput \
  * -p $outputdir  \  # all subjects directory  after running xcpEngine
  * -f "*quality.csv" \  # the extention of the file users want to combine
  * -o XCP_QAVARS.csv  # the output file in csv 


The output file will consist of the header and  the all subjects correposnding value::

    id1,id2,relMeanRMSMotion,nSpikesRMS,nSpikesFD,nSpikesDV,relMaxRMSMotion
    ses-01,sub-01,0.07876904,1,0,0,0.2795057
    ses-01,sub-02,0.06421208,7,2,0,0.3267097
    ses-01,sub-06,0.02349,0,1,0,0.1087066
