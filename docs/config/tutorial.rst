Pipeline tutorial
-----------------

0. Before you begin
~~~~~~~~~~~~~~~~~~~

To get started, first [create a singularity image of xcpEngine::

  $ singularity build /data/applications/xcpEngine.simg docker://pennbbl/xcpengine:latest

Next, download
`an example output from FMRIPREP <https://figshare.com/articles/xcpEngine_tutorial_data/7359086>`_

Suppose the downloaded data is extracted to ``${DATA_ROOT}/fmriprep``, where ``${DATA_ROOT}``` is
an existing directory on your system.

1. Running the anatomical pipeline
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

You need to create a cohort file and a design file to show XCP where your data is and tell it what
to do with it. Since there is only a single subject with a single session, write the following
content to `${DATA_ROOT}/anat_cohort.csv`::

  id0,img
  sub-1,fmriprep/sub-1/anat/sub-1_T1w_preproc.nii.gz

Then download the antsCT design
`file <https://raw.githubusercontent.com/PennBBL/xcpEngine/master/designs/anat-antsct.dsn>`_ into
``${DATA_ROOT}/anat-antsct.dsn``

Now you're ready to run the anatomical pipeline! Create an empty directory in your home directory
(we'll use ``${HOME}`` because it is directly mounted by Singularity by default, so do ``mkdir
${HOME}/data``). This will be the bind point for your system's ``${DATA_ROOT}`` directory and will
let singularity access your files. Binding directories is very important and worth understanding
well. See the singularity
`documentation <https://www.sylabs.io/guides/3.0/user-guide/bind_paths_and_mounts.html>`_
for details.::

  singularity run -B ${DATA_ROOT}:${HOME}/data  \
     /data/applications/xcpEngine.simg
     -d ${HOME}/data/anat-antsct.dsn \
     -c ${HOME}/data/anat_cohort.csv  \
     -o ${HOME}/data/xcp_output \
     -t 1 \
     -r ${HOME}/data

This will take up to 2 days, but when it's done you will have the full output of
antsCorticalThickness for this subject! It also provides all the spatial normalization
info to map atlases to your BOLD data. See the :ref:`anatomical` stream to
learn about the available templates and atlases.

2. Running a functional connectivity pipeline
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Processing fMRI data for functional connectivity analysis can be done using another design file.
Now save one of the nicely-performing pipeline
`design files <https://raw.githubusercontent.com/PennBBL/xcpEngine/master/designs/fc-36p.dsn>`_
as something
like ``${DATA_ROOT}/fc-36p.dsn``. This will take the preprocessed BOLD output from ``FMRIPREP`` and
prepare it for functional connectivity analysis. Create a new cohort csv that tells XCP where the
output from the ``struc`` module is located and where the output from ``FMRIPREP`` is located. In
``${DATA_ROOT}/func_cohort.csv`` write::

  id0,antsct,img
  sub-1,xcp_output/sub-1/struc,fmriprep/sub-1/func/sub-1_task-rest_space-T1w_desc-preproc_bold.nii.gz


This specifies that we will process the ``task-rest`` scan from this subject. Other runs from the
same session would need to be added as additional lines in the cohort file. Run xcpEngine with this
new cohort file::

  singularity run -B ${DATA_ROOT}:${HOME}/data  \
     /data/applications/xcpEngine.simg
     -d ${HOME}/data/fc-36p.dsn \
     -c ${HOME}/data/func_cohort.csv  \
     -o ${HOME}/data/xcp_output \
     -t 1 \
     -r ${HOME}/data


3. Running a ASL processing pipeline
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Processing ASL data for computation of CBF  can be done using
`design files <https://github.com/PennBBL/xcpEngine/blob/master/designs/cbf.dsn>`_
This will take the ASL,M0 (if available) and anatomical directory. 
ASL processing steps is the same like  both anatomical anf functional connectivity pipelines, 
the only different is cohort file and design files. 


4. Arguments
~~~~~~~~~~~~

While the pipeline is running, let's break down the call that we made to the XCP Engine. We passed
a total of 5 arguments to the pipeline.

  * A :ref:`design` file, ``-d ${HOME}/data/example/anat-antsct.dsn``
  * A :ref:`cohort` file, ``-c ${HOME}/data/example/anat_cohort.csv``
  * An output path, ``${HOME}/data/example/xcp_output``
  * A verbosity level, ``-t 1``
  * A reference/relative directory, ``-r ${HOME}/data``

Let's discuss each of these, and how a user might go about selecting or preparing them.

Design file
^^^^^^^^^^^

The design file parametrizes the image processing stream. The XCP system supports multimodal image
processing, including *inter alia* functional connectivity and volumetric anatomy. How does the
system know which of these available processing streams it should execute? It parses the parameters
provided by the user in the design file. In our example, we parametrized the stream using the
design file ``anat-antsct.dsn``.


Near the top of the file, you will find a variable called ``pipeline`` that should look something
like: ``confound,regress,fcon,reho,alff,net,roiquant,seed,norm,qcfc``. The ``pipeline`` variable tells
the XCP system which modules it should run, and what order they should be run in.

Underneath the ``pipeline`` variable, you will find code blocks corresponding to each of the
modules defined in ``pipeline``. If you're curious as to what effects any of the variables have,
just look up the variables in the documentation for the relevant pipeline :ref:`modules`.


Cohort file and reference directory
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The design file instructs the pipeline as to how inputs should be processed, but the :ref:`cohort`
file (also called a subject list) actually informs the pipeline where to
find the inputs. Let's look at the cohort file that we used for this analysis.::

  id0,antsct,img
  sub-1,xcp_output/sub-1/struc,fmriprep/sub-1/func/sub-1_task-rest_space-T1w_desc-preproc_bold.nii.gz

The cohort file is formatted as a ``.csv`` with 3 variables and 1 observation (subject). The first
line of the cohort file is a header that defines each of the variables. Subject identifiers are
placed in columns starting with ``id`` and ending with a non-negative integer. For instance, the
first identifier (``id0``) of the first subject is ``sub-1``. There could be a second identifier
(``id1``) such as ``ses-01`` if needed.

The inputs for each subject are defined in the remaining columns, here ``antsct`` and ``fmriprep``.
``antsct`` defines the path to the output files of the subject's processed ANTs Cortical Thickness
pipeline (which has already been run as part of the :ref:`anatomical` stream in step 1).
``fmriprep`` defines the prefix to the main image that this pipeline will analyze. Since this is
the cohort for a functional connectivity stream, the main image will be a functional image (in this
case, resting state).

If we look at our call to ``xcpEngine``, we can see that we passed it the argument ``-r ${DATADIR}``.
This argument instructs ``xcpEngine`` to search within ``${DATADIR}`` for cohort paths. This is very
useful when using Singularity of Docker, as you can specify the relative bind path as your root
while keeping the paths in your cohort file relative to your system's root.

Now, let's suppose that we have already processed this subject through the pipeline system, and we
acquire data for a new, 2nd subject. Let's say this new subject has identifier `sub-2`. To process
this new subject, DO NOT CREATE A NEW COHORT FILE. Instead, edit your existing cohort file and add
the new subject as a new line at the end of the file. For our example subject, the corresponding
line in the cohort file might be something like
``sub-2,xcp_output/sub-2/struc,fmriprep/sub-2/func/sub-2_task-rest_space-T1w_desc-preproc_bold.nii.gz``.
Why edit the existing cohort file instead of creating a new one?

  * The pipeline will automatically detect that it has already run for the other subject, so it
    will not waste computational resources on them.
  * The pipeline will then collate group-level data across all 8 subjects. If you were to create a
    new cohort file with just the new subject, group-level data would be pulled from only that
    subject. Not much of a group, then.

5. Output files
~~~~~~~~~~~~~~~

To see what the remaining arguments to ``xcpEngine`` do, we will need to look at the pipeline's
output. By now, the pipeline that you launched earlier will hopefully have executed to completion.
Let's take a look at the output directory that you defined using the ``-o`` option,
``${output_root}``. If you list the contents of ``${output_root}``, you will find 7 subject-level
output directories (corresponding to the values of the ``id0`` variable in the cohort file) and one
group-level output directory (called ``group``). (You can change the group-level output path using
the additional command-line argument ``-a out_group=<where you want the group-level output>``.)

Begin by looking at the subject-level output. Navigate to the first subject's output directory,
``${output_root}/sub-1``. In this directory, you will find:

  * A subject-specific copy of the design file that you used to run the pipeline, evaluated and
    modified to correspond to this particular subject (``sub-1``). (In the XCP system, the process
    of mapping the template design file to each subject is called *localisation*, and the script
    that handles this is called the *localiser*.)
  * An atlas directory (``sub-1_atlas``). Inside the atlas directory, each parcellation that has
    been analyzed will exist as a NIfTI file, registered to the subject's T1w native space.

  * A subdirectory corresponding to each pipeline module, as defined in the ``pipeline`` variable
    in the design file. For the most part, these directories store
    images and files that the pipeline uses to verify successful processing.

    * Take a look inside the ``fcon`` subdirectory. Inside, there will
      be a separate subdirectory for each of the atlases that the pipeline has processed. For
      instance, in the ``power264`` subdirectory (corresponding to the
      `264-node Power atlas <https://www.ncbi.nlm.nih.gov/pubmed/22099467>`_), there will be files
      suffixed ``ts.1D`` and ``network.txt``.
    * ``ts.1D`` contains 264 columns corresponding to each node of the atlas; each column contains
      a region's functional time series.
    * ``network.txt`` contains the functional connectivity matrix or connectome for the Power
      atlas, formatted as a vector to remove redundant edges.

  * A log directory (``sub-1_logs``). Inside the log directory, open the file whose name ends
    with ``_LOG``. This is where all of the pipeline's image processing commands are logged.
    The verbosity of this log can be modified using the argument to the ``-t`` option). It is
    recommended that you use a verbosity level of either 1 or 2. For most cases, 1 will be
    sufficient, but 2 can sometimes provide additional, lower-level diagnostic information.
  * A quality file (``sub-1_quality.csv``). The contents of the quality file will be discussed in
    detail later, along with group-level outputs.
  * A spatial metadata file (``sub-1_spaces.json``). The pipeline uses this to determine how to
    move images between different coordinate spaces.
  * The final output of processing (``sub-1.nii.gz``). This is the primary functional image, after
    all image processing steps (except for smoothing) have been applied to it. If you have smoothing in your design file,
    smoothed outputs are saved separately as files like ``sub-1_img_sm${k}.nii.gz`` inside the ``norm`` and ``regress``
    folders, with ``${k}`` the smoothing kernel size. However, this
    preprocessed file usually isn't as useful for analysis as are its derivatives, which brings us to ...
  * An index of derivative images (``sub-1_derivatives.json``).

    * Let's look at the content of the derivatives file now. Run the command shown, and find the
      entry for ``reho``. This JSON object corresponds to the voxelwise map of this subject's
      regional homogeneity (*ReHo*).
    * The map can be found in the path next to the ``Map`` attribute. (You can open this in
      ``fslview`` if you would like.)
    * The ``Provenance`` attributes tell us that the map was produced as part of the 6th pipeline
      module, ``reho``.
    * The ``Space`` attribute tells us that the map is in 2mm isotropic MNI space.
    * The ``Statistic`` attribute instructs the pipeline's ``roiquant`` module that it should
      compute the mean value within each parcel of each atlas when converting the voxelwise
      derivative into an ROI-wise derivative.
    * The ``Type`` attribute is used by the pipeline when it makes decisions regarding
      interpolations and other processing steps.
    * There will actually be a separate index for each coordinate space that has been processed.
      Note that there's also a ``sub-1_derivatives-sub-1_fc.json``, which has the same metadata
      for derivatives in the subject's native functional space.

Next, let's examine the group-level output. Navigate to ``${output_root}/group``. In this directory,
you will find:

* The dependency metadata from earlier (``dependencies/*pipelineDescription.json``). (A new
  time-stamped metadata file is generated for each run of the pipeline.)
* An error logging directory (``error``). This should hopefully be empty!
* A log directory (``log``), analogous to the log directory from the subject level.
* Module-level directories, in this case for the ``roiquant`` and ``qcfc`` modules.

  * Let's look at the group-level ``roiquant`` output. Like the subject-level ``net`` output,
    there will be a separate subdirectory for each atlas that has been processed.
  * Inside the atlas-level subdirectory, there will be files corresponding to any derivatives that
    had a non-``null`` value for their ``Statistic`` attribute. For instance, the ReHo that we
    looked at earlier (``Statistic: mean``) has been quantified regionally and collated across all
    subjects in the file ending with the suffix ``RegionalMeanReho.csv``. You may wish to examine
    one of these files; they are ready to be loaded into R or any other environment capable of
    parsing ``.csv`` s.

* A sample quality file for the modality (``fc_quality.csv``).

  * The ``qcfc`` module's subdirectory will contain reports analogous to those from our .These
    aren't really useful for a sample of only 1 subject, so we won't look at them here.

* Collated subject-level quality indices (``n1_quality.csv``, not to be confused with the
  sample-level quality file). If you examine this file, you will find the quality indices that the
  functional connectivity stream tracks. This file can be used to establish exclusion criteria
  when building a final sample, for instance on the basis of subject movement or registration
  quality.
* An audit file (``n1_audit.csv``). This file indicates whether each pipeline module has
  successfully run for each subject. ``1`` indicates successful completion, while ``0`` indicates
  a nonstandard exit condition.

6. Anatomy of the pipeline system
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Now, let's pull this information together to consider how the pipeline system operates.

1. The front end, ``xcpEngine``, parses the provided :ref:`design` and :ref:`cohort` files.
2. The *localiser* uses the information in the cohort file to generate a subject-specific version
   of the design file for each subject. (The localiser shifts processing from the sample level to
   the subject level; this is called the *localisation* or *map* step.)
3. ``xcpEngine`` parses the ``pipeline`` variable in the design file to determine what
   :ref:`modules`
   (or processing routines) it should run. Different imaging and data modalities (e.g., anatomical,
   functional connectivity, task activation) will make use of a different series of modules.
4. ``xcpEngine`` submits a copy of each module for each subject in the cohort using that subject's
   local design file. Modules run in series, with all subjects running each module in parallel. As
   it runs, each module writes derivatives and metadata to its output directory.
5. To collate subject-level data or perform group-level analysis, the pipeline uses the
   *delocaliser*. Shift of processing from the subject level to the sample level is called
   *delocalisation* or a *reduce* step.

7. Getting help
~~~~~~~~~~~~~~~

To get help, the correct channel to use is
` Github <https://github.com/PennBBL/xcpEngine/issues>`_.
Open a new issue and describe your problem. If the problem is highly dataset-specific, you can
contact the development team by email, but Github is almost always the preferred channel for
communicating about pipeline functionality. You can also use the issue system to request new
pipeline features or suggest changes.

8. Common Errors
~~~~~~~~~~~~~~~
A non-exhaustive list of some common errors, and fixes to try.

* ``ImportError: bad magic number in 'site'`` : Try running ``unset PYTHONPATH`` immediately prior to running the pipeline.

* ``Cannot allocate vector of size xx Mb`` : Try increasing the amount of memory available for running the pipeline.
