.. include:: links.rst

.. _containers:

xcpEngine containers (Extra Info)
========================================

All atlases, software dependencies and scripts are included in the
xcpEngine Docker/Singularity image. **These instructions are not needed
if you are using ``xcpengine-docker`` or ``xcpengine-singularity``.
They are here in case you need to run them manually**

.. _singularity:


Using xcpEngine with Singularity_
---------------------------------

The easiest way to get started with xcpEngine on a HPC system is
to build a Singularity image from the xcpEngine released on
dockerhub.::

  $ singularity build xcpEngine.simg docker://pennbbl/xcpengine:latest

The only potentially tricky part about using a singularity image
is the need to *bind* directories from your host operating system
so they can be accessed from inside the container. Suppose there
is a ``/data`` directory that is shared across your cluster as
an nfs mount. All your data is stored in ``/data/study`` and
you have a cohort file and design file there. When running the
container, these will be seen as existing relative to the
bind point. This means they need to be specified like so.::

  $ singularity run \
      -B /data:/home/user/data \
      xcpEngine.simg \
      -c /home/user/data/study/my_cohort_rel_container.csv \
      -d /home/user/data/study/my_design.dsn \
      -o /home/user/data/study/output \
      -i $TMPDIR


The above command will work fine as long as your cohort file
points to the data *as it would be seen by the container*.
Specifically, the paths in ``my_cohort_rel_container.csv``
would all need to start with ``/home/user/data`` instead of ``/data``. If you would like to
keep the paths in your cohort relative to their locations in
the host OS, you would need to specify a *relative root* when
you run the container.::

  $ singularity run \
      -B /data:/home/user/data \
      xcpEngine.simg \
      -c /home/user/data/study/my_cohort_host_paths.csv \
      -d /home/user/data/study/my_design.dsn \
      -o /home/user/data/study/output \
      -r /home/user \
      -i $TMPDIR

Where the paths in ``my_cohort_host_paths.csv`` all start with
``/data``.

**NOTE:** Singularity_ typically mounts the host's ``/tmp`` as
``/tmp`` in the container. This is useful in the case where you
are running xcpEngine using a queueing system and want to write
intermediate files to the locally-mounted scratch space provided
in a ``$TMPDIR`` variable specific to the job. If you want to use
a different temporary directory, be sure that it's accessible from
inside the container and provide the container-bound path to it.

.. _Docker:

Using xcpEngine with Docker_
-----------------------------

Using Docker_ is almost identical to Singularity_, with the ``-B`` arguments
substituted for ``-v``. Here is an example:::

  $ docker --rm -it \
      -v /data:/data \
      -v /tmp:/tmp \
      pennbbl/xcpengine:latest \
      -c /data/study/my_cohort_host_paths.csv \
      -d /data/study/my_design.dsn \
      -o /data/study/output \
      -i $TMPDIR

Mounting directories in Docker is easier than with Singularity.


Parallelize across subjects
-----------------------------

By running xcpEngine from a container, you lose the ability to submit jobs
to the cluster directly from xcpEngine. We provide two examplary ways to split your cohort
file and submit either a ``qsub`` (SGE_) or an ``sbatch`` (SLURM_)  -job for each line. 
For illustrating reasons the two different scripts refer to different cohort-file-types: The SGE 
script uses a ``my_cohort_rel_container.csv`` cohortfile, which means we **don't need** to 
specify an ``-r`` flag. The SLURM script uses a ``my_cohort_rel_host.csv`` cohortfile, which 
means we **need** to specify an ``-r`` flag.
Note for both scripts: You will need to collate group-level outputs after batching subjects
with the ``${XCPEDIR}/utils/combineOutput`` script, provided in ``utils``.

.. _SGE:

Using SGE_ to parallelize across subjects
^^^^^^^^^^^^^^^^^^^^^^^

::

  #!/bin/bash
  FULL_COHORT=/data/study/my_cohort_rel_container.csv
  NJOBS=`wc -l < ${FULL_COHORT}`

  if [[ ${NJOBS} == 0 ]]; then
      exit 0
  fi

  cat << EOF > xcpParallel.sh
  #$ -V
  #$ -t 1-${NJOBS}

  # Adjust these so they work on your system
  SNGL=/share/apps/singularity/2.5.1/bin/singularity
  SIMG=/data/containers/xcpEngine.simg
  FULL_COHORT=${FULL_COHORT}

  # Create a temp cohort file with 1 line
  HEADER=\$(head -n 1 \$FULL_COHORT)
  LINE_NUM=\$( expr \$SGE_TASK_ID + 1 )
  LINE=\$(awk "NR==\$LINE_NUM" \$FULL_COHORT)
  TEMP_COHORT=\${FULL_COHORT}.\${SGE_TASK_ID}.csv
  echo \$HEADER > \$TEMP_COHORT
  echo \$LINE >> \$TEMP_COHORT

  \$SNGL run -B /data:/home/user/data \$SIMG \\
    -c /home/user\${TEMP_COHORT} \\
    -d /home/user/data/study/my_design.dsn \\
    -o /home/user/data/study/output \\
    -i \$TMPDIR

  EOF
  qsub xcpParallel.sh




.. _SLURM:

Using SLURM_ to parallelize across subjects
^^^^^^^^^^^^^^^^^^^^^^^

::

  #!/bin/bash
  # Adjust these so they work on your system
  FULL_COHORT=/data/study/my_cohort_rel_host.csv
  NJOBS=`wc -l < ${FULL_COHORT}`
  HEADER="$(head -n 1 $FULL_COHORT)"
  SIMG=/data/containers/xcpEngine.simg
  TMPDIR=/path/to/your/tmp-directory
  # memory, CPU and time depend on the designfile and your dataset. Adjust values correspondingly
  XCP_MEM=0G
  XCP_C=0
  XCP_TIME=0:0:0
 

  if [[ ${NJOBS} == 0 ]]; then
      exit 0
  fi

  cat << EOF > xcpParallel.sh
  #!/bin/bash -l
  #SBATCH --array 1-${NJOBS}
  #SBATCH --job-name xcp_engine
  #SBATCH --mem $XCP_MEM
  #SBATCH -c $XCP_C
  #SBATCH --time $XCP_TIME
  #SBATCH --workdir /path/to/your/working_directory
  #SBATCH --output /path/to/your/working_directory/logs/slurm-%A_%a.out


  LINE_NUM=\$( expr \$SLURM_ARRAY_TASK_ID + 1 )
  LINE=\$(awk "NR==\$LINE_NUM" $FULL_COHORT)
  TEMP_COHORT=${FULL_COHORT}.\${SLURM_ARRAY_TASK_ID}.csv
  echo $HEADER > \$TEMP_COHORT
  echo \$LINE >> \$TEMP_COHORT 

  singularity run -B /home/user/data:/data \\
    -B $TMPDIR:/tmp $SIMG \\
    -d /data/study/my_design.dsn \\
    -c \${TEMP_COHORT} \\
    -o /data/study/output \\
    -r /data \\
    -i /tmp

  EOF
  sbatch xcpParallel.sh



NOTE

Depending on your design-file some modules refer by default to ``qsub`` (SGE_) which doenst exist in your container once you use ``SBATCH`` (SLURM_). The ``jfl`` module used for example in the 

  [anat-antsct.dsn](https://github.com/PennBBL/xcpEngine/blob/master/designs/anat-antsct.dsn)
  
has this setting ``jlf_parallel[3]=1``. The ``1`` refers to ``qsub`` here. Using ``SBATCH`` you have to change that setting. ``jlf_parallel[3]=0`` will solve the problem but will increase processing time significantly (you dont process parallel anymore but serial then). 
by default (built into the container?) antsJointLabelFusion.sh is trying to use SGE qsub -c 1 Option and that fails because there is no qsub in the container 


 

Using the bundled software
----------------------------

All the neuroimaging software used by xcpEngine is available
inside the Singularity image. Suppose you couldn't get FSL 5.0.11
to run on your host OS. You could access it by::

  $ singularity shell -B /data:/home/user/data xcpEngine.simg
  Singularity: Invoking an interactive shell within container...

  Singularity xcpEngine.simg:~> flirt -version
  FLIRT version 6.0

  Singularity xcpEngine.simg:~> antsRegistration --version
  ANTs Version: 2.2.0.dev815-g0740f
  Compiled: Jun 27 2017 17:39:25


This can be useful on a system where you don't have current compilers or
root permissions.
