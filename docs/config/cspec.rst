# The cluster specifications file

**NOTE: this section is not applicable if you are using singularity or docker**

If you are running the pipeline on a cluster with a SGE-like job management system, then it is possible to configure each module of the pipeline to be submitted to the cluster with a different set of parameters. This can be useful, for instance, when the memory demand of modules varies considerably and the user accordingly wishes to allocate different amounts of memory for each module.

Module-specific cluster parameters are dictated by a _cluster specifications file_ that can be passed to the [pipeline front end](%%BASEURL/config/xcpEngine) as an argument to the `-m` option. If the `-m` option receives a file as an argument, then it will perform as though it had received the argument `c` (i.e., it will submit all jobs to the cluster for execution in parallel). However, it will also use the values defined in the file when submitting jobs.

The cluster specifications file contains a single array variable, `cspec` (for cluster specification). Each entry in `cspec` contains cluster specifications for the module that shares its index in the processing stream (`pipeline` in the [design file](%%BASEURL/config/design)). For instance, `cspec[3]` specifies cluster parameters for the third module in the pipeline. (`cspec[0]` is reserved for the `xcpLocaliser`).

In the example shown, 16 gigabytes of virtual memory are allocated to the  `regress` module while limiting all other modules to the user's default memory allotment. (Note the only `cspec` should be defined in the cluster specifications file. `pipeline` is shown below only to provide context.)
```bash
pipeline=confound,regress,net,qcfc
cspec=(
   [1]='-l h_vmem=16.5G,s_vmem=16.0G'
   [4]='-l h_vmem=16.5G,s_vmem=16.0G'
)
```
