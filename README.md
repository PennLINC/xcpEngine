# The BBL image processing umbrella

[![CircleCI](https://circleci.com/gh/PennBBL/xcpEngine/tree/master.svg?style=svg)](https://circleci.com/gh/PennBBL/xcpEngine/tree/master)
[![Documentation Status](https://readthedocs.org/projects/ansicolortags/badge/?version=latest)](http://xcpengine.readthedocs.io/?badge=latest)
[![PyPI download total](https://img.shields.io/pypi/v/xcpengine-container.svg)](https://pypi.org/project/xcpengine-container/)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.3840960.svg)](https://doi.org/10.5281/zenodo.3840960)

## Deprecation Notice

xcpEngine is no longer supported.
xcpEngine is essentially completely configurable -- including configurations that don't make sense and would not pass peer review.
Instead of maintaining this complex and potentially dangerous configurability,
the most widely-used fMRI postprocessing workflows from xcpEngine are available (including for surface data) and rigorously tested/supported in XCP-D.

For ASL preprocessing, we recommend switching to ASLPrep.

## Overview

xcpEngine provides a configurable, modular, agnostic, and multimodal platform for neuroimage
processing and quality assessment. It implements a number of high-performance denoising approaches
and computes regional and voxelwise values of interest for each modality. The system provides tools
for calculating functional connectivity after preprocessing has been run in `FMRIPREP`, as well as
a standard toolkit for benchmarking pipeline performance. All pipelines from [our 2017 benchmarking
paper](https://www.ncbi.nlm.nih.gov/pubmed/28302591) are implementable, as are the pipelines
evaluated in [the recent work of Parkes and
colleagues](https://www.biorxiv.org/content/early/2017/11/05/156380).

## Documentation

Detailed documentation is accessible at the [pipeline's documentation
hub](http://xcpengine.readthedocs.io)

If you experience any difficulties, we suggest that you search or post to the
issues forum of the pipeline's GitHub repository.
