.. _struc:

``struc``
===========

``struc`` is an omnibus module for processing of anatomical MR images. ``struc`` can run the ANTs
Cortical Thickness (ANTsCT) pipeline in its entirety or can execute any combination of N4 bias
field correction, FSL- or ANTs-based brain extraction, Atropos brain segmentation, and ANTs
diffeomorphic registration.

Outputs
^^^^^^^^

 * ``corticalThickness``
 * ``mask``
 * ``segmentation``

Omnibus modules
^^^^^^^^^^^^^^^^^

Omnibus modules defy modular logic to an extent: they do not comprise a single, well-encapsulated
processing step. Instead, they include a number of *routines*, each of which corresponds to a
common processing step. These routines can be combined and re-ordered within the parent module.
Much like the ``pipeline`` variable specifies the inclusion and order of modules in the pipeline,
the module-level ``process`` variable specifies the inclusion and order of routines within an
omnibus module. An example is provided here for the ``struc`` omnibus module:::

  pipeline=struc,gmd,cortcon,sulc,jlf,roiquant,qcanat
  struc_process[1]=BFC-ABE-REG-SEG

In the example here, the ``pipeline`` variable is defined as a standard anatomical stream that
begins with ``struc``.

 * ``struc_process``: the name of the variable specifying the inclusion and order of routines
 * ``[1]``: the scope of the ``struc_process`` variable, that is, the first module of the
   ``pipeline``
 * ``BFC-ABE-REG-SEG``: a series of three-letter codes for module routines to be called within
   ``struc``, offset by hyphens (``-``) and ordered in the same order that they are to be executed

Available routine codes
^^^^^^^^^^^^^^^^^^^^^^^^^^

``ACT``
~~~~~~~~

*ANTs Cortical Thickness*. This routine executes the entire ANTs cortical thickness pipeline. In
general, no other routines need to be included if ``ACT`` is used.

``BFC``
~~~~~~~~~

*N4 bias field correction*. This routine removes spatial intensity bias from the anatomical image
using the N4 approach from ANTs.

``ABE``
~~~~~~~~

*ANTs brain extraction*. This routine uses ``antsBrainExtraction`` to identify brain voxels and
remove any non-brain voxels from the anatomical image.

``FBE``
~~~~~~~~~

*FSL brain extraction*. This routine uses FSL's ``BET`` to identify brain voxels and remove any
non-brain voxels from the anatomical image.

``SEG``
~~~~~~~~

*Anatomical segmentation*. This routine uses ANTs's ``Atropos`` with or without tissue class priors
to segment the anatomical image into tissue classes.

``REG``
~~~~~~~~~

*Registration*. This routine uses ``antsRegistration`` to diffeomorphically register the anatomical
image to a template.

Module configuration
^^^^^^^^^^^^^^^^^^^^^

``struc_denoise_anat``
~~~~~~~~~~~~~~~~~~~~~~~~~

*Denoise anatomical image.*

Routine: ``SEG``, ``ACT``.

During the segmentation procedure, ANTs can use the ``DenoiseImage`` program to remove noise from
an anatomical image using a spatially adaptive filter with a Gaussian or a Rician noise model.::

  # do not denoise
  struc_denoise_anat[cxt]=0

  # apply denoising
  struc_denoise_anat[cxt]=1

``struc_denoise_anat`` must be either ``0`` or ``1``.

``struc_seg_priors``
~~~~~~~~~~~~~~~~~~~~~~
*Prior-driven segmentation.*

Routine: ``SEG``.

Segmentation implemented in the ``SEG`` routine can be either prior-driven or priorless. In
prior-driven segmentation, the segmentation of the brain into tissue classes is guided by prior
maps that assign each voxel a probability of belonging to each tissue class, often resulting in a
more anatomically correct parcellation. Tissue-class priors are provided for each parcellation.
(Disabling this option is not currently available in the ANTsCT routine (``ACT``); the ANTsCT
pipeline will always use prior-driven segmentation.)::

  # enable prior-driven segmentation
  struc_seg_priors[cxt]=1

  # do not use priors for segmentation
  struc_seg_priors[cxt]=0

``struc_seg_priors`` must be either ``0`` or ``1``.

``struc_prior_weight``
~~~~~~~~~~~~~~~~~~~~~~~~

Prior weight for segmentation.

Routine: ``SEG``.

Segmentation implemented in the ``SEG`` routine can be either prior-driven or priorless. If
prior-driven segmentation (``struc_seg_priors``) is enabled, the prior weight determines the extent
to which the tissue class priors constrain the parcellation. A higher prior weight will result in a
segmentation that more closely conforms to the priors.::

  # set prior weight to 0.25
  struc_prior_weight[cxt]=0.25

``struc_seg_priors`` must be a value in the interval ``[0,1]`` (inclusive).

``struc_posterior_formulation``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Posterior formulation.

Routine: ``SEG``, ``ACT``.

The formulation for posterior probability maps produced by the segmentation routine. The default
setting (``'Socrates[1]'``) is usually acceptable. Consult the ANTs documentation for more
information.::

  # Use Socrates formulation with mixture model proportions
  struc_posterior_formulation[cxt]='Socrates[1]'

  # Use Plato formulation with mixture model proportions
  struc_posterior_formulation[cxt]='Plato[1]'

``struc_posterior_formulation`` can be, for instance, ``'Socrates[1]'`` (default), ``'Plato[1]'``,
``'Aristotle[1]'`` or ``'Sigmoid[1]'``. Consult the ANTs documentation for all available options.

``struc_floating_point``
~~~~~~~~~~~~~~~~~~~~~~~~~~~

*Precision for registrations.*

Routine: ``REG``, ``ABE``, ``ACT``.

The precision to be used during registrations. ``1`` indicates that single-precision registration
should be used, while ``0`` indicates that double-precision registration should be used (default,
more precision).::

  # Use double precision
  struc_floating_point[cxt]=0

  # Use single precision
  struc_floating_point[cxt]=1

``struc_floating_point`` must be either ``0`` or ``1``.

``struc_random_seed``
~~~~~~~~~~~~~~~~~~~~~~

Use random seed.

Routine: ``SEG``, ``ABE``, ``ACT``.

The pseudorandom number generator can generate values that appear more random if it is seeded with
a value based on the system clock. To use random seeding to initialise the RNG, set
``struc_random_seed`` to a value of ``1``.::

  # Use random seed
  struc_random_seed[cxt]=1

  # Disable random seed
  struc_random_seed[cxt]=0

``struc_random_seed`` must be either ``0`` or ``1``.

``struc_bspline``
~~~~~~~~~~~~~~~~~~~~~

Deformable B-spline SyN registration.

Routine: ``REG``, ``ACT``.

Regularisation during ANTs registration can be performed using a b-spline approach. Please
reference the [original article](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3870320/#B36) for
further information.::

  # Use deformable B-spline registration
  struc_bspline[cxt]=1

  # Use deformable registration
  struc_bspline[cxt]=0

``struc_bspline`` must be either ``0`` or ``1``.

``struc_fit``
~~~~~~~~~~~~~~~

Brain extraction threshold.

Routine: ``FBE``

The fractional intensity threshold determines how much of an image will be retained after non-brain
voxels are zeroed during the FSL-based ``FBE`` routine. It is not used for ANTs-based brain
extraction. A more liberal mask can be obtained using a lower fractional intensity threshold. The
fractional intensity threshold should be a positive number greater than 0 and less than 1.::

  # Fractional intensity threshold of 0.3
  struc_fit[cxt]=0.3

Freesufer run.

Routine: ``FSF``

The freesufer can be run with addition of `FSF` to the procsess as ::

  struc_process[cxt]=FSF-ACT

If the freesufer has be ran before, the directory of freesufer can be copied by including::

  struc_freesurferdir[cxt]=/path/to/freesufer/directory
this can also be included in the cohort file.
the cifti files for cortical thickness are generated.  

``struc_quick``
~~~~~~~~~~~~~~~~~~

Quick SyN registration.

Routine: ``REG``, ``ACT``.

SyN registration can be performed using an alternative, faster approach. Although the results are
not of the same quality as standard SyN registration, this approach nonetheless typically results
in a set of transforms that is adequate for many purposes.::

  # Use quick SyN registration
  struc_quick[cxt]=1

  # Use default SyN registration
  struc_quick[cxt]=0

``struc_quick`` must be either ``0`` or ``1``.

``struc_rerun``
~~~~~~~~~~~~~~~~~

Ordinarily, each module will detect whether a particular analysis has run to completion before
beginning it. If re-running is disabled, then the module will immediately skip to the next stage of
analysis. Otherwise, any completed analyses will be repeated.If you change the run parameters, you
should rerun any modules downstream of the change.::

  # Skip processing steps if the pipeline detects the expected output
  struc_rerun[cxt]=0

  # Repeat all processing steps
  struc_rerun[cxt]=1

``struc_cleanup``
~~~~~~~~~~~~~~~~~~~~

Modules often produce numerous intermediate temporary files and images during the course of an
analysis. In many cases, these temporary files are undesirable and unnecessarily consume disk
space. If cleanup is enabled, any files stamped as temporary will be deleted when a module
successfully runs to completion. If a module fails to detect the output that it expects, then
temporary files will be retained to facilitate error diagnosis.::

  # Remove temporary files
  struc_cleanup[cxt]=1

  # Retain temporary files
  struc_cleanup[cxt]=0

``struc_process``
~~~~~~~~~~~~~~~~~~~~

Specifies the order for execution of anatomical processing routines. Exercise discretion when using
this option; unless you have a compelling reason for doing otherwise, it is recommended you use one
of the default orders provided in the pre-configured design files.

The processing order should be a string of concatenated three-character routine codes separated by
hyphens (``-``). Each substring encodes a particular preprocessing routine; this feature should
primarily be used to selectively run only parts of the preprocessing routine.::

  # Default processing routine for ANTs Cortical Thickness
  struc_process[cxt]=ACT

  # Minimal anatomical processing routine (for use with functional MRI)
  struc_process[cxt]=BFC-ABE-REG-SEG

  # Minimal anatomical processing routine using FSL instead of ANTs for brain extraction
  struc_process[cxt]=BFC-FBE-REG-SEG

Permitted codes include:

 * ``ACT``: complete ANTs cortical thickness pipeline
 * ``BFC``: N4 bias field correction
 * ``ABE``: ANTs brain extraction
 * ``FBE``: FSL brain extraction
 * ``SEG``: Atropos image segmentation
 * ``REG``: registration to a template
 * ``FSF``: Freesufer  or copy freesufer outputs from fmriprep if available
