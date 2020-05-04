
Quality Control  Dictionary 
===================================
 The quality control measures (prefix_quality.csv) 

Coregsitration of Functional and T1w:: 
         - coregCrossCorr - cross correlation  
         - CoregJaccard - Jaccard index 
         - CoregDice - Dice index 
         - CoregCoverage - Coverage index 

Registration of T1w to Template: 
         - regCrossCorr - cross correlation 
         - regJaccard - Jaccard index 
         - regDice - Dice index
         - regCoverage - Coverage index

Normalization of T1w/Functional to Template:
         - normCrossCorr - cross correlation 
         - normJaccard - Jaccard index 
         - normDice - Dice index
         - normCoverage - Coverage index 

QC for anatomical:
         - euler_number_rh,euler_number_lh -  Eurler number if freesurfer is included 
         - meanGMD - mean of Grey matter density
         - SignalToNoiseRatio - grey matter signal to noise ratio 
         - BackgroundKurtosis - background intensity Kurtosis
         - GreyMatterKurtosis - grey matter intensity Kurtosis
         - EntropyFocusCriterion - entropy focus criterion ( for ghost signals)
         - CorticalContrasts - coritical contrasts between white matter and grey matter signals
         - FGBGEnergyRatio - Foreground-to-background energy ratio
         - ContrastToNoiseRatio - contrast to noise ratio
         - WhiteMatterSkewness - WhiteMatter Skewness
         - BackgroundSkewness - background intensity Kurtosis



Motion/spikes summary.::
         - relMeansRMSMotion - mean value of RMS motion 
         - relMaxRMSMotion - maximum  vaue of RMS motion 
         - nSpikesFD - number of spikes per FD 
         - nspikesDV - number of spikes per DV 
         - pctSpikesDV - percentage of spikes per DV 
         - pctSpikesFD - percentage of spikes per FD 
         - meanDV - mead DVARS 

regression summary.:: 
         - motionDVCorrInit - correlation of  mean RMS and DVARS before regresion 
         - motionDVCorrFinal - correlation of  mean RMS and DVARS after  regresion 
         - nNuisanceParameters - total number of nuisance nNuisanceParameters
         - nVolCensored - total number of volume censored 
         - estimatedLostTemporalDOF - total degree of freedom lost 

CBF quality evaluation index.::
         - cbf_qei - cbf quality evalution index 
         - negativeVoxelsTS  - total number of negative voxels in CBF timeseries
         - negativeVoxels - total number of negative voxels in mean CBF 
         - cbfscore_qei - cbf score quality evaluation index
         - cbfscrub_qei - cbf scrub quality evaluation index
         - cbfbasil_qei - cbf basil quality evaluation index
         - cbfspatial_qei - cbf basil spatial  quality evaluation index
         - cbfpv_qei - cbf with partial volume correction quality evaluation index
         - nvoldel - number of volume deleted due to score
         - negativeVoxels_basil - number of negative voxels of mean cbf basil 
         - cbftsnr - cbf temporal signal to noise ratio
         - cbfscoretsnr - cbf score temporal signal to noise ratio 




   
