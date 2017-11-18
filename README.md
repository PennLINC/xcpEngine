# The BBL image processing umbrella

##### Overview

xcpEngine v0.6.0 (ACCELERATOR) is the most recent iteration of the BBL's neuroimage processing system. This system provides a configurable, modular, agnostic, and multimodal platform for neuroimage processing and quality assessment. It implements a number of high-performance denoising approaches and computes regional and voxelwise values of interest for each modality. The system provides a general-purpose image processing interface, as well as a standard toolkit for benchmarking pipeline performance. All pipelines from [our 2017 benchmarking paper](https://www.ncbi.nlm.nih.gov/pubmed/28302591) are implementable, as are the pipelines evaluated in [the recent work of Parkes and colleagues](https://www.biorxiv.org/content/early/2017/11/05/156380). As of v0.6.0, functional and anatomical modalities are supported, with perfusion and diffusion under development.

##### Installation

###### Dependencies

Ensure that your bash terminal is minimally v4.0 (`bash --version`). Ensure that all dependencies are installed. These should include: AFNI, ANTs, FSL, C3D, R, Rscript. Install the following R packages if necessary: optparse, pracma, RNifti, signal. For enhanced group-level reporting, optionally install the following R packages: reshape2, ggplot2, svglite.

###### Software

Copy all files from the GitHub repository to the directory where you want the software installed. All code is interpreted, so no compilation should be necessary at this stage. Define the following environment variables (Run `export <variable_name>=<variable_value>` in a bash terminal, or in the appropriate bash configuration file):

* XCPEDIR : the directory where the pipeline is installed. It should contain the pipeline front-end (`xcpEngine`), the image processing library (`core`), utility scripts (`utils`), and pipeline modules (`modules`).
* FSLDIR : the directory where FSL is installed. This should be the top-level FSL install directory, contining both source (`src`) and compiled (`bin`) code.
* ANTSPATH : the directory where ANTs is installed. This directory should directly contain ANTs scripts and binaries, such as `antsRegistration` and `antsApplyTransforms`.
* AFNI_PATH : the directory where AFNI is installed. This directory should directly contain AFNI scripts and binaries, such as `3dcalc` and `3dTproject`.
* C3D_PATH : the directory where C3D is installed. This directory should contain C3D scripts, such as the `c3d_affine_tool`.

After all of the above variables are defined, run the script `xcpReset` in the pipeline directory. If the script runs without any warnings, then you have successfully installed the pipeline. To verify the installation, you may wish to check `${XCPEDIR}/core/global`, which defines the pipeline environment.

If you receive a warning notifying you that any environment variables are undefined, ensure that those variables are defined and re-run `xcpReset`. If the warning persists, the variables are probably defined locally but not in the environment. In this case, either run `export <variable1_name> <variable2_name> . . .` followed by `xcpReset`, or run `source xcpReset` to complete installation.

If you experience any difficulties, we suggest that you search or post to the issues forum of the pipeline's GitHub repository.

##### Change log
v0.6.0 2017.11
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
