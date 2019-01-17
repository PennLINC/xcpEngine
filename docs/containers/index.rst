.. _containers:

xcpEngine containers
========================================

All atlases, software dependencies and scripts are included in the
xcpEngine Docker/Singularity image.

.. _singularity:

  test test
 
 ``test``

Using xcpEngine with singularity
---------------------------------

The easiest way to get started with xcpEngine on a HPC system is
to build a Singularity image from the xcpEngine released on
dockerhub.

  $ singularity build xcpEngine.simg docker://pennbbl/xcpengine:latest

The only potentially tricky part about using a singularity image
is the need to *bind* directories from your host operating system
so they can be accessed from inside the container. Suppose there
is a ``/data`` directory that is shared across your cluster as
an nfs mount. All your data is stored in ``/data/study`` and
you have a cohort file and design file there. When running the
container, these will be seen as existing relative to the
bind point. This means they need to be specified like so.

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

**NOTE:** Singularity typically mounts the host's ``/tmp`` as
``/tmp`` in the container. This is useful in the case where you
are running xcpEngine using a queueing system and want to write
intermediate files to the locally-mounted scratch space provided
in a ``$TMPDIR`` variable specific to the job. If you want to use
a different temporary directory, be sure that it's accessible from
inside the container and provide the container-bound path to it.

Using SGE to parallelize across subjects
----------------------------------------

By running xcpEngine from a container, you lose the ability to submit jobs
to the cluster directly from xcpEngine. Here is a way to split your cohort
file and submit a qsub job for each line. *Note that we are using
`my_cohort_rel_container.csv`, which means we don't need to specify
an `-r` flag. If your cohort file uses paths relative to the host's
file system you will need to specify `-r`*::

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


You will need to run group analysis with your whole cohort file after the
jobs have all finished.

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
