# new home directory for the XCP Engine

##### Change log
v0.6.0 2017.10 (target)
* Operational modules (18): alff, confound, cbf, coreg, fcon, gmd, jlf, net, norm, prestats, qcfc, qcstruc, regress, reho, roiquant, seed, struc, task
* Internal-only modules (2): dico, dti2xcp
* Modules added (1): fcon, cbf
* Modules renamed (3): benchmark => qcfc, strucQA => qcstruc, antsCT => struc
* Modules assimilated (1): locreg (into confound)
* A metadata system has been implemented for derivative neuroimages, parcellation schemes, and coordinate spaces.
* A standardised atlas and space organisation scheme with builder utilities supports rapid retrieval of metadata and easy warping between any coordinate spaces.
* Group-level processing is now supported by a delocaliser operation.
* Development for the XCP system is now easier. The generalised module header (and other cumbersome code) has been encapsulated in a new directory for core scripts, functions, and text blocks.
* The code has been extensively rewritten.

v0.5.1 2017.06
* Operational modules (20): asl, alff, benchmark, antsCT, confound, coreg, dico, dti2xcp, gmd, jlf, locreg, net, norm, prestats, regress, reho, roiquant, seed, strucQA, task
* Modules added (4): antsCT, gmd, jlf, strucQA
* Multimodal processing now stably encompasses high-resolution anatomical sequences. Cortical thickness and grey matter density analyses, as well as multi-atlas parcellation construction, are performed through ANTs.
* Automated template construction and atlas generation are now available through ANTs.

v0.5.0 2016.07
* Operational modules (16): asl, alff, benchmark, confound, coreg, dico, dti2xcp, locreg, net, norm, prestats, regress, reho, roiquant, seed, task
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
