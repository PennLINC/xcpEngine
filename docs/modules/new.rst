# Creating a new module

Writing a new subject-level module for the BBL pipeline

### Headers

The first code in any new pipeline module should be a pair of module headers: first a *specific* module header and afterward a *general* module header.

The specific module header contains, at minimum, the module name and a short description of its functionality.

```bash
###################################################################
# SPECIFIC MODULE HEADER
# <one-line description of module functionality>
###################################################################
mod_name_short=<short name of module, e.g. confound or regress>
mod_name='<full name of module>'
mod_head=${XCPEDIR}/core/CONSOLE_MODULE_G
```

If you want to load any additional function libraries beyond the XCP core library into the environment, the specific module header is also the place to do that.

```bash
source ${XCPEDIR}/core/functions/library_func.sh
```

The general module header is the same for all modules. It currently comprises three steps:

 * Load global constants into the environment, and initialise any global associative arrays (`source ${XCPEDIR}/core/constants`)
 * Load the XCP core library of functions into the environment (`source ${XCPEDIR}/core/functions/library.sh`)
 * Parse arguments passed to the module (`source ${XCPEDIR}/core/parseArgsMod`)

```bash
###################################################################
# GENERAL MODULE HEADER
###################################################################
source ${XCPEDIR}/core/constants
source ${XCPEDIR}/core/functions/library.sh
source ${XCPEDIR}/core/parseArgsMod
```

(This should be condensed into a single call at some point in the future.)

### Actions on completion

Immediately under the header, there should be a function that includes instructions for what the module should do when it successfully runs to completion. Minimal steps for module completion are:

 * Update the pipeline audit file to reflect successful completion of the current module (`source ${XCPEDIR}/core/auditComplete`)
 * Write any new quality assessment indices into the subject's quality tracker file (`source ${XCPEDIR}/core/updateQuality`)
 * Run the generic code for successful end-of-module (`source ${XCPEDIR}/core/moduleEnd`)

```bash
###################################################################
# MODULE COMPLETION
###################################################################
completion() {
   source ${XCPEDIR}/core/auditComplete
   source ${XCPEDIR}/core/updateQuality
   source ${XCPEDIR}/core/moduleEnd
}
```

In the body of the `completion` function, these minimal steps can be supplemented by any additional code that should be executed when the module successfully completes. In almost every case, those additional steps should be executed before the general `completion` code. The example shown here is for the `net` module.

```bash
completion() {
   write_atlas

   source ${XCPEDIR}/core/auditComplete
   source ${XCPEDIR}/core/updateQuality
   source ${XCPEDIR}/core/moduleEnd
}
```

Modules will often have more than one successful exit point. At each successful exit point, the `completion` function should be called.

### Output definition

The output definition comprises two principal blocks: (i) declaration of any possible outputs of the module and (ii) a brief description of each output.

What should be declared as an output? If you want to reference anything created by a module in another downstream module, then declare it as an output. By contrast, intermediate files should generally not be declared as outputs. Only persistent files that are usable either for analysis of data at the group level or for generation of further derivatives should be saved. All outputs that are declared in a module will be accessible from any downstream modules.

Internally, the pipeline has 4 classes of potential outputs: `derivative`, `output`, `configure`, and `qc`. `derivative` and `output` are used for files on the file system, while `configure` and `qc` are used for values that do not exist in separate files. Files (`derivative` and `output`) are declared using the syntax `<output type> <output name> <output path>`, and should generally be written to a path of the form `${prefix}_<output name>`. (`${prefix}` will be assigned by the pipeline at runtime.)

#### `derivative`

`derivative` is used to declare outputs formatted as NIfTI images. `derivative` creates a new JSON-formatted `derivative` object with a set of attributes. These attributes can be accessed using `derivative_get` and modified using `derivative_set`. If you know beforehand the value of an attribute, you should assign it using `derivative_set`. When declaring a new `derivative`, you should *not* declare its path with *any* file extension; the appropriate extension will be assigned by the pipeline.

```bash
derivative        <derivative name>    <path to output in module's directory>

derivative_set    <derivative name>       \
                  <derivative attribute>  \
                  <new value for attribute>
```

For example, a new brain mask derivative can be instantiated as shown.

```bash
derivative        mask     ${prefix}_mask
derivative_set    mask     Type     Mask
```

#### `output`

`output` is used to declare outputs that exist as non-NIfTI files on the file system (or NIfTI files that shouldn't be accessible from the index of `derivatives`). Outputs *must* be assigned paths with the most appropriate file extension (e.g., `.nii.gz`, `.1D`, `.csv`, `.txt`, etc.).

```bash
output            <output name>        <path to output in module's directory>
```

For example, a connectivity matrix might be instantiated as shown.

```bash
output            connectivity   ${prefix}_connectivity.txt
```

#### `configure`

`configure` is used to declare outputs that exist as values rather than files. For instance, signals for downstream module behavior can be declared using `configure`. Outputs declared using `configure` must be initialized with some default value. (This can be the value of an existing variable or any upstream output.) The value of the `configure` is then changed during the course of the module.

```bash
configure         <output name>        <initial value>
```

#### `qc`

`qc` is reserved for new quality indices computed in the course of a module. The value assigned to a `qc` variable will be written in the subject's quality tracker file at end-of-module. A `qc` declaration requires  At this time, a `qc` declaration also requires a file path.

```bash
qc <output name>  <variable name in quality tracker>  <path to output in module's directory>
```
