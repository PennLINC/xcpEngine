import pytest
import os
import os.path as op
import shutil
import tempfile

fmriprep_output_files = """
dataset_description.json
logs/CITATION.html
logs/CITATION.md
logs/CITATION.tex
sub-01/anat/sub-01_desc-aparcaseg_dseg.nii.gz
sub-01/anat/sub-01_desc-aseg_dseg.nii.gz
sub-01/anat/sub-01_desc-brain_mask.nii.gz
sub-01/anat/sub-01_desc-preproc_T1w.nii.gz
sub-01/anat/sub-01_dseg.nii.gz
sub-01/anat/sub-01_from-MNI152NLin2009cAsym_to-T1w_mode-image_xfm.h5
sub-01/anat/sub-01_from-orig_to-T1w_mode-image_xfm.txt
sub-01/anat/sub-01_from-T1w_to-fsnative_mode-image_xfm.txt
sub-01/anat/sub-01_from-T1w_to-MNI152NLin2009cAsym_mode-image_xfm.h5
sub-01/anat/sub-01_hemi-L_inflated.surf.gii
sub-01/anat/sub-01_hemi-L_midthickness.surf.gii
sub-01/anat/sub-01_hemi-L_pial.surf.gii
sub-01/anat/sub-01_hemi-L_smoothwm.surf.gii
sub-01/anat/sub-01_hemi-R_inflated.surf.gii
sub-01/anat/sub-01_hemi-R_midthickness.surf.gii
sub-01/anat/sub-01_hemi-R_pial.surf.gii
sub-01/anat/sub-01_hemi-R_smoothwm.surf.gii
sub-01/anat/sub-01_label-CSF_probseg.nii.gz
sub-01/anat/sub-01_label-GM_probseg.nii.gz
sub-01/anat/sub-01_label-WM_probseg.nii.gz
sub-01/anat/sub-01_space-MNI152NLin2009cAsym_desc-brain_mask.nii.gz
sub-01/anat/sub-01_space-MNI152NLin2009cAsym_desc-preproc_T1w.nii.gz
sub-01/anat/sub-01_space-MNI152NLin2009cAsym_dseg.nii.gz
sub-01/anat/sub-01_space-MNI152NLin2009cAsym_label-CSF_probseg.nii.gz
sub-01/anat/sub-01_space-MNI152NLin2009cAsym_label-GM_probseg.nii.gz
sub-01/anat/sub-01_space-MNI152NLin2009cAsym_label-WM_probseg.nii.gz
sub-01/func/sub-01_task-mixedgamblestask_run-01_AROMAnoiseICs.csv
sub-01/func/sub-01_task-mixedgamblestask_run-01_bold.dtseries.json
sub-01/func/sub-01_task-mixedgamblestask_run-01_bold.dtseries.nii
sub-01/func/sub-01_task-mixedgamblestask_run-01_desc-confounds_regressors.tsv
sub-01/func/sub-01_task-mixedgamblestask_run-01_desc-MELODIC_mixing.tsv
sub-01/func/sub-01_task-mixedgamblestask_run-01_space-fsaverage5_hemi-L.func.gii
sub-01/func/sub-01_task-mixedgamblestask_run-01_space-fsaverage5_hemi-R.func.gii
sub-01/func/sub-01_task-mixedgamblestask_run-01_space-MNI152NLin2009cAsym_boldref.nii.gz
sub-01/func/sub-01_task-mixedgamblestask_run-01_space-MNI152NLin2009cAsym_desc-brain_mask.nii.gz
sub-01/func/sub-01_task-mixedgamblestask_run-01_space-MNI152NLin2009cAsym_desc-preproc_bold.nii.gz
sub-01/func/sub-01_task-mixedgamblestask_run-01_space-MNI152NLin2009cAsym_desc-smoothAROMAnonaggr_bold.nii.gz
sub-01/func/sub-01_task-mixedgamblestask_run-01_space-T1w_boldref.nii.gz
sub-01/func/sub-01_task-mixedgamblestask_run-01_space-T1w_desc-aparcaseg_dseg.nii.gz
sub-01/func/sub-01_task-mixedgamblestask_run-01_space-T1w_desc-aseg_dseg.nii.gz
sub-01/func/sub-01_task-mixedgamblestask_run-01_space-T1w_desc-brain_mask.nii.gz
sub-01/func/sub-01_task-mixedgamblestask_run-01_space-T1w_desc-preproc_bold.nii.gz
sub-01/func/sub-01_task-mixedgamblestask_run-02_AROMAnoiseICs.csv
sub-01/func/sub-01_task-mixedgamblestask_run-02_bold.dtseries.json
sub-01/func/sub-01_task-mixedgamblestask_run-02_bold.dtseries.nii
sub-01/func/sub-01_task-mixedgamblestask_run-02_desc-confounds_regressors.tsv
sub-01/func/sub-01_task-mixedgamblestask_run-02_desc-MELODIC_mixing.tsv
sub-01/func/sub-01_task-mixedgamblestask_run-02_space-fsaverage5_hemi-L.func.gii
sub-01/func/sub-01_task-mixedgamblestask_run-02_space-fsaverage5_hemi-R.func.gii
sub-01/func/sub-01_task-mixedgamblestask_run-02_space-MNI152NLin2009cAsym_boldref.nii.gz
sub-01/func/sub-01_task-mixedgamblestask_run-02_space-MNI152NLin2009cAsym_desc-brain_mask.nii.gz
sub-01/func/sub-01_task-mixedgamblestask_run-02_space-MNI152NLin2009cAsym_desc-preproc_bold.nii.gz
sub-01/func/sub-01_task-mixedgamblestask_run-02_space-MNI152NLin2009cAsym_desc-smoothAROMAnonaggr_bold.nii.gz
sub-01/func/sub-01_task-mixedgamblestask_run-02_space-T1w_boldref.nii.gz
sub-01/func/sub-01_task-mixedgamblestask_run-02_space-T1w_desc-aparcaseg_dseg.nii.gz
sub-01/func/sub-01_task-mixedgamblestask_run-02_space-T1w_desc-aseg_dseg.nii.gz
sub-01/func/sub-01_task-mixedgamblestask_run-02_space-T1w_desc-brain_mask.nii.gz
sub-01/func/sub-01_task-mixedgamblestask_run-02_space-T1w_desc-preproc_bold.nii.gz
sub-01.html
"""



def xcp_run(cohort_arg="", design_arg="-d /xcpEngine/designs/fc-36p.dsn",
            workdir_arg="", relpath_arg="", output_arg=""):
    cmd = ["/opt/miniconda-latest/envs/neuro/bin/python",
           "/xcpEngine/checks/check_inputs.py",
           cohort_arg, design_arg, workdir_arg, relpath_arg, output_arg]
    return os.system(" ".join(cmd))


def touch(fname, times=None):
    with open(fname, 'a'):
        os.utime(fname, times)

mni_cohort = """\
id0,img
sub-01,sub-01/func/sub-01_task-mixedgamblestask_run-01_space-MNI152NLin2009cAsym_desc-preproc_bold.nii.gz
sub-01,sub-01/func/sub-01_task-mixedgamblestask_run-02_space-MNI152NLin2009cAsym_desc-preproc_bold.nii.gz
"""

t1w_cohort = """\
id0,img
sub-01,sub-01/func/sub-01_task-mixedgamblestask_run-01_space-T1w_desc-preproc_bold.nii.gz
sub-01,sub-01/func/sub-01_task-mixedgamblestask_run-02_space-T1w_desc-preproc_bold.nii.gz
"""

anat_cohort = """\
id0,img
sub-1,/anat/sub-1_desc-preproc_T1w.nii.gz
"""

bad_characters_cohort = """\
id0,img
sub-1,/func/sub-1_task-rest_space-T1w_desc-preproc_bold.nii.gz
sub-1,/func/sub-1>>_task-rest_space-T1w_desc-preproc_bold.nii.gz
"""

cohort_w_antsct = """\
id0,img,antsct
sub-1,/func/sub-1>>_task-rest_space-T1w_desc-preproc_bold.nii.gz,/func/sub-1
"""

cohort_w_confound2_custom = """\
id0,img,confound2_custom
sub-1,/func/sub-1_task-rest_space-T1w_desc-preproc_bold.nii.gz,sub-01/func/sub-01_task-mixedgamblestask_run-02_desc-MELODIC_mixing.tsv
"""

invalid_column="""\
id0,img,nonsense
sub-01,sub-01/func/sub-01_task-mixedgamblestask_run-01_space-T1w_desc-preproc_bold.nii.gz
sub-01,sub-01/func/sub-01_task-mixedgamblestask_run-02_space-T1w_desc-preproc_bold.nii.gz
"""

cohorts = {
    "mni_cohort.csv": mni_cohort,
    "t1w_cohort.csv": t1w_cohort,
    "anat_cohort.csv": anat_cohort,
    "bad_characters_cohort.csv": bad_characters_cohort,
    "cohort_w_antsct.csv": cohort_w_antsct,
    "cohort_w_confound2_custom.csv": cohort_w_confound2_custom,
    "invalid_column.csv": invalid_column
}

def create_test_data(wd):
    # Create fake fmriprep output
    fmp_path = op.join(wd, "fmriprep_output")
    for fname in fmriprep_output_files.split():
        new_abspath = op.join(fmp_path, fname)
        new_dir, new_basename = op.split(new_abspath)
        if not op.exists(new_dir):
            os.makedirs(new_dir)
        touch(new_abspath)

    # Create the different cohort files
    for fname, content in cohorts.items():
        fullpath = op.join(wd, fname)
        with open(fullpath, "w") as f:
            f.write(content)


@pytest.fixture
def working_dir(request):
    working_dir = tempfile.mkdtemp()
    create_test_data(working_dir)
    os.makedirs(op.join(working_dir, "work"))
    os.makedirs(op.join(working_dir, "xcpOutput"))

    def fin():
        shutil.rmtree(working_dir)
    request.addfinalizer(fin)

    return working_dir

def get_paths(wd):

    return (op.join(wd, "fmriprep_output"), op.join(wd, "work"),
            op.join(wd, "xcpOutput"))

def test_working_example(working_dir):
    assert op.exists(working_dir)
    fmp_dir, work_dir, out_dir = get_paths(working_dir)
    cohort_file = op.join(working_dir, "mni_cohort.csv")
    check = xcp_run(cohort_arg="-c " + cohort_file,
                    relpath_arg="-r " + fmp_dir,
                    workdir_arg="-i " + work_dir,
                    output_arg="-o " + out_dir
                    )
    assert int(check) == 0
