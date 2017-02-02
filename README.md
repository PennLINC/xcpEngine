# new home directory for the XCP Engine

##### Adding modules

The primary output of any module must be an image whose name matches the primary subject identifier.

##### Change log
v0.5.0 2016.07
* Operational modules (16): asl, alff, confound, coreg, dico, locreg, net, norm, prestats, regress, reho, roiquant, seed, task
* Modules added (6): benchmark, dico, dti2xcp, locreg, roiquant, task
* Multimodal processing potential is extended to task-constrained activation analysis (and internally DTI). Task activation analysis is currently performed through FSL's FEAT, and the XCP Engine can now process any individual-level FEAT design file.
* ROI-wise quantification is centralised into the roiquant module.
* Group-level modules are enabled. The first of these is benchmark.g.mod, which computes motion-related quality metrics for the pipeline that has been run on a cohort.
* The XCP Engine has been restructured to support group-level modules. Interfacing with clusters outside of chead is still unlikely to work.

v0.4.0 and fixes (2016.03)
* RSPIPE deprecated. XCP Engine implemented to call modules and deploy pipelines as needed.
* Operational modules (10): prestats, coreg, confound, regress, net, seed, alff, reho, norm, asl
* Modules added (3): alff, reho, asl
* The XCP Engine now supports multimodal neuroimage processing. For now, this is limited to perfusion (arterial spin labelling) and is a BBL internal-only feature.
* Dependencies are checked at engine launch, and versions are tracked and logged.
* xcpConfig is now configured under the assumption that structural processing has been completed using an ANTs-like pipeline.
* Spatial and temporal filtering now have wrapper scripts that support a variety of approaches (FSL, AFNI, and utility R scripts).
* Help for module configuration options substantially expanded.

v0.3.0 and fixes (2015.10)
* Operational modules (7): prestats, coreg, confound, regress, sca, net, norm
* Modules added (4): confound, regress, sca, net
* Design file creation UI implemented.
* Design file localiser implemented.
* Master subject-level script (restpipe.sh) implemented.
* Confound matrix assembly implemented.
* Confound regression implemented.
* Confound regression module moves masks to the appropriate space.
* Matrix assembly and regression split into separate modules (anticipating future support for voxelwise regressors).
* Modules modified to conform to new paradigm.
* Power et al. (2014) iterative censoring pipeline is nearly implementable.
* Relative RMS displacement can now be included in the confound model.
* Mask erosion implemented.
* Temporal filters will now also filter the confound matrix prior to the regression step.

v0.2.0 and fixes (2015.10)
* Operational modules (3): prestats, coreg, norm
* Modules added (3): prestats, coreg, norm
* Design architecture implemented.
* Pipeline broken into modules.
* Prestats module implemented.
* Coregistration implemented.
* Normalisation implemented.
* Demeaning/detrending added to prestats.
* Extended filter options.

v0.1.0 and fixes (2015.09)
* Original RSPIPE deFEATed
* major debugging

##### devnotes

Modules implemented or partially implemented
* alff : computes amplitude of low-frequency fluctuations
* aroma : ICA-AROMA-like denoising
* confound : creates a matrix of global confound variables/nuisance regressors
* coreg : computes coregistration of structural and functional images
* locreg : generates localised confound variables/nuisance regressors
* net : extracts an a priori network from 4D timeseries and computes basic network metrics
* norm : moves all images from subject space into template space
* prestats : encompasses numerous preprocessing strategies
* regress : removes effects of global and local nuisance variables from data
* reho : computes regional homogeneity
* sca : seed-based correlation analysis

Planned/in preparation:
* astate : identifies activity states from network or 4D timeseries
* concat : performs all future analyses on subject-concatenated images/nets
* context : runs contextual connectivity pipeline on dynamic FC data
* cspace : computes trajectories through connectomic or activity space
* cstate : identifies connectivity states from dynamic FC
* infomax : computes a data-driven network using the Infomax ICA algorithm
* metacon : computes a metaconnectivity matrix from dynamic FC
* mtd : dynamic FC using the multiplication of temporal derivatives
* mtdregrec : alternative confound regression procedure with imputation
* qavars : obtains variables related to data and analysis quality
* sliwico : dynamic FC using sliding window correlations
* streg : spatiotemporal regression for simple back-reconstruction
* tica : temporal ICA on network timeseries to obtain TFMs
* time : obtains a time-by-time adjacency matrix and computes basic metrics

