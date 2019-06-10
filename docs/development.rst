.. _development:

Developing/Debugging XCP
===========================

The easiest way to debug or develop XCP is to download the source code from GitHub
and mount it in an xcpEngine Docker or Singularity container. If you are on a laptop
you will want to use Docker, whereas if you are on a HPC cluster you will want to
use Singularity.

Downloading the source code
------------------------------

To download the master branch from GitHub, you can do the following::

  git clone https://github.com/PennBBL/xcpEngine.git

Now you can edit or add to the code however you'd like.

 ``xcpEngine`` depends on number of dependencies including `ANTS <https://github.com/ANTsX/ANTs>`_, `FSL <https://fsl.fmrib.ox.ac.uk/fsl/fslwiki>`_,`c3d <http://www.itksnap.org/pmwiki/pmwiki.php?n=Convert3D.Documentation>`_, `AFNI <https://afni.nimh.nih.gov/>`_, R and Python packages. 
 The main R packages require are RNifti, optparse, pracma, signal, and python packages require are numpy,nibabel,niworkflows, nilearn and matplotlib. 
 The enviroment should be set as follow in the bash profile::
         XCPEDIR=/path/to/xcpEngine/sourcecode
         FSLDIR=/path/to/fsldir
         AFNI_PATH=/path/to/afni
         C3D_PATH=/path/to/c3d
         ANTSPATH=/path/to/ANTs
  
After setting the enviroment, it is require to reset the xcpEngine to link to those dependencies::
    source ${XCPEDIR}/xcpReset 
  
You can use docker or singularity image. 
  
Patching a local copy of xcpEngine into a container
-------------------------------------------------------

Assuming you're in the same directory as when you ran ``git clone``, you can
now mount your local copy of xcpEngine into the container.::

  docker run -it \
      -v `pwd`/xcpEngine:/xcpEngine \
      --entrypoint bash \
      pennbbl/xcpengine:latest

This will drop you into a shell inside the container, which contains all of  ``xcpEngine``'s
dependencies and your local copy of the ``xcpEngine`` code. You can run the pipeline directly from
inside this shell, but you will need  to be certain that it has access to your data. Suppose your
data is located  on your laptop in ``/data/fmriprep``, your cohort file is at
``/data/fmriprep/cohort.csv``, the working directory should be ``/data/work`` and you want the
output to go in ``/data/xcpOutput``. You have to start Docker so that you can read and write  from
these locations. Do this by mounting your data directory in the container::

  docker run -it \
    -v /data/fmriprep:/inputs \
    -v /data/xcpOutput:/output \
    -v /data/work:/work \
    -v `pwd`/xcpEngine:/xcpEngine \
    --entrypoint bash \
    pennbbl/xcpengine:latest

Then you can run ``xcpEngine`` in the container::

  xcpEngine \
    -d /xcpEngine/designs/fc-36p.dsn \
    -c /inputs/cohort.csv \
    -i /work \
    -o /output

and the pipeline should run using the code in your local copy of ``xcpEngine``.


Using singularity
--------------------

Mounting directories in a container is not as simple using Singularity. Suppose you
created a Singularity image using something like:::

  singularity build xcpEngine-latest.simg docker://pennbbl/xcpengine:latest

Assuming your data is in all the same locations as the laptop Docker example above,
you can patch the local copy of the ``xcpEngine`` source code by::

  singularity shell -B `pwd`/xcpEngine:/xcpEngine xcpEngine-latest.simg

Mounting data directories is somewhat trickier because the mount point must
exist inside the container. One convenient location for binding data is ``/mnt``.::

  singularity shell \
    -B /data:/mnt \
    -B `pwd`/xcpEngine:/xcpEngine \
    xcpEngine-latest.simg

and you can make the call to ``xcpengine`` from inside the shell::

  xcpEngine\
    -d /xcpEngine/designs/fc-36p.dsn \
    -c /mnt/fmriprep/cohort.csv \
    -i /mnt/work \
    -o /mnt/xcpOutput

This way you can make quick changes to the xcp source code and see how they would
impact your pipeline without needing to create a new Singularity image.
