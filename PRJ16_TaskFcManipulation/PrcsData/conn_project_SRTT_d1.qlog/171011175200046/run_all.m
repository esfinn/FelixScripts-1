% auto-generated by conn_jobmanager
% this script can be used to run this process from Matlab locally on this machine (or in a Matlab parallel toolbox environment)

addpath /gpfs/gsfs5/users/jangrawdc/MATLAB/Toolboxes/spm12/spm12;
addpath /gpfs/gsfs5/users/jangrawdc/MATLAB/Toolboxes/conn17f/conn;
cd /gpfs/gsfs5/users/jangrawdc/PRJ16_TaskFcManipulation/PrcsData/conn_project_SRTT_d1.qlog/171011175200046;

jobs={'/gpfs/gsfs5/users/jangrawdc/PRJ16_TaskFcManipulation/PrcsData/conn_project_SRTT_d1.qlog/171011175200046/node.0001171011175200046.mat','/gpfs/gsfs5/users/jangrawdc/PRJ16_TaskFcManipulation/PrcsData/conn_project_SRTT_d1.qlog/171011175200046/node.0002171011175200046.mat','/gpfs/gsfs5/users/jangrawdc/PRJ16_TaskFcManipulation/PrcsData/conn_project_SRTT_d1.qlog/171011175200046/node.0003171011175200046.mat','/gpfs/gsfs5/users/jangrawdc/PRJ16_TaskFcManipulation/PrcsData/conn_project_SRTT_d1.qlog/171011175200046/node.0004171011175200046.mat','/gpfs/gsfs5/users/jangrawdc/PRJ16_TaskFcManipulation/PrcsData/conn_project_SRTT_d1.qlog/171011175200046/node.0005171011175200046.mat'};
% runs individual jobs
parfor n=1:numel(jobs)
  conn_jobmanager('exec',jobs{n});
end

% merges job outputs with conn project
conn load '/gpfs/gsfs5/users/jangrawdc/PRJ16_TaskFcManipulation/PrcsData/conn_project_SRTT_d1.mat';
conn save;