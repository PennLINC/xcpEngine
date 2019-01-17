Pipeline design file
====================

A pipeline design file (``.dsn``) defines a processing pipeline that is interpreted by the image
processing system.

The design file contains:

 * A list of the modules_ that should be executed;
 * The set of parameters that configure each module, as well as their values

Preparing the design file
--------------------------

We strongly recommend you copy and use one of the
`standard design files <https://github.com/PennBBL/xcpEngine/tree/master/designs>`_ that come with
XCP Engine. These are regularly tested and usually work.

Examples
~~~~~~~~~

A `library of preconfigured pipelines <https://github.com/PennBBL/xcpEngine/tree/master/designs>`_
is available for each of the following experiments:

 * Anatomical (``anat``)
 * Functional connectivity (``fc``)
 * Functional connectivity benchmarking (``qcfc``)

Specifications (advanced)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Design variables fall into four main categories:

 * *Analysis variables* are input variables accessible at all stages of the pipeline
 * The *pipeline definition* specifies the modules (stages) of the pipeline that are to be run
 * *Module variables* are input variables accessible at only a single stage of the pipeline, and
   typically configure the behavior of that pipeline stage
 * *Output variables* are produced as the pipeline is run and are accessible at all stages of the
   pipeline
 * A fifth category of variable is not defined in the design file at all. *Subject variables* take
   different values for different subjects. See the cohort_ file
   documentation for more information about this type of variable.

Analysis variables
~~~~~~~~~~~~~~~~~~~~

Each design file includes a set of variables that are accessible at all stages of the pipeline.::

  analysis=accelerator_$(whoami)
  design=${XCPEDIR}/designs/fc-36P.dsn
  sequence=fc-rest
  standard=MNI%2x2x2_via_PNC%2x2x2


Pipeline definitions
~~~~~~~~~~~~~~~~~~~~~

The design file includes the ``pipeline`` variable, which defines the backbone of the pipeline: a
comma-separated sequence of the modules_ that together comprise the
processing stream.

The standard functional connectivity processing stream is:::

  pipeline=confound,regress,fcon,reho,alff,net,roiquant,seed,norm,qcfc

The standard benchmarking processing stream is an abbreviated version of the FC stream:::

  pipeline=confound,regress,fcon,qcfc

The complete anatomical processing stream is:::
  
  pipeline=struc,jlf,gmd,cortcon,sulc,roiquant,qcanat


Module configurations
~~~~~~~~~~~~~~~~~~~~~~~

In addition to the overall backbone of the processing stream, the design file includes
specifications for each of its constituent modules. As an illustrative example, the specifications
of the ``coreg`` module in a standard functional connectivity stream are provided here:::

  ###################################################################
  # 2 COREG
  ###################################################################

  coreg_reference[2]=mean
  coreg_cfunc[2]=bbr
  coreg_seg[2]=${segmentation[sub]}
  coreg_wm[2]=3
  coreg_denoise[2]=1
  coreg_refwt[2]=NULL
  coreg_inwt[2]=NULL
  coreg_qacut[2]=0.8,0.9,0.7,0.8
  coreg_decide[2]=1
  coreg_mask[2]=0
  coreg_rerun[2]=0
  coreg_cleanup[2]=1

Each row defines a different parameter for the ``coreg`` module (e.g., ``coreg_cfunc`` -- the cost
function for registration) and assigns it a value (e.g., ``bbr`` -- boundary-based registration).
When the module is executed, it processes its inputs according to the specifications in the
pipeline design file.

Output variables
~~~~~~~~~~~~~~~~~

Output variables aren't defined in the design file that's provided as an argument at runtime.
Instead, they are defined as the pipeline is run and written to a copy of the design file. Output
variables are typically accessible by all pipeline stages after they are produced. An illustrative
example is provided, again for the ``coreg`` module:::

  # ··· outputs from IMAGE COREGISTRATION MODULE[2] ··· #
  struct2seq_img[9001]=accelerator/9001/coreg/9001_struct2seq.nii.gz
  struct2seq_mat[9001]=accelerator/9001/coreg/9001_struct2seq.mat
  seq2struct[9001]=accelerator/9001/coreg/9001_seq2struct.txt
  seq2struct_img[9001]=accelerator/9001/coreg/9001_seq2struct.nii.gz
  struct2seq[9001]=accelerator/9001/coreg/9001_struct2seq.txt
  seq2struct_mat[9001]=accelerator/9001/coreg/9001_seq2struct.mat
  fit[9001]=0.3
  sourceReference[9001]=accelerator/9001/prestats/9001_meanIntensityBrain.nii.gz
  targetReference[9001]=9001_antsct/ExtractedBrain0N4.nii.gz
  altreg2[9001]=mutualinfo
  altreg1[9001]=corratio

Each row corresponds to an output defined by the ``coreg`` module that can be used by all downstream
modules. For example, ``struct2seq`` defines an affine transformation from the subject's
high-resolution anatomical space to the subject's functional space. This transformation can later
be used to align white matter and CSF masks to the functional image, enabling tissue-based confound
regression.
