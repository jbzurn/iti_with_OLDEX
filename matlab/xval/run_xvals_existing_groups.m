function run_xvals_existing_groups(dataset,n_xval,root_dir)
%cross-validate with ITI for data that has already been split into
%cross-validation sets

% dataset = 'robot_onebadwrist';
% n_xval = 10;
% root_dir = 'C:\Users\Brooks\Documents\MATLAB\robot\';
filename = strcat(root_dir,dataset);
% load(filename,'zip_train_data','zip_train_classes');
% dir_location = strcat(root_dir,'/',dataset);
dir_location = strcat(root_dir,'/',dataset);
load(filename,'zip_train_data','zip_train_classes');

if(~exist(dir_location,'dir'))
    mkdir(dir_location)
end

%split_xval_groups(zip_train_data,zip_train_classes,n_xval,dataset);
%they will all be split the same since its not randomized

%xval(dataset,n_xval,dir_location);
xval(dataset,n_xval,filename);
%test crossvalidation sets


