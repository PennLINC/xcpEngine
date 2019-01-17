
Use cases for the XCP pipeline
------------------------------

The XCP pipeline supports a number of use cases for anatomical and functional image processing.
This page is concerned with configuring analysis of a new dataset, as well as configuring common
modifications to existing datasets or existing analyses.

Run a new sample or dataset
~~~~~~~~~~~~~~~~~~~~~~~~~~~

To run a new sample or dataset through the pipeline, you will need to create a new cohort_
file. Each line of the cohort file should correspond to a different
subject in the sample, and each column should correspond to either a subject identifier or an input
path. Input paths can be defined either absolutely or relatively. The new cohort file
should be passed as an argument to the XCP front end ``-c`` option.

Add to an existing sample
~~~~~~~~~~~~~~~~~~~~~~~~~

Sometimes, you will want to add new subjects to an existing sample that has already been processed
using the pipeline system. This might be the case, for instance, if you acquire new data for an
ongoing study.

If you are adding new subjects to an existing sample, *do not* create a new cohort file for only
the new subjects. If you do this, the pipeline system will separately collate group-level data for
new and existing subjects. Instead, edit the existing cohort file for the pipeline, and append each
new subject to the file as a new line. The pipeline system automatically detects whether it has
produced expected output for each subject, so it will not repeat any processing that has already
completed. Check your design file to verify that any module-level ``rerun`` variables are set to a
value of ``0``. Otherwise, the pipeline will re-run for all subjects, even those that have already
completed.


Add new seeds for connectivity mapping
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

For analysis of functional connectivity, it will sometimes be desirable to compute the voxelwise
connectivity to a new seed region of interest. To do this, check your design file to ensure that
the ``pipeline`` includes a ``seed`` module, and that the ``seed`` module is executed after any
pre-processing or denoising steps.

Next, determine the coordinate library files used in the current
analysis. Paths to these will be stored in the ``seed_lib`` variable. If ``seed_lib`` references a
subject-level variable (with ``[sub]``), then the path to
the library will be stored in the cohort file and may be different for each subject. If ``seed_lib``
does not specify a containing directory, then the seed library is in ``${BRAINATLAS}/coor`` (by
default ``${XCPEDIR}/atlas/coor``).

After locating the coordinate library, edit it, adding new lines for each seed in accordance with
the spatial coordinate library specifications.
