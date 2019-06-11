.. _cohortfile:

Pipeline cohort file
====================

A pipeline cohort file defines the experimental sample -- the set of subjects that the pipeline should process.

 The cohort file is formatted as ``.csv`` and contains:

 * A column corresponding to each category of input
 * A header naming each category of input
 * A row corresponding to each subject

Examples
----------

Cohort files can usually be prepared using a simple command-line call. The contents of a cohort
file will vary depending upon:

 * The imaging modality
 * The experimental objective
 * Available inputs

Examples for a few common processing cases are provided below.

Subject identifiers
~~~~~~~~~~~~~~~~~~~~

In general, all cohort files should contain a unique set of identifier variables for each unique
subject. The pipeline system uses identifier variables to generate a unique output path for each
input. To cast a cohort field as an identifier, give it the name ``id<i>`` in the cohort header,
where ``<i>`` is a nonnegative integer. In the illustrative example, ``id0`` might correspond to
the subject's identifier, ``id1`` to the time point (as in a longitudinal study). So
``sub-01,ses-01`` would denote the first session for subject 001. These can also be used to denote multiple runs in the same session, as ``sub-01,ses-01,run-01``. Note that these do not get
automatically added to paths when xcp is looking for files.::

  id0,id1
  sub-01,ses-01
  sub-01,ses-02
  sub-02,ses-01
  sub-03,ses-01
  sub-03,ses-02
  sub-04,ses-02
  sub-04,ses-01

Guidelines and specifications
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

 * There are no upper or lower limits to the number of identifier variables that can be provided,
   but in general it is recommended that they be ordered hierarchically. That is, subject should
   precede time point and not the other way around.
 * Identifiers can comprise any combination of alphanumeric characters and underscores. Any other
   characters should be excised or mapped to the set of valid characters.

Path definitions
~~~~~~~~~~~~~~~~~~

Paths defined in a cohort file can be specified either as absolute paths or as relative paths. For
portability, relative path definitions are recommended where possible. If relative paths are
provided, then the call to ``xcpEngine`` should include the ``-r`` flag, which accepts as its
argument the path relative to which cohort paths were defined. For instance, the provided example
would yield a value of
``/data/example/derivatives/fmriprep/sub-01/ses-01/anat/sub-01_ses-01_desc-preproc_T1w.nii.gz`` for
``img``.::

  -r /data/example/derivatives/fmriprep

with::

  id0,id1,img
  sub-01,ses-01,sub-01/ses-01/anat/sub-01_ses-01_desc-preproc_T1w.nii.gz


This is particularly useful for using directories mounted in Singularity.

Anatomical processing: Already done by ``FMRIPREP``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

If you aren't interested in getting structural measurements (volume, etc) or using a custom
template, you can skip this step entirely and go to :ref:`functionalprocessing`. However, if you
want to use a custom template you'll need to make sure to have ``T1w`` in your ``--output-spaces``
list when you run ``FMRIPREP``. For anatomical processing, the cohort file is quite minimal: only
the subject's anatomical image is required in addition to the set of identifiers. The subject's
anatomical image should receive the header ``img``. **Anatomical processing must occur after
``FMRIPREP`` and before functional processing**.::

  id0,id1,img
  sub-01,ses-01,sub-01/ses-01/anat/sub-01_ses-01_desc-preproc_T1w.nii.gz
  sub-01,ses-02,sub-01/ses-02/anat/sub-01_ses-02_desc-preproc_T1w.nii.gz
  sub-02,ses-01,sub-02/ses-01/anat/sub-02_ses-01_desc-preproc_T1w.nii.gz
  sub-03,ses-01,sub-03/ses-01/anat/sub-03_ses-01_desc-preproc_T1w.nii.gz

Again, the structural pipeline *is not necessary to run the functional pipeline* in most cases.

.. _functionalprocessing:

Functional processing
~~~~~~~~~~~~~~~~~~~~~~~

*Directly using preprocessed BOLD data from ``FMRIPREP``*

To operate directly on the output from ``FMRIPREP`` the cohort file is very simple. The subject
identifier variables are specified, followed by the path to the output image from ``FMRIPREP``.
These can be in any volumetric output space (``T1w``, ``template``). Here is an example::

  id0,id1,img
  sub-01,ses-01,sub-01/ses-01/func/sub-01_ses-01_task-rest_space-T1w_desc-preproc_bold.nii.gz
  sub-01,ses-02,sub-01/ses-02/func/sub-01_ses-02_task-rest_space-T1w_desc-preproc_bold.nii.gz
  sub-02,ses-01,sub-01/ses-01/func/sub-02_ses-01_task-rest_space-T1w_desc-preproc_bold.nii.gz
  sub-03,ses-01,sub-03/ses-01/func/sub-03_ses-01_task-rest_space-T1w_desc-preproc_bold.nii.gz

*After running the xcp structural pipeline*

There are two ways that the cohort file for the functional processing stream can be specified. In
the case where the T1w-space output from ``FMRIPREP`` (requires that ``--output-spaces`` included
``T1w`` in your ``FMRIPREP`` call) was processed with the XCP anatomical stream, you need to
specify the directory where that output exists. An example cohort file for this use case would look
like::

  id0,id1,img,antsct
  sub-01,ses-01,sub-01/ses-01/func/sub-01_ses-01_task-rest_space-T1w_desc-preproc_bold.nii.gz,xcp_output/sub-01/ses-01/struc
  sub-01,ses-02,sub-01/ses-02/func/sub-01_ses-02_task-rest_space-T1w_desc-preproc_bold.nii.gz,xcp_output/sub-01/ses-02/struc
  sub-02,ses-01,sub-01/ses-01/func/sub-02_ses-01_task-rest_space-T1w_desc-preproc_bold.nii.gz,xcp_output/sub-02/ses-01/struc
  sub-03,ses-01,sub-03/ses-01/func/sub-03_ses-01_task-rest_space-T1w_desc-preproc_bold.nii.gz,xcp_output/sub-03/ses-01/struc

The first line of this cohort file would process the image
``${DATA_ROOT}/sub-01/ses-01/func/sub-01_ses-01_task-rest_space-T1w_desc-preproc_bold.nii.gz``.

ASL processing
~~~~~~~~~~~~~~~~~~~~~~~

The ASL processing requires ASL image, M0 scan for caibration (if available). In the absence of M0 scan, the average  
control volumes is used as reference or M0 scan (scale=1). The ASL processing requires anatomical processing directory of either 
`FMRIPREP` or the :ref:`struc`: module  of `xcpEngine`. Here is an example of cohort file with anatomical directory of `FMRIPREP`.::

  id0,img,m0,anatdir
  sub-1,/path/to/asl.nii.gz,/path/to/m0.nii.gz,fmriprep/sub-xx/anat


With the :ref:`struc`: directory of the `xcpEngine` output, the cohort file is shown below.::

  id0,img,m0,antsct
  sub-1,/path/to/asl.nii.gz,/path/to/m0.nii.gz,/path/to/struc


Subject variables
------------------

Each of the columns in the cohort file becomes a *subject variable* at runtime. Subject variables
can be used in the :ref:`design` to assign a parameter
subject-specific values. For instance, to use a custom task file for a subject the ``task_design`` parameter in the :ref:`struc`
can be assigned the ``fsf`` subject variable. To
indicate that the assignment is a subject variable, include the array index ``[sub]`` in the
variable's name as shown.::

  task_design[1]=${fsf[sub]}
