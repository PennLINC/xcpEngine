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
