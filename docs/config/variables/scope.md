# Variable scope

In the pipeline system, the _scope_ of a variable refers to the blocks of the pipeline where that variable is active. Variables can have _subject_ scope, _module_ scope, _global_ scope, or _local/functional_ scope. The scope of each variable is typically set when the variable is defined in the pipeline's _design file_.

### Subject-level variables

_Subject-level_ variables are active only for a single subject (or, more precisely, for a single line of the cohort file), but they persist across the entire pipeline for that subject. A variable is given subject-level scope if it is defined as an array variable with the array index `sub`.

```
referenceVolume[sub]=XX000_referenceVolume.nii.gz
```

### Module-level variables

_Module-level_ variables are active only in the context of a single pipeline module, but they are active for all subjects in the context of that module. A variable is given module-level scope if it is defined as an array variable with the array index `cxt`.

```bash
confound_gsr[cxt]=mean
```

When the pipeline is launched, the value of `cxt` is set to `0`. As the pipeline completes each module, the value of `cxt` is incremented. Thus, during the first module, `cxt` is equal to `1`. During the second module, `cxt` is equal to `2`. During the ninth module, `cxt` is equal to `9`.

```
pipeline=confound,regress
prestats_tmpf[1]=
```

### Global variables

Global variables are active across all modules and across all subjects. They notably include the `pipeline` variable, which specifies the modular constitution of the pipeline.

### Local variables

Local variables are active only in the body of a function. They do not persist outside of the function; as soon as the function runs to completion, these variables become unset.
