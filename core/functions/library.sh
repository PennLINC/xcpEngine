#!/usr/bin/env bash

###################################################################
#  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  #
###################################################################

###################################################################
# Load the complete XCP bash function library.
###################################################################
LIBRARY=${XCPEDIR}/core/functions

source ${LIBRARY}/abort_stream
source ${LIBRARY}/abspath
source ${LIBRARY}/add_reference
source ${LIBRARY}/apply_exec
source ${LIBRARY}/arithmetic
source ${LIBRARY}/assign
source ${LIBRARY}/atlas
source ${LIBRARY}/atlas_check
source ${LIBRARY}/atlas_parse
source ${LIBRARY}/atlas_set
source ${LIBRARY}/cleanup
source ${LIBRARY}/configure
source ${LIBRARY}/configures
source ${LIBRARY}/contains
source ${LIBRARY}/define
source ${LIBRARY}/derivative
source ${LIBRARY}/derivative_cxt
source ${LIBRARY}/derivative_floats
source ${LIBRARY}/derivative_inherit
source ${LIBRARY}/derivative_parse
source ${LIBRARY}/derivative_set
source ${LIBRARY}/doi2bib
source ${LIBRARY}/echo_cmd
source ${LIBRARY}/exec_afni
source ${LIBRARY}/exec_ants
source ${LIBRARY}/exec_c3d
source ${LIBRARY}/exec_fsl
source ${LIBRARY}/exec_sys
source ${LIBRARY}/exec_xcp
source ${LIBRARY}/final
source ${LIBRARY}/import_image
source ${LIBRARY}/import_metadata
source ${LIBRARY}/input
source ${LIBRARY}/is_1D
source ${LIBRARY}/is_image
source ${LIBRARY}/is_integer
source ${LIBRARY}/is+integer
source ${LIBRARY}/is_numeric
source ${LIBRARY}/is+numeric
source ${LIBRARY}/join_by
source ${LIBRARY}/json_get
source ${LIBRARY}/json_get_array
source ${LIBRARY}/json_keys
source ${LIBRARY}/json_merge
source ${LIBRARY}/json_multiset
source ${LIBRARY}/json_object
source ${LIBRARY}/json_print
source ${LIBRARY}/json_rm
source ${LIBRARY}/json_set
source ${LIBRARY}/json_set_array
source ${LIBRARY}/lc_prefix
source ${LIBRARY}/load_atlas
source ${LIBRARY}/load_derivatives
source ${LIBRARY}/matchexact
source ${LIBRARY}/matching
source ${LIBRARY}/ninstances
source ${LIBRARY}/output
source ${LIBRARY}/printx
source ${LIBRARY}/proc_afni
source ${LIBRARY}/proc_ants
source ${LIBRARY}/proc_c3d
source ${LIBRARY}/proc_cmd
source ${LIBRARY}/proc_fsl
source ${LIBRARY}/proc_xcp
source ${LIBRARY}/process
source ${LIBRARY}/processed
source ${LIBRARY}/qc
source ${LIBRARY}/quality_metric
source ${LIBRARY}/repeat
source ${LIBRARY}/require
source ${LIBRARY}/rerun
source ${LIBRARY}/rln
source ${LIBRARY}/routine
source ${LIBRARY}/routine_end
source ${LIBRARY}/set_space
source ${LIBRARY}/space_get
source ${LIBRARY}/space_set
source ${LIBRARY}/strslice
source ${LIBRARY}/subroutine
source ${LIBRARY}/subject_parse
source ${LIBRARY}/transform_set
source ${LIBRARY}/verbose
source ${LIBRARY}/warpspace
source ${LIBRARY}/write_atlas
source ${LIBRARY}/write_config_safe
source ${LIBRARY}/write_config
source ${LIBRARY}/write_derivative
source ${LIBRARY}/write_output
source ${LIBRARY}/zscore_image
