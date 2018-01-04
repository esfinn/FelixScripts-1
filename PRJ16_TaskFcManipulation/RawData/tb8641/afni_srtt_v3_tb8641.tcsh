#!/bin/tcsh -xef

echo "auto-generated by afni_proc.py, Wed Jan  3 09:36:14 2018"
echo "(version 6.02, December 12, 2017)"
echo "execution started: `date`"

# execute via : 
#   tcsh -xef afni_srtt_v3_tb8641.tcsh 2>&1 | tee output.afni_srtt_v3_tb8641.tcsh

# =========================== auto block: setup ============================
# script setup

# take note of the AFNI version
afni -ver

# check that the current AFNI version is recent enough
afni_history -check_date 23 Sep 2016
if ( $status ) then
    echo "** this script requires newer AFNI binaries (than 23 Sep 2016)"
    echo "   (consider: @update.afni.binaries -defaults)"
    exit
endif

# the user may specify a single subject to run with
if ( $#argv > 0 ) then
    set subj = $argv[1]
else
    set subj = tb8641
endif

# assign output directory name
set output_dir = tb8641.srtt_v3

# verify that the results directory does not yet exist
if ( -d $output_dir ) then
    echo output dir "$subj.results" already exists
    exit
endif

# set list of runs
set runs = (`count -digits 2 1 3`)

# create results and stimuli directories
mkdir $output_dir
mkdir $output_dir/stimuli

# copy stim files into stimulus directory
cp stim_times/stim_times_srtt/bl1_c1_unstr.txt  \
    stim_times/stim_times_srtt/bl2_c1_unstr.txt \
    stim_times/stim_times_srtt/bl3_c1_unstr.txt \
    stim_times/stim_times_srtt/bl1_c2_str.txt   \
    stim_times/stim_times_srtt/bl2_c2_str.txt   \
    stim_times/stim_times_srtt/bl3_c2_str.txt $output_dir/stimuli

# copy anatomy to results dir
3dcopy anat/Sag3DMPRAGE_Fixed.nii.gz $output_dir/Sag3DMPRAGE_Fixed

# ============================ auto block: tcat ============================
# apply 3dTcat to copy input dsets to results dir, while
# removing the first 6 TRs
3dTcat -prefix $output_dir/pb00.$subj.r01.tcat \
    func_srtt/ep2dbold156s005a001.nii.gz'[6..$]'
3dTcat -prefix $output_dir/pb00.$subj.r02.tcat \
    func_srtt/ep2dbold156s007a001.nii.gz'[6..$]'
3dTcat -prefix $output_dir/pb00.$subj.r03.tcat \
    func_srtt/ep2dbold156s009a001.nii.gz'[6..$]'

# and make note of repetitions (TRs) per run
set tr_counts = ( 150 150 150 )

# -------------------------------------------------------
# enter the results directory (can begin processing data)
cd $output_dir


# ========================== auto block: outcount ==========================
# data check: compute outlier fraction for each volume
touch out.pre_ss_warn.txt
foreach run ( $runs )
    3dToutcount -automask -fraction -polort 3 -legendre                     \
                pb00.$subj.r$run.tcat+orig > outcount.r$run.1D

    # censor outlier TRs per run, ignoring the first 0 TRs
    # - censor when more than 0.1 of automask voxels are outliers
    # - step() defines which TRs to remove via censoring
    1deval -a outcount.r$run.1D -expr "1-step(a-0.1)" > rm.out.cen.r$run.1D

    # outliers at TR 0 might suggest pre-steady state TRs
    if ( `1deval -a outcount.r$run.1D"{0}" -expr "step(a-0.4)"` ) then
        echo "** TR #0 outliers: possible pre-steady state TRs in run $run" \
            >> out.pre_ss_warn.txt
    endif
end

# catenate outlier counts into a single time series
cat outcount.r*.1D > outcount_rall.1D

# catenate outlier censor files into a single time series
cat rm.out.cen.r*.1D > outcount_${subj}_censor.1D

# ================================ despike =================================
# apply 3dDespike to each run
foreach run ( $runs )
    3dDespike -NEW -nomask -prefix pb01.$subj.r$run.despike \
        pb00.$subj.r$run.tcat+orig
end

# ================================= tshift =================================
# time shift data so all slice timing is the same 
foreach run ( $runs )
    3dTshift -tzero 0 -quintic -prefix pb02.$subj.r$run.tshift \
             -tpattern alt+z2                                  \
             pb01.$subj.r$run.despike+orig
end

# --------------------------------
# extract volreg registration base
3dbucket -prefix vr_base pb02.$subj.r01.tshift+orig"[0]"

# ================================= align ==================================
# for e2a: compute anat alignment transformation to EPI registration base
# (new anat will be intermediate, stripped, Sag3DMPRAGE_Fixed_ns+orig)
align_epi_anat.py -anat2epi -anat Sag3DMPRAGE_Fixed+orig \
       -save_skullstrip -suffix _al_junk                 \
       -epi vr_base+orig -epi_base 0                     \
       -epi_strip 3dAutomask                             \
       -giant_move                                       \
       -volreg off -tshift off

# ================================== tlrc ==================================
# warp anatomy to standard space (non-linear warp)
auto_warp.py -base MNI152_T1_2009c+tlrc -input Sag3DMPRAGE_Fixed_ns+orig \
             -skull_strip_input no

# move results up out of the awpy directory
# (NL-warped anat, affine warp, NL warp)
# (use typical standard space name for anat)
# (wildcard is a cheap way to go after any .gz)
3dbucket -prefix Sag3DMPRAGE_Fixed_ns awpy/Sag3DMPRAGE_Fixed_ns.aw.nii*
mv awpy/anat.un.aff.Xat.1D .
mv awpy/anat.un.aff.qw_WARP.nii .

# ================================= volreg =================================
# align each dset to base volume, align to anat, warp to tlrc space

# verify that we have a +tlrc warp dataset
if ( ! -f Sag3DMPRAGE_Fixed_ns+tlrc.HEAD ) then
    echo "** missing +tlrc warp dataset: Sag3DMPRAGE_Fixed_ns+tlrc.HEAD" 
    exit
endif

# register and warp
foreach run ( $runs )
    # register each volume to the base
    3dvolreg -verbose -zpad 1 -base vr_base+orig                              \
             -1Dfile dfile.r$run.1D -prefix rm.epi.volreg.r$run               \
             -cubic                                                           \
             -1Dmatrix_save mat.r$run.vr.aff12.1D                             \
             pb02.$subj.r$run.tshift+orig

    # create an all-1 dataset to mask the extents of the warp
    3dcalc -overwrite -a pb02.$subj.r$run.tshift+orig -expr 1                 \
           -prefix rm.epi.all1

    # catenate volreg/epi2anat/tlrc xforms
    cat_matvec -ONELINE                                                       \
               anat.un.aff.Xat.1D                                             \
               Sag3DMPRAGE_Fixed_al_junk_mat.aff12.1D -I                      \
               mat.r$run.vr.aff12.1D > mat.r$run.warp.aff12.1D

    # apply catenated xform: volreg/epi2anat/tlrc
    # then apply non-linear standard-space warp
    3dNwarpApply -master Sag3DMPRAGE_Fixed_ns+tlrc -dxyz 3                    \
                 -source pb02.$subj.r$run.tshift+orig                         \
                 -nwarp "anat.un.aff.qw_WARP.nii mat.r$run.warp.aff12.1D"     \
                 -prefix rm.epi.nomask.r$run

    # warp the all-1 dataset for extents masking 
    3dNwarpApply -master Sag3DMPRAGE_Fixed_ns+tlrc -dxyz 3                    \
                 -source rm.epi.all1+orig                                     \
                 -nwarp "anat.un.aff.qw_WARP.nii mat.r$run.warp.aff12.1D"     \
                 -interp cubic                                                \
                 -ainterp NN -quiet                                           \
                 -prefix rm.epi.1.r$run

    # make an extents intersection mask of this run
    3dTstat -min -prefix rm.epi.min.r$run rm.epi.1.r$run+tlrc
end

# make a single file of registration params
cat dfile.r*.1D > dfile_rall.1D

# ----------------------------------------
# create the extents mask: mask_epi_extents+tlrc
# (this is a mask of voxels that have valid data at every TR)
3dMean -datum short -prefix rm.epi.mean rm.epi.min.r*.HEAD 
3dcalc -a rm.epi.mean+tlrc -expr 'step(a-0.999)' -prefix mask_epi_extents

# and apply the extents mask to the EPI data 
# (delete any time series with missing data)
foreach run ( $runs )
    3dcalc -a rm.epi.nomask.r$run+tlrc -b mask_epi_extents+tlrc               \
           -expr 'a*b' -prefix pb03.$subj.r$run.volreg
end

# warp the volreg base EPI dataset to make a final version
cat_matvec -ONELINE                                                           \
           anat.un.aff.Xat.1D                                                 \
           Sag3DMPRAGE_Fixed_al_junk_mat.aff12.1D -I  > mat.basewarp.aff12.1D

3dNwarpApply -master Sag3DMPRAGE_Fixed_ns+tlrc -dxyz 3                        \
             -source vr_base+orig                                             \
             -nwarp "anat.un.aff.qw_WARP.nii mat.basewarp.aff12.1D"           \
             -prefix final_epi_vr_base

# create an anat_final dataset, aligned with stats
3dcopy Sag3DMPRAGE_Fixed_ns+tlrc anat_final.$subj

# record final registration costs
3dAllineate -base final_epi_vr_base+tlrc -allcostX                            \
            -input anat_final.$subj+tlrc |& tee out.allcostX.txt

# -----------------------------------------
# warp anat follower datasets (non-linear)
3dNwarpApply -source Sag3DMPRAGE_Fixed+orig                                   \
             -master anat_final.$subj+tlrc                                    \
             -ainterp wsinc5 -nwarp anat.un.aff.qw_WARP.nii anat.un.aff.Xat.1D\
             -prefix anat_w_skull_warped

# ================================== blur ==================================
# blur each volume of each run
foreach run ( $runs )
    3dmerge -1blur_fwhm 6 -doall -prefix pb04.$subj.r$run.blur \
            pb03.$subj.r$run.volreg+tlrc
end

# ================================== mask ==================================
# create 'full_mask' dataset (union mask)
foreach run ( $runs )
    3dAutomask -dilate 1 -prefix rm.mask_r$run pb04.$subj.r$run.blur+tlrc
end

# create union of inputs, output type is byte
3dmask_tool -inputs rm.mask_r*+tlrc.HEAD -union -prefix full_mask.$subj

# ---- create subject anatomy mask, mask_anat.$subj+tlrc ----
#      (resampled from tlrc anat)
3dresample -master full_mask.$subj+tlrc -input Sag3DMPRAGE_Fixed_ns+tlrc \
           -prefix rm.resam.anat

# convert to binary anat mask; fill gaps and holes
3dmask_tool -dilate_input 5 -5 -fill_holes -input rm.resam.anat+tlrc     \
            -prefix mask_anat.$subj

# compute overlaps between anat and EPI masks
3dABoverlap -no_automask full_mask.$subj+tlrc mask_anat.$subj+tlrc       \
            |& tee out.mask_ae_overlap.txt

# note Dice coefficient of masks, as well
3ddot -dodice full_mask.$subj+tlrc mask_anat.$subj+tlrc                  \
      |& tee out.mask_ae_dice.txt

# ---- create group anatomy mask, mask_group+tlrc ----
#      (resampled from tlrc base anat, MNI152_T1_2009c+tlrc)
3dresample -master full_mask.$subj+tlrc -prefix ./rm.resam.group         \
           -input                                                        \
           /usr/local/apps/afni/current/linux_openmp_64/MNI152_T1_2009c+tlrc

# convert to binary group mask; fill gaps and holes
3dmask_tool -dilate_input 5 -5 -fill_holes -input rm.resam.group+tlrc    \
            -prefix mask_group

# ================================= scale ==================================
# scale each voxel time series to have a mean of 100
# (be sure no negatives creep in)
# (subject to a range of [0,200])
foreach run ( $runs )
    3dTstat -prefix rm.mean_r$run pb04.$subj.r$run.blur+tlrc
    3dcalc -a pb04.$subj.r$run.blur+tlrc -b rm.mean_r$run+tlrc \
           -c mask_epi_extents+tlrc                            \
           -expr 'c * min(200, a/b*100)*step(a)*step(b)'       \
           -prefix pb05.$subj.r$run.scale
end

# ================================ regress =================================

# compute de-meaned motion parameters (for use in regression)
1d_tool.py -infile dfile_rall.1D -set_nruns 3                                \
           -demean -write motion_demean.1D

# compute motion parameter derivatives (for use in regression)
1d_tool.py -infile dfile_rall.1D -set_nruns 3                                \
           -derivative -demean -write motion_deriv.1D

# create censor file motion_${subj}_censor.1D, for censoring motion 
1d_tool.py -infile dfile_rall.1D -set_nruns 3                                \
    -show_censor_count -censor_prev_TR                                       \
    -censor_motion 0.3 motion_${subj}

# combine multiple censor files
1deval -a motion_${subj}_censor.1D -b outcount_${subj}_censor.1D             \
       -expr "a*b" > censor_${subj}_combined_2.1D

# note TRs that were not censored
set ktrs = `1d_tool.py -infile censor_${subj}_combined_2.1D                  \
                       -show_trs_uncensored encoded`

# ------------------------------
# run the regression analysis
3dDeconvolve -input pb05.$subj.r*.scale+tlrc.HEAD                            \
    -censor censor_${subj}_combined_2.1D                                     \
    -polort 3                                                                \
    -local_times                                                             \
    -num_stimts 18                                                           \
    -stim_times_AM1 1 stimuli/bl1_c1_unstr.txt 'dmBLOCK(1)'                  \
    -stim_label 1 uns1                                                       \
    -stim_times_AM1 2 stimuli/bl2_c1_unstr.txt 'dmBLOCK(1)'                  \
    -stim_label 2 uns2                                                       \
    -stim_times_AM1 3 stimuli/bl3_c1_unstr.txt 'dmBLOCK(1)'                  \
    -stim_label 3 uns3                                                       \
    -stim_times_AM1 4 stimuli/bl1_c2_str.txt 'dmBLOCK(1)'                    \
    -stim_label 4 str1                                                       \
    -stim_times_AM1 5 stimuli/bl2_c2_str.txt 'dmBLOCK(1)'                    \
    -stim_label 5 str2                                                       \
    -stim_times_AM1 6 stimuli/bl3_c2_str.txt 'dmBLOCK(1)'                    \
    -stim_label 6 str3                                                       \
    -stim_file 7 motion_demean.1D'[0]' -stim_base 7 -stim_label 7 roll_01    \
    -stim_file 8 motion_demean.1D'[1]' -stim_base 8 -stim_label 8 pitch_01   \
    -stim_file 9 motion_demean.1D'[2]' -stim_base 9 -stim_label 9 yaw_01     \
    -stim_file 10 motion_demean.1D'[3]' -stim_base 10 -stim_label 10 dS_01   \
    -stim_file 11 motion_demean.1D'[4]' -stim_base 11 -stim_label 11 dL_01   \
    -stim_file 12 motion_demean.1D'[5]' -stim_base 12 -stim_label 12 dP_01   \
    -stim_file 13 motion_deriv.1D'[0]' -stim_base 13 -stim_label 13 roll_02  \
    -stim_file 14 motion_deriv.1D'[1]' -stim_base 14 -stim_label 14 pitch_02 \
    -stim_file 15 motion_deriv.1D'[2]' -stim_base 15 -stim_label 15 yaw_02   \
    -stim_file 16 motion_deriv.1D'[3]' -stim_base 16 -stim_label 16 dS_02    \
    -stim_file 17 motion_deriv.1D'[4]' -stim_base 17 -stim_label 17 dL_02    \
    -stim_file 18 motion_deriv.1D'[5]' -stim_base 18 -stim_label 18 dP_02    \
    -num_glt 10                                                              \
    -gltsym 'SYM: +uns1 +uns2 +uns3'                                         \
    -glt_label 1 unstructured                                                \
    -gltsym 'SYM: +str1 +str2 +str3'                                         \
    -glt_label 2 structured                                                  \
    -gltsym 'SYM: +uns1 +uns2 +uns3 -str1 -str2 -str3'                       \
    -glt_label 3 unstructured-structured                                     \
    -gltsym 'SYM: +uns1 -str1'                                               \
    -glt_label 4 'unstructured-structured BL1'                               \
    -gltsym 'SYM: +uns2 -str2'                                               \
    -glt_label 5 'unstructured-structured BL2'                               \
    -gltsym 'SYM: +uns3 -str3'                                               \
    -glt_label 6 'unstructured-structured BL3'                               \
    -gltsym 'SYM: +uns1 +uns2 +uns3 +str1 +str2 +str3'                       \
    -glt_label 7 task                                                        \
    -gltsym 'SYM: +uns1 +str1'                                               \
    -glt_label 8 'task BL1'                                                  \
    -gltsym 'SYM: +uns2 +str2'                                               \
    -glt_label 9 'task BL2'                                                  \
    -gltsym 'SYM: +uns3 +str3'                                               \
    -glt_label 10 'task BL3'                                                 \
    -jobs 10                                                                 \
    -fout -tout -x1D X.xmat.1D -xjpeg X.jpg                                  \
    -x1D_uncensored X.nocensor.xmat.1D                                       \
    -fitts fitts.$subj                                                       \
    -errts errts.${subj}                                                     \
    -bucket stats.$subj


# if 3dDeconvolve fails, terminate the script
if ( $status != 0 ) then
    echo '---------------------------------------'
    echo '** 3dDeconvolve error, failing...'
    echo '   (consider the file 3dDeconvolve.err)'
    exit
endif


# display any large pairwise correlations from the X-matrix
1d_tool.py -show_cormat_warnings -infile X.xmat.1D |& tee out.cormat_warn.txt

# -- execute the 3dREMLfit script, written by 3dDeconvolve --
tcsh -x stats.REML_cmd 

# if 3dREMLfit fails, terminate the script
if ( $status != 0 ) then
    echo '---------------------------------------'
    echo '** 3dREMLfit error, failing...'
    exit
endif


# create an all_runs dataset to match the fitts, errts, etc.
3dTcat -prefix all_runs.$subj pb05.$subj.r*.scale+tlrc.HEAD

# --------------------------------------------------
# create a temporal signal to noise ratio dataset 
#    signal: if 'scale' block, mean should be 100
#    noise : compute standard deviation of errts
3dTstat -mean -prefix rm.signal.all all_runs.$subj+tlrc"[$ktrs]"
3dTstat -stdev -prefix rm.noise.all errts.${subj}_REML+tlrc"[$ktrs]"
3dcalc -a rm.signal.all+tlrc                                                 \
       -b rm.noise.all+tlrc                                                  \
       -c full_mask.$subj+tlrc                                               \
       -expr 'c*a/b' -prefix TSNR.$subj 

# ---------------------------------------------------
# compute and store GCOR (global correlation average)
# (sum of squares of global mean of unit errts)
3dTnorm -norm2 -prefix rm.errts.unit errts.${subj}_REML+tlrc
3dmaskave -quiet -mask full_mask.$subj+tlrc rm.errts.unit+tlrc               \
          > gmean.errts.unit.1D
3dTstat -sos -prefix - gmean.errts.unit.1D\' > out.gcor.1D
echo "-- GCOR = `cat out.gcor.1D`"

# ---------------------------------------------------
# compute correlation volume
# (per voxel: average correlation across masked brain)
# (now just dot product with average unit time series)
3dcalc -a rm.errts.unit+tlrc -b gmean.errts.unit.1D -expr 'a*b' -prefix rm.DP
3dTstat -sum -prefix corr_brain rm.DP+tlrc

# create ideal files for fixed response stim types
1dcat X.nocensor.xmat.1D'[12]' > ideal_uns1.1D
1dcat X.nocensor.xmat.1D'[13]' > ideal_uns2.1D
1dcat X.nocensor.xmat.1D'[14]' > ideal_uns3.1D
1dcat X.nocensor.xmat.1D'[15]' > ideal_str1.1D
1dcat X.nocensor.xmat.1D'[16]' > ideal_str2.1D
1dcat X.nocensor.xmat.1D'[17]' > ideal_str3.1D

# --------------------------------------------------------
# compute sum of non-baseline regressors from the X-matrix
# (use 1d_tool.py to get list of regressor colums)
set reg_cols = `1d_tool.py -infile X.nocensor.xmat.1D -show_indices_interest`
3dTstat -sum -prefix sum_ideal.1D X.nocensor.xmat.1D"[$reg_cols]"

# also, create a stimulus-only X-matrix, for easy review
1dcat X.nocensor.xmat.1D"[$reg_cols]" > X.stim.xmat.1D

# ============================ blur estimation =============================
# compute blur estimates
touch blur_est.$subj.1D   # start with empty file

# create directory for ACF curve files
mkdir files_ACF

# -- estimate blur for each run in errts --
touch blur.errts.1D

# restrict to uncensored TRs, per run
foreach run ( $runs )
    set trs = `1d_tool.py -infile X.xmat.1D -show_trs_uncensored encoded     \
                          -show_trs_run $run`
    if ( $trs == "" ) continue
    3dFWHMx -detrend -mask full_mask.$subj+tlrc                              \
            -ACF files_ACF/out.3dFWHMx.ACF.errts.r$run.1D                    \
            errts.${subj}+tlrc"[$trs]" >> blur.errts.1D
end

# compute average FWHM blur (from every other row) and append
set blurs = ( `3dTstat -mean -prefix - blur.errts.1D'{0..$(2)}'\'` )
echo average errts FWHM blurs: $blurs
echo "$blurs   # errts FWHM blur estimates" >> blur_est.$subj.1D

# compute average ACF blur (from every other row) and append
set blurs = ( `3dTstat -mean -prefix - blur.errts.1D'{1..$(2)}'\'` )
echo average errts ACF blurs: $blurs
echo "$blurs   # errts ACF blur estimates" >> blur_est.$subj.1D

# -- estimate blur for each run in err_reml --
touch blur.err_reml.1D

# restrict to uncensored TRs, per run
foreach run ( $runs )
    set trs = `1d_tool.py -infile X.xmat.1D -show_trs_uncensored encoded     \
                          -show_trs_run $run`
    if ( $trs == "" ) continue
    3dFWHMx -detrend -mask full_mask.$subj+tlrc                              \
            -ACF files_ACF/out.3dFWHMx.ACF.err_reml.r$run.1D                 \
            errts.${subj}_REML+tlrc"[$trs]" >> blur.err_reml.1D
end

# compute average FWHM blur (from every other row) and append
set blurs = ( `3dTstat -mean -prefix - blur.err_reml.1D'{0..$(2)}'\'` )
echo average err_reml FWHM blurs: $blurs
echo "$blurs   # err_reml FWHM blur estimates" >> blur_est.$subj.1D

# compute average ACF blur (from every other row) and append
set blurs = ( `3dTstat -mean -prefix - blur.err_reml.1D'{1..$(2)}'\'` )
echo average err_reml ACF blurs: $blurs
echo "$blurs   # err_reml ACF blur estimates" >> blur_est.$subj.1D


# add 3dClustSim results as attributes to any stats dset
mkdir files_ClustSim

# run Monte Carlo simulations using method 'ACF'
set params = ( `grep ACF blur_est.$subj.1D | tail -n 1` )
3dClustSim -both -mask full_mask.$subj+tlrc -acf $params[1-3]                \
           -cmd 3dClustSim.ACF.cmd -prefix files_ClustSim/ClustSim.ACF

# run 3drefit to attach 3dClustSim results to stats
set cmd = ( `cat 3dClustSim.ACF.cmd` )
$cmd stats.$subj+tlrc stats.${subj}_REML+tlrc


# ================== auto block: generate review scripts ===================

# generate a review script for the unprocessed EPI data
gen_epi_review.py -script @epi_review.$subj \
    -dsets pb00.$subj.r*.tcat+orig.HEAD

# generate scripts to review single subject results
# (try with defaults, but do not allow bad exit status)
gen_ss_review_scripts.py -mot_limit 0.3 -out_limit 0.1 -exit0

# ========================== auto block: finalize ==========================

# remove temporary files
\rm -fr rm.* awpy

# if the basic subject review script is here, run it
# (want this to be the last text output)
if ( -e @ss_review_basic ) ./@ss_review_basic |& tee out.ss_review.$subj.txt

# return to parent directory
cd ..

echo "execution finished: `date`"




# ==========================================================================
# script generated by the command:
#
# afni_proc.py -subj_id tb8641 -script afni_srtt_v3_tb8641.tcsh -out_dir      \
#     tb8641.srtt_v3 -dsets func_srtt/ep2dbold156s005a001.nii.gz              \
#     func_srtt/ep2dbold156s007a001.nii.gz                                    \
#     func_srtt/ep2dbold156s009a001.nii.gz -blocks despike tshift align tlrc  \
#     volreg blur mask scale regress -copy_anat anat/Sag3DMPRAGE_Fixed.nii.gz \
#     -anat_has_skull yes -tcat_remove_first_trs 6 -volreg_align_e2a          \
#     -tlrc_NL_warp -volreg_tlrc_warp -tlrc_base MNI152_T1_2009c+tlrc         \
#     -align_opts_aea -giant_move -tshift_opts_ts -tpattern alt+z2 -blur_size \
#     6 -volreg_align_to first -volreg_warp_dxyz 3 -regress_stim_times        \
#     stim_times/stim_times_srtt/bl1_c1_unstr.txt                             \
#     stim_times/stim_times_srtt/bl2_c1_unstr.txt                             \
#     stim_times/stim_times_srtt/bl3_c1_unstr.txt                             \
#     stim_times/stim_times_srtt/bl1_c2_str.txt                               \
#     stim_times/stim_times_srtt/bl2_c2_str.txt                               \
#     stim_times/stim_times_srtt/bl3_c2_str.txt -regress_stim_labels uns1     \
#     uns2 uns3 str1 str2 str3 -regress_local_times -regress_est_blur_errts   \
#     -regress_basis 'dmBLOCK(1)' -regress_stim_types AM1 -regress_reml_exec  \
#     -regress_censor_outliers 0.1 -regress_censor_motion 0.3                 \
#     -regress_apply_mot_types demean deriv -regress_opts_3dD -num_glt 10     \
#     -gltsym 'SYM: +uns1 +uns2 +uns3' -glt_label 1 unstructured -gltsym      \
#     'SYM: +str1 +str2 +str3' -glt_label 2 structured -gltsym 'SYM: +uns1    \
#     +uns2 +uns3 -str1 -str2 -str3' -glt_label 3 unstructured-structured     \
#     -gltsym 'SYM: +uns1 -str1' -glt_label 4 'unstructured-structured BL1'   \
#     -gltsym 'SYM: +uns2 -str2' -glt_label 5 'unstructured-structured BL2'   \
#     -gltsym 'SYM: +uns3 -str3' -glt_label 6 'unstructured-structured BL3'   \
#     -gltsym 'SYM: +uns1 +uns2 +uns3 +str1 +str2 +str3' -glt_label 7 task    \
#     -gltsym 'SYM: +uns1 +str1' -glt_label 8 'task BL1' -gltsym 'SYM: +uns2  \
#     +str2' -glt_label 9 'task BL2' -gltsym 'SYM: +uns3 +str3' -glt_label 10 \
#     'task BL3' -jobs 10 -bash -execute
