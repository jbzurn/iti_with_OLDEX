function tree = iti(filestem,varargin)
%iti main program
%author: Paul Utgoff
%modified for Matlab by J. Brooks Zurn
%version 2009-0531a
%
%takes a set of inputs and induces a decision tree off-line (batch mode)
%or on-line (incrementally) using the Kolmogorov-Smirnov distance as a
%metric.  Restructures tree recursively.  This program produces the same
%tree as ITI Version 3.10 for numerical data with string or numerical
%class names.  It has not been tested for missing data instances, and 
%does not handle symbolic data.
%
%NOTE: 'kernel' processing and cross-validation is performed using a
%separate program (scripts located in the folder gaussian_irdt).
%
%usage: iti(filestem,option1,parameter1,option2,parameter2,...
%example: tree = iti('iti/iris','l','iris','f');
%
%inputs: 
%filestem: the root folder containing data files (this is where the final 
%           program data 'datastore_main.mat' will be stored, as well as 
%           intermediate data dumps ('datadump.mat') performed in response 
%           to run-time errors.  A 'names' file must be located in this
%           directory for the program to run (the data loaded from the
%           'names' file can be changed using command line options).
%varargin: parameters for the program, including loading data, training
%           trees off-line (batch) or on-line (incrementally),
%           saving/restoring trees, and viewing trees graphically.  Viewing
%           trees requires the Statistics Toolbox V7.0 (Matlab R2008b)
%

%%***include iti header file
% ITI_VERSION = 3;
% ITI_REVISION = 10;
% COPYRIGHT_DATE = '23 March 2001';
% DATA_PATH_NAME = '';

%global variables
global FALSE
FALSE = 0;
global TRUE
TRUE = 1;
global NULL
NULL = 0;

global n_training_insts
global n_testing_insts
global n_variables
global n_OLDEX_variables
global n_classes
global current_inst_tag
global current_data_format

global all_classes
global variable_name
global total_cpu
global total_transpositions
global n_transpositions
global DEBUG_MERIT

global tree_class_counts
global tree_class_counts_tags
global tree_numeric_value_counts

kernel_type = 'NULL';
global kernel_transform_table
global kernel_const


current_inst_tag = 0;
n_transpositions = 0;
total_cpu=0;

DEBUG_MERIT = 0;

%variables
min_insts_second_majority = 1;

%assign internal variables that have pre-set values
do_performance_measuring = FALSE;
do_test_incrementally = FALSE;  %%%///jbz initialize
%  n_leaves_using_fast_train,
%  total_transpositions;

fileopen_ok = 0; %%/* jbz for 'T' */
inc_test_fp = 0;

num_attributes_namesfile = 0; % /* jbz for 'N': the number of attributes for the new names file*/
get_num_attributes_readin_ok = 0; %/* jbz for 'N': figure out whether a number was read in*/

% fprintf('ITI %d.%d - (C) Copyright, U. of Massachusetts, %s, All Rights Reserved\n\n',ITI_VERSION,ITI_REVISION,COPYRIGHT_DATE);
% fprintf('Use the option "z" to see the manual.\n\n'); 
fprintf('ITI for Matlab\n');
fprintf('usage: iti(filestem,option1,parameter1,option2,parameter2,...\n\n');

do_vpruning = FALSE;

verbose_load_instances = FALSE;
n_training_insts = 0;
n_testing_insts = 0;
title(1) = 0;
tag = NULL;
train_set = NULL;
test_set = NULL;
my_train_set = NULL;   %/* jbz */
tree = NULL;

%%%%testing variable inits
tree_exists = 0;
accuracy = 0;
n_insts = 0;
n_tests = 0;
n_leaves = 0;
xpath = 0;



i_arg = 1;
i_char = 0;

%fname = sprintf('%s%s/names',DATA_PATH_NAME,filestem);
fname = sprintf('%s/names',filestem);

fp=fopen(fname,'r');

%verbose_load_instances = 1;
try 
    if (fp)
        fclose(fp);
        fprintf('Loading variable names ...');
        [variable_name n_variables all_classes] = read_variable_names(fname,verbose_load_instances);
        [dummy n_classes] = size(all_classes);  %n_classes directly from file
        fprintf(' %d loaded\n',n_variables);
        
        tree = initialize_tree(tree,min_insts_second_majority);
        tree_class_counts = initialize_tree(tree,min_insts_second_majority);
        tree_class_counts_tags = initialize_tree(tree,min_insts_second_majority);
        tree_numeric_value_counts = initialize_tree(tree,min_insts_second_majority);
        
%         if(~isstruct(tree))
%             tree= get_tree_node(tree,n_variables,n_classes,1);
%         end
%         
%         tree(1) = load_classnames_into_tree(tree(1),all_classes);
%         for i=1:n_variables
%             tree(1).variables(i).variable_key = variable_name{i,1};
%         end
%         
%         tree(1).min_insts_second_majority = min_insts_second_majority;
        
    else
        error('Unable to open file %s\n',fname);
    end
catch
    fprintf('current directory is ');
    disp('current directory is ');
    cd
    error('Problem opening names file %s (file might be absent from directory %s\n',fname,filestem);
end

%process input arguments
%number of input arguments = nargin
if(nargin<2)
    %    error('usage: iti(filestem,option1,parameter1,option2,parameter2,...');
    fprintf('warning: not enough parameters.  usage: iti(filestem,option1,parameter1,option2,parameter2,...\n\n');
else
    arguments_remaining = nargin - 1; % the first arg was the filestem
    current_argument = 1;
    while(current_argument<=arguments_remaining)
        
        %process an argument
        %decrement the appropriate # of arguments
        switch varargin{current_argument}
            case 'd'
                current_argument = current_argument + 1;
            case 'E'
                current_argument = current_argument + 1;
            case {'e','f','i'}
                fprintf('current arg is %s\n',varargin{current_argument});
                %if(strcmp(varargin{current_argument},'f')&& tree)
                if(strcmp(varargin{current_argument},'f')&& tree_exists)
                    fprintf('Error: Can''t use fast training mode tree once tree has been\n');
                    fprintf('       created.  Using incremental training mode instead.\n');
                    varargin{current_argument} = 'i';
                end
                
                %build the tree
                if(n_training_insts)
                    %setup outfiles where necessary
                    if (do_test_incrementally)  %//jbz open the inc_test file filename b/c there's a default
                        %value even if no name is supplied to program.
                        fname = sprintf('%s.inc_test',inc_test_fname);
                        inc_test_fp = fopen(fname,'w');
                        if(inc_test_fp>0)
                            fprintf('successfully opened inc_test file %s\n',fname);
                        else
                            fprintf('couldn''t open inc_test file %s\n',fname);
                        end
                    end
                    
                    %start building tree
                    fprintf('\nBuilding tree:\n');
                    switch varargin{current_argument}
                        case 'e'
                        case 'f'
                            if(~isstruct(tree))
                                tree=get_tree_node(tree,n_variables,n_classes,1);
                            end
                            
                            %tree training function depends on data format.
                            %Check whether current data format is ITI or
                            %MATLAB
                            
                            %tree = fast_train(tree,train_set,test_set,do_vpruning,do_performance_measuring,do_test_incrementally);
                            tree = fast_train2(tree,train_fname_full_name,n_training_insts,n_variables,n_classes,all_classes);
                            
                            
                            
                            %fprintf('\ntree exists? %d',does_tree_exist(tree));
                            tree_exists = 1;
                            current_treetype = 'iti_tree';
                            
                            
                            
                            tag = 'iti-fast';
                            
                        case 'i'
                            %fprintf('\ntree exists? %d',does_tree_exist(tree));
                            if(~isstruct(tree))
                                tree=get_tree_node(tree,n_variables,n_classes,1);
                            end
                            
                            tree = batch_train(tree,train_set,test_set,do_vpruning,do_performance_measuring,do_test_incrementally);
                            %fprintf('\ntree exists? %d',does_tree_exist(tree));
                            tree_exists = 1;
                            current_treetype = 'iti_tree';
                            
                            
                            
                            tag = 'iti-incremental';
                    end
                    %subswitch the options
                    %done building tree
                    
                    %if outfiles were used close them
                    
                    if(inc_test_fp>0)
                        fclose(inc_test_fp);
                    end
                    
                end
                %now we're done so setup for next task
                current_argument = current_argument + 1;
            case 'load_mat_train_fast'
                %loads training data from a .mat file and trains it offline
                %training data must be stored in a matrix named
                %'zip_train_data'.  Training classes must be stored in a
                %cell array called 'zip_train_classes'
                current_data_format = 'MATLAB';
                current_option_string = varargin{current_argument};
                if(((nargin-1) - current_argument)>0)  %make sure the current argument isn't the last one
                    current_argument = current_argument + 1;
                    if(ischar(varargin{current_argument}))  %ensures the following argument is a string
                        input_string = varargin{current_argument};
                        
                        %%%%%%%%%%%%%%%%%%%insert code here %%%%%%%
                        if(~isstruct(tree))
                                tree=get_tree_node(tree,n_variables,n_classes,1);
                            end
                            
                            %tree =
                            %fast_train(tree,train_set,test_set,do_vpruning,do_performance_measuring,do_test_incrementally);
                            input_file = strcat(filestem,'/',input_string);
                            %tree = fast_train_mat(tree,input_file);
                            tree = fast_train_mat(tree,input_string);
                            current_treetype = 'iti_tree';
                            %fprintf('\ntree exists? %d',does_tree_exist(tree));
                            tree_exists = 1;
                            %current_treetype = 'iti_tree';
                            
                            
                            
                            tag = 'iti-fast';
                        
                        %%%%%%%%%%%%%%%%%%%end insert code here %%%
                    end %end ischar(varargin...
                else
                    save datadump_main
                    error('error. no input arguments after ''%s''. saving data.\n',current_option_string);
                end
                
                current_argument = current_argument + 1;
            case 'convert_data_c45_to_mat'  %NOT CHECKED YET!!!
                %loads training data from C4.5 format file, saves & returns
                %the data in the .mat format used here (zip_train_data
                %numeric array, zip_train_classes cell array).
                %this needs 1 argument after - the string filename of the
                %C4.5 format datafile to read.
                fprintf('\ncurrent arg is convert_data_c45_to_mat\n');
                current_data_format = 'MATLAB';
                if(((nargin-1) - current_argument)>0)
                    current_argument = current_argument + 1;
                    if(ischar(varargin{current_argument}))%make sure arg after 'l' is a string
                        train_fname = sprintf('%s',varargin{current_argument});
                        %fname = sprintf('%s/%s/%s.data',DATA_PATH_NAME,filestem,train_fname);
                        fname = sprintf('%s\\%s.data',filestem,train_fname);
                        train_fname_full_name = fname;
                        fp = fopen(fname,'r');
                        if(fp>0)
                            fclose(fp);
                            fprintf('Loading training set from %s ...',fname);
                            %[train_set n_training_insts] = read_instances(fname,train_set,verbose_load_instances,variable_name,n_variables);
                            [zip_train_data n_instances zip_train_classes] = convert_instances_mat_format(fname,verbose_load_instances,n_variables);
                            fprintf('%d loaded\n',n_training_insts);
                        else
                            save datadump_main
                            error('error. unable to open file %s\n',fname);
                        end
                    else
                        save datadump_main
                        error('error. no input arguments after "convert_data_c45_to_mat". saving data and exiting.\n');
                    end
                else
                    fprintf('File name not given after "convert_data_c45_to_mat", no data loaded\n');
                end
                
                current_argument = current_argument + 1;
            case 'make_mat_xval_sets'  %NOT CHECKED YET!!!
                %loads training data passed to function as an input and trains tree offline
                %this needs one numeric arguments after it - the number of
                %cross-validation groups to create.  
                %If the data does not exist in memory as zip_train_data,
                %this option passes a warning and continues.
                current_option_string = varargin{current_argument};
                if(((nargin-1) - current_argument)>0)  %ensure input's there
                    current_argument = current_argument + 1;
                    if(isnumeric(varargin{current_argument}))  %ensures the following argument is a string
                        fprintf('number of cross-validation sets is %d... ',varargin{current_argument});
                        %ensure zip_train_data exists
                        %ensure zip_test_data exists
                        if(exist('zip_train_data','var'))
                            if(exist('zip_test_data','var'))
                                all_data = vertcat(zip_train_data,zip_test_data);
                                all_classes = vertcat(zip_train_classes,zip_test_classes);
                            else
                                all_data = zip_train_data;
                                all_classes = zip_train_classes;
                            end
                            split_xval_groups(all_data,all_classes,varargin{current_argument},filestem)
                        else
                            fprintf('\nWarning (iti): no training data loaded, cannot split into cross-validation sets.');
                        end
                        
                    else
                        save datadump_main
                        error('error. number of cross-validation sets not entered after ''%s''. saving data.\n',current_option_string);
                        
                    end
                    
                else
                    save datadump_main
                    error('error. no input arguments after ''%s''. saving data.\n',current_option_string);
                end
                
                current_argument = current_argument + 1;
            case 'pass_mat_train_fast'
                %loads training data passed to function as an input and trains tree offline
                %this needs TWO arguments after it - train_data and
                %train_classes.  train_data must be a numeric matrix,
                %train_classes a cell array of strings.
                current_option_string = varargin{current_argument};
                if(((nargin-2) - current_argument)>0)  %make sure there are two arguments after the current one
                    current_argument = current_argument + 1;
                    %if(ischar(varargin{current_argument}))  %ensures the following argument is a string
                    if(isnumeric(varargin{current_argument}))  %ensures the following argument is a string
                        fprintf('loading training data %s... ',inputname(current_argument));
                        train_data = varargin{current_argument};
                        [temp_insts temp_attributes] = size(train_data);
                        fprintf('%d instances loaded\n',temp_insts);
                        current_argument = current_argument + 1;
                        if(iscell(varargin{current_argument}))
                            fprintf('loading training data classes %s... ',inputname(current_argument));
                            train_classes = varargin{current_argument};
                            fprintf('done\n');
                            %%%%%%%%%%%%%%%%%%%insert code here %%%%%%%
                            if(~isstruct(tree))
                                tree=get_tree_node(tree,n_variables,n_classes,1);
                                tree_class_counts=get_tree_node(tree,n_variables,n_classes,1);
                                tree_class_counts_tags=get_tree_node(tree,n_variables,n_classes,1);
                                tree_numeric_value_counts=get_tree_node(tree,n_variables,n_classes,1);
                                
                            end
                            
                            %tree = fast_train(tree,train_set,test_set,do_vpruning,do_performance_measuring,do_test_incrementally);
                            %input_file = strcat(filestem,'/',input_string);
                            tree = fast_train_mat_passed(tree,train_data,train_classes);
                            current_treetype = 'iti_tree';
                            %fprintf('\ntree exists? %d',does_tree_exist(tree));
                            tree_exists = 1;
                            %current_treetype = 'iti_tree';
                            
                            
                            
                            tag = 'iti-fast';
                            
                            %%%%%%%%%%%%%%%%%%%end insert code here %%%
                        else
                            %fprintf('error: argument after %s is not a char array of classes, skip training\n',current_option_string);
                            %current_argument
                            fprintf('error: argument %s is not a char array of classes, skip training\n',inputname(current_argument));
                        end
                        
                    else
                        fprintf('error: argument %s is not a numeric array of data, skip training\n',inputname(current_option_string));
                    end %end isnumeric(varargin...
                else
                    save datadump_main
                    error('error. insufficient input arguments after ''%s''. skip training\n',current_option_string);
                end
                
                current_argument = current_argument + 1;
            case 'OLDEX'
                %loads training data from a .mat file and trains it offline
                %in two different trees. automatically determines
                %configurations and determines which tree data should be
                %used for.
                %training data must be stored in a matrix named
                %'zip_train_data'.  Training classes must be stored in a
                %cell array called 'zip_train_classes'
                current_option_string = varargin{current_argument};
                if(((nargin-1) - current_argument)>0)  %make sure the current argument isn't the last one
                    current_argument = current_argument + 1;
                    if(ischar(varargin{current_argument}))  %ensures the following argument is a string
                        input_string = varargin{current_argument};
                        
                        %%%%%%%%%%%%%%%%%%%insert code here %%%%%%%
                        if(~isstruct(tree))
                            tree=get_tree_node(tree,n_variables,n_classes,1);
                            tree_class_counts=get_tree_node(tree,n_variables,n_classes,1);
                            tree_class_counts_tags=get_tree_node(tree,n_variables,n_classes,1);
                            tree_numeric_value_counts=get_tree_node(tree,n_variables,n_classes,1);
                            
                        end
                        
                        tree_oldex_1 = tree;
                        tree_oldex_1_class_counts = tree_class_counts;
                        tree_oldex_1_class_counts_tags = tree_class_counts_tags;
                        tree_oldex_1_numeric_value_counts = tree_numeric_value_counts;
                        
                        tree_oldex_2 = tree;
                        tree_oldex_2_class_counts = tree_class_counts;
                        tree_oldex_2_class_counts_tags = tree_class_counts_tags;
                        tree_oldex_2_numeric_value_counts = tree_numeric_value_counts;
                        
%                         if(~isstruct(tree_oldex_1))
%                             global tree_oldex_1
%                             global tree_oldex_1_class_counts
%                             global tree_oldex_1_class_counts_tags
%                             global tree_oldex_1_numeric_value_counts
%                             tree_oldex_1=get_tree_node(tree,n_variables,n_classes,1);
%                             tree_oldex_1_class_counts=get_tree_node(tree,n_variables,n_classes,1);
%                             tree_oldex_1_class_counts_tags=get_tree_node(tree,n_variables,n_classes,1);
%                             tree_oldex_1_numeric_value_counts=get_tree_node(tree,n_variables,n_classes,1);
%                         end
%                         if(~isstruct(tree_oldex_2))
%                             global tree_oldex_2
%                             global tree_oldex_2_class_counts
%                             global tree_oldex_2_class_counts_tags
%                             global tree_oldex_2_numeric_value_counts
%                             tree_oldex_2=get_tree_node(tree,n_variables,n_classes,1);
%                             tree_oldex_2_class_counts=get_tree_node(tree,n_variables,n_classes,1);
%                             tree_oldex_2_class_counts_tags=get_tree_node(tree,n_variables,n_classes,1);
%                             tree_oldex_2_numeric_value_counts=get_tree_node(tree,n_variables,n_classes,1);
%                         end
                        
                        %tree = fast_train(tree,train_set,test_set,do_vpruning,do_performance_measuring,do_test_incrementally);
                        %input_file = strcat(filestem,'/',input_string);
%                             [tree_oldex_1,tree_oldex_2] = OLDEX(tree,tree_oldex_1,tree_oldex_2,input_file);
                            [tree_oldex_1,tree_oldex_2] = OLDEX(tree,tree_oldex_1,tree_oldex_2,input_string);

                            current_treetype = 'iti_tree_OLDEX';
                            %fprintf('\ntree exists? %d',does_tree_exist(tree));
                            tree_exists = 1;
                            %current_treetype = 'iti_tree';


                            
                            tag = 'iti-OLDEX';
                        
                        %%%%%%%%%%%%%%%%%%%end insert code here %%%
                    end %end ischar(varargin...
                else
                    save datadump_main
                    error('error. no input arguments after ''%s''. saving data.\n',current_option_string);
                end
                
                current_argument = current_argument + 1;
            
            case 'h'
                current_argument = current_argument + 1;
            case 'j'
                current_argument = current_argument + 1;
            case 'l'
                fprintf('\ncurrent arg is l\n');
                current_data_format = 'ITI';
                if(((nargin-1) - current_argument)>0)
                    current_argument = current_argument + 1;
                    if(ischar(varargin{current_argument}))%make sure arg after 'l' is a string
                        train_fname = sprintf('%s',varargin{current_argument});
                        %fname = sprintf('%s/%s/%s.data',DATA_PATH_NAME,filestem,train_fname);
                        fname = sprintf('%s\\%s.data',filestem,train_fname);
                        train_fname_full_name = fname;
                        fp = fopen(fname,'r');
                        if(fp>0)
                            fclose(fp);
                            fprintf('Loading training set from %s ...',fname);
                            [train_set n_training_insts] = read_instances(fname,train_set,verbose_load_instances,variable_name,n_variables);
                            fprintf('%d loaded\n',n_training_insts);
                        else
                            fprintf('Unable to open file %s\nAttempting to open file with .csv extension...\n\n',fname);
                            %fname(sprintf('%s/%s/%s.csv',DATA_PATH_NAME,filestem,train_fname));
                            fname(sprintf('%s\\%s.csv',filestem,train_fname));
                            fp=fopen(fname,'r');
                            if(fp>0)
                                fclose(fp);
                                fprintf('Loading training set from %s ...',fname);
                                [train_set n_training_insts] = read_instances(fname,train_set,verbose_load_instances,n_variables);
                                fprintf('%d loaded\n',n_training_insts);
                            else
                                save datadump_main
                                error('error. unable to open file %s\n',fname);
                            end
                        end
                    else
                        save datadump_main
                        error('error. no input arguments after l. saving data and exiting.\n');
                    end
                else
                    fprintf('File name not given with -l, no data loaded\n');
                end
                current_argument = current_argument + 1;
                
                save datastore_main
            case 'a'
                current_argument = current_argument + 1;
            case 'A'
                current_argument = current_argument + 1;
            case 'B'
                current_argument = current_argument + 1;
            case 'C'
                current_argument = current_argument + 1;
            case 'D'
                current_argument = current_argument + 1;
            case 'c'
                current_argument = current_argument + 1;
            case 'k'
                current_argument = current_argument + 1;
            case 'n'
                current_argument = current_argument + 1;
            case 'L'
                current_argument = current_argument + 1;
            case 'M'
                current_argument = current_argument + 1;
            case 'm'
                current_argument = current_argument + 1;
            case 'I'
                %compute and store the test results instance-by-instance
                %this is not functional yet (2009-0527)
                do_test_incrementally = ~do_test_incrementally; %flip the sign
                if(((nargin-1) - current_argument)>0)
                    current_argument = current_argument + 1;
                    if(ischar(varargin{current_argument}))%make sure arg after 'l' is a string
                        inc_test_fname = varargin{current_argument};
                    else
                        fprintf('Error, inc_test_fname not given after I. Using default: test.inc_test\n');
                        inc_test_fname = 'test';
                    end
                else
                    fprintf('Error. final argument (inc_test name) is missing. Using default: test.inc_test\n');
                    inc_test_fname = 'test';
                end
                
                current_argument = current_argument + 1;
            case 'P'
                current_argument = current_argument + 1;
            case 'p'
                current_argument = current_argument + 1;
            case 'q'
                %load a test set from a C4.5 format datafile located in
                %directory filestem
                %note: can specify a file from a subdirectory in filestem
                %by specifying the directory in the command option, 
                %i.e. 'q','special_test_set/test_set'
                %assumes data filename is in format '*.data'
                fprintf('\ncurrent arg is q\n');
                if(((nargin-1) - current_argument)>0)
                    current_argument = current_argument + 1;
                    if(ischar(varargin{current_argument}))%make sure arg after 'l' is a string
                        test_fname = sprintf('%s',varargin{current_argument});
                        %fname = sprintf('%s/%s/%s.data',DATA_PATH_NAME,filestem,test_fname);
                        fname = sprintf('%s/%s.data',filestem,test_fname);
                        fp = fopen(fname,'r');
                        if(fp>0)
                            fclose(fp);
                            fprintf('Loading testing set from %s ...',fname);
                            [test_set n_testing_insts] = read_instances(fname,test_set,verbose_load_instances,variable_name,n_variables);
                            fprintf('%d loaded\n',n_testing_insts);
                        else
                            fprintf('Unable to open file %s\nAttempting to open file with .csv extension...\n\n',fname);
                            %fname = sprintf('%s/%s/%s.data',DATA_PATH_NAME,filestem,test_fname);
                            fname = sprintf('%s/%s.data',filestem,test_fname);
                            fp=fopen(fname,'r');
                            if(fp>0)
                                fclose(fp);
                                fprintf('Loading testing set from %s ...',fname);
                                [test_set n_testing_insts] = read_instances(fname,test_set,verbose_load_instances,n_variables);
                                fprintf('%d loaded\n',n_testing_insts);
                            else
                                save datadump_main
                                error('error. unable to open file %s\n',fname);
                            end
                        end
                    else
                        save datadump_main
                        error('error. no input arguments after q. saving data and exiting.\n');
                    end
                else
                    fprintf('File name not given with -q, no data loaded\n');
                end
                current_argument = current_argument + 1;
                
                save datastore_main
            case 'load_mat_test_set'
                %loads test data from a .mat file
                %test data must be stored in a matrix named
                %'zip_test_data'.  Test classes must be stored in a
                %cell array called 'zip_test_classes'

                current_option_string = varargin{current_argument};
                if(((nargin-1) - current_argument)>0)  %make sure the current argument isn't the last one
                    current_argument = current_argument + 1;
                    if(ischar(varargin{current_argument}))  %ensures the following argument is a string
                        input_string = varargin{current_argument};
                        
                        %%%%%%%%%%%%%%%%%%%insert code here %%%%%%%
                        input_file = strcat(filestem,'/',input_string);
                        fprintf('\nLoading test set %s...',input_file);
                        
                        %[test_set] = read_test_instances_mat(input_file);
                        [test_set] = read_test_instances_mat(input_string);
                        fprintf('%d loaded\n',n_testing_insts);
                        
                        %%%%%%%%%%%%%%%%%%%end insert code here %%%
                    end %end ischar(varargin...
                else
                    save datadump_main
                    error('error. no input arguments after ''%s''. saving data.\n',current_option_string);
                end
                
                current_argument = current_argument + 1;
            case 'pass_mat_test_set'
                %loads test data passed in varargin, must be followed by
                %two inputs - the numeric test set data, and the cell array
                %of test set classes
                
                current_option_string = varargin{current_argument};
                if(((nargin-2) - current_argument)>0)  %make sure the current argument isn't the last one
                    current_argument = current_argument + 1;
                    if(isnumeric(varargin{current_argument}))  %ensures the following argument is a string
                        fprintf('loading test set data ... ');
                        test_set_mat = varargin{current_argument};
                        [temp_n_testing_insts dummy] = size(test_set_mat);
                        %%%%%%%%%%%%%%%%%%%insert code here %%%%%%%
                        %[test_set] = read_test_instances_mat(input_string);
                        
                        fprintf('%d loaded\n',temp_n_testing_insts);
                        current_argument = current_argument + 1;
                        if(iscell(varargin{current_argument}))
                            n_testing_insts = temp_n_testing_insts;
                            fprintf('loading test set classes ... ');
                            test_classes_mat = varargin{current_argument};
                            
                            test_set = read_test_instances_passed(test_set_mat,test_classes_mat);
                            fprintf('done\n');
                        else
                            fprintf('error: couldn''t load test set classes\n');
                        end
                    else
                        fprintf('error: passed test set data not a numeric matrix\n');
                        %%%%%%%%%%%%%%%%%%%end insert code here %%%
                    end %end ischar(varargin...
                else
                    save datadump_main
                    error('error. no input arguments after ''%s''. saving data.\n',current_option_string);
                end
                
                current_argument = current_argument + 1;
                
            case 'kernel_pass_mat_test_set'
                %loads test data passed in varargin, must be followed by
                %two inputs - the numeric test set data, and the cell array
                %of test set classes
                %kernel-transforms test set according to same kernel as
                %entered for train set
                %NOTE: MUST HAVE PREVIOUSLY USED kernel_pass_mat_train_fast
                
                current_option_string = varargin{current_argument};
                if(((nargin-2) - current_argument)>0)  %make sure the current argument isn't the last one
                    current_argument = current_argument + 1;
                    if(isnumeric(varargin{current_argument}))  %ensures the following argument is a string
                        fprintf('loading test set data ... ');
                        test_set_mat = varargin{current_argument};
                        [temp_n_testing_insts dummy] = size(test_set_mat);
                        %%%%%%%%%%%%%%%%%%%insert code here %%%%%%%
                        %[test_set] = read_test_instances_mat(input_string);
                        
                        fprintf('%d loaded\n',temp_n_testing_insts);
                        current_argument = current_argument + 1;
                        if(iscell(varargin{current_argument}))
                            n_testing_insts = temp_n_testing_insts;
                            fprintf('loading test set classes ... ');
                            test_classes_mat = varargin{current_argument};
                            
                            %transform data using kernel
                            %kernel_type = 'rbf';
                            %c=0.8;
                            %kernel_const = 256*c; %from scholkopf & smola for usps dataset
                            %[kernel_transform_table kernel_transform_table_ix] = init_kernel_transform_table;
                            
                            kernel_transforms = perform_kernel_transforms(kernel_type,kernel_const,test_classes_mat);
                            original_test_classes_mat = test_classes_mat;
                            test_classes_mat = horzcat(original_test_classes_mat,kernel_transforms);
                            
                            test_set = read_test_instances_passed(test_set_mat,test_classes_mat);
                            fprintf('done\n');
                            
                            fprintf('kernel-transforming test set...');
                            
                            
                            fprintf('done.\n');
                        else
                            fprintf('error: couldn''t load test set classes\n');
                        end
                    else
                        fprintf('error: passed test set data not a numeric matrix\n');
                        %%%%%%%%%%%%%%%%%%%end insert code here %%%
                    end %end ischar(varargin...
                else
                    save datadump_main
                    error('error. no input arguments after ''%s''. saving data.\n',current_option_string);
                end
                
                current_argument = current_argument + 1;
            case 'R'
                current_argument = current_argument + 1;
            case 'r'
                %restore a previously saved tree from a .mat file
                %tree variable in file must be named 'tree'
                %doesn't check whether tree is ITI structure 
                %or classregtree object!!
                fprintf('\ncurrent arg is r\n');
                if(((nargin-1) - current_argument)>0)
                    current_argument = current_argument + 1;
                    if(ischar(varargin{current_argument}))%make sure arg after 'r' is a string
                        restore_fname = sprintf('%s',varargin{current_argument});
                        fname = sprintf('%s/%s',filestem,restore_fname);
                        try
                            fprintf('Restoring tree from file %s\n',fname);
                            if(tree_exists)
                                tree_old = tree;
                            end
                            load(fname,'tree','current_treetype','n_classes');
                            tree_exists = 1;
                        catch
                            fprintf('error, unable to load file %s\n',fname);
                            save datadump_main
                        end
                    else
                        save datadump_main
                        error('error. unable to open file %s\n',fname);
                    end
                    
                else
                    save datadump_main
                    error('error. no input arguments after r. saving data.\n');
                end
                
                
                
                current_argument = current_argument + 1;
            case 's'
                %save the tree (only!) in a .mat file
                %note: matlab will overwrite file if it exists, without
                %confirmation
                fprintf('\ncurrent arg is s\n');
                if(((nargin-1) - current_argument)>0)
                    current_argument = current_argument + 1;
                    if(ischar(varargin{current_argument}))%make sure arg after 'r' is a string
                        save_fname = sprintf('%s',varargin{current_argument});
                        fname = sprintf('%s/%s/%s',DATA_PATH_NAME,filestem,save_fname);
                        try
                            fprintf('Saving tree (only!) to file %s\n',fname);
                            save(fname,'tree','current_inst_tag','filestem');
                        catch
                            fprintf('error, unable to save to file %s\n',fname);
                            save datadump_main
                        end
                    else
                        save datadump_main
                        error('error. unable to save to filename %s\n',fname);
                    end
                    
                else
                    save datadump_main
                    error('error. no input arguments after ''s''. saving data.\n');
                end
                
                current_argument = current_argument + 1;
            case 't'
                %test tree using previously loaded test data
                %display results to screen
                if(tree_exists)
                    %fprintf('display test results here\n');
                    if(~strcmp(current_treetype,'iti_tree'))
                        tree = iti_tree;
                        current_treetype = 'iti_tree';
                    end
                    
                    if(n_testing_insts)
                        clear class_name_test  %clear everything in case we're running multiple tests during a single session
                        clear class_name_true_test
                        class_num_test = zeros(n_testing_insts,1);
                        height_test = zeros(n_testing_insts,1);
                        
                        for i=1:n_testing_insts
                            [class_num_test(i,1) height_test(i,1)] = tree_test(tree,1,test_set(i,:),0);
                            class_name_test{i,1}=all_classes{class_num_test(i,1)};
                            class_name_true_test{i,1}=test_set(i,1).classname;
                        end
                        
                        results=strcmp(class_name_test,class_name_true_test);
                        
                        test_set_accuracy = mean(results);
                        accuracy = 100*test_set_accuracy;
                        
                        %something is off with xtests, this result is a
                        %little high for pima
                        xpath = mean(height_test);  %this is the same as sum(height_test)/n_testing_insts;
                    else
                        accuracy = -1;
                        xpath = 0;
                    end
                    
                    %fprintf('accuracy=%3.3f',accuracy);
                    
                    n_leaves = count_leaves(tree,1,0);
                    
                    %                     [n_insts,n_tests,n_leaves] = count_instances_tests_leaves(tree,tree,n_insts,n_tests,n_leaves,TRUE);
                    %                     if(n_insts)
                    %                         xpath = n_tests/n_insts;
                    %                     else
                    %                         xpath = 0;
                    %                     end
                    %
                    
                    
                    fprintf('Leaves: %d, xtests: %f, instances: %d',n_leaves,xpath,n_training_insts);
                    if(accuracy>=0)
                        fprintf(', accuracy: %f\n',accuracy);
                    end
                    %                     fprintf(', cpu: %f, transps: %f',total_cpu,total_transpositions);
                    
                else
                    fprintf('no tree to test\n');
                end
                current_argument = current_argument + 1;
            case 'T'
                %tests existing tree using previously loaded test set, and 
                %appends the results to a file named 'test.results', 
                %located in the root directory
                if(((nargin-1) - current_argument)>0)
                    current_argument = current_argument + 1;
                    if(ischar(varargin{current_argument}))%make sure arg after 'T' is a string
                        test_fname = sprintf('%s',varargin{current_argument});
                        %fname = sprintf('%s\\test.results',filestem);
                        fname = sprintf('test.results'); %NOTE: this saves test.results in whatever directory you've navigated to!!!
                        %try
                        fprintf('Appending test results to file %s\n',fname);
                        
                        %%%%%%%%%%%%%%%perform the actual tests
                        if(tree_exists)
                            %fprintf('display test results here\n');
                            
                            if(exist('current_treetype','var'))
                                if(~strcmp(current_treetype,'iti_tree'))
                                    tree = iti_tree;
                                    current_treetype = 'iti_tree';
                                end
                            else
                                current_treetype = 'iti_tree';
                            end
                            
                            if(n_testing_insts)
                                clear class_name_test  %clear everything in case we're running multiple tests during a single session
                                clear class_name_true_test
                                class_num_test = zeros(n_testing_insts,1);
                                height_test = zeros(n_testing_insts,1);
                                
                                for i=1:n_testing_insts
                                    [class_num_test(i,1) height_test(i,1)] = tree_test(tree,1,test_set(i,:),0);
                                    class_name_test{i,1}=all_classes{class_num_test(i,1)};
                                    class_name_true_test{i,1}=test_set(i,1).classname;
                                end
                                
                                results=strcmp(class_name_test,class_name_true_test);
                                
                                test_set_accuracy = mean(results);
                                accuracy = 100*test_set_accuracy;
                                
                                %something is off with xtests, this result is a
                                %little high for pima
                                %...is xtests computed using the
                                %experimentally observed test_set tests or
                                %the actual branch heights?
                                
                                xpath = mean(height_test);  %this is the same as sum(height_test)/n_testing_insts;
                                %                     [n_insts,n_tests,n_leaves] = count_instances_tests_leaves(tree,tree,n_insts,n_tests,n_leaves,TRUE);
                                %                     if(n_insts)
                                %                         xpath = n_tests/n_insts;
                                %                     else
                                %                         xpath = 0;
                                %                     end
                                %
                                
                            else
                                accuracy = -1;
                                xpath = 0;
                            end
                            
                            %fprintf('accuracy=%3.3f',accuracy);
                            
                            n_leaves = count_leaves(tree,1,0);
                            
                            
                            
                            fprintf('Leaves: %d, xtests: %f, instances: %d',n_leaves,xpath,n_training_insts);
                            if(accuracy>=0)
                                fprintf(', accuracy: %f',accuracy);
                            end
                            fprintf(', total_cpu: %f\n',total_cpu);
                            %                     fprintf(', cpu: %f, transps: %f',total_cpu,total_transpositions);
                            %%%%%%%%%%%%%%%done perform the actual tests
                            
                            
                            %save results to file
                            fprintf('Writing test results to file %s ...',fname);
                            
                            fid_test = fopen(fname,'a+');
                            % temp2_name = pwd;
                            % temp3_name = horzcat(temp2_name,'\\test.results');
                            %fid_test = fopen('C:\\Users\\Brooks\\Documents\\MATLAB\\gaussian_irdt\\pima\\rbf_xval1\test.results','a+');
                            %fid_test = fopen(temp3_name,'a+');
                            
                            if(fid_test)
                                fprintf(fid_test,'%s\t%d\t%d\t%d\t%f\t%f\n',test_fname,n_leaves,xpath,n_training_insts,accuracy,total_cpu);
                                
                            end
                            
                            fclose(fid_test);
                            fprintf('done\n');
                            
                            %%%%%%%%%%%%%done saving results
                        else
                            fprintf('no tree to test\n');
                        end
                        
                        
                        
                        %                         catch
                        %                             fprintf('error, unable to save to file %s\n',fname);
                        %                             save datadump_main
                        %                         end
                    else
                        save datadump_main
                        error('error. unable to save to filename %s\n',fname);
                    end
                    
                else
                    save datadump_main
                    error('error. no input arguments after ''T''. saving data.\n');
                end
                current_argument = current_argument + 1;
                case 'LOAD_SAVED'
                    %loads all variables from a saved file, i.e. a datadump
                    %file.  filename string follows argument.
                    if(((nargin-1) - current_argument)>0)
                        current_argument = current_argument + 1;
                        if(ischar(varargin{current_argument}))%make sure arg after 'T' is a string
                            test_fname = sprintf('%s',varargin{current_argument});
                            
                            load(test_fname)
                        else
                            save datadump_main
                            error('error. unable to load filename %s.  saving data.\n',fname);
                        end
                        
                    else
                        save datadump_main
                        error('error. no input arguments after ''LOAD_SAVED''. saving data.\n');
                    end
                    current_argument = current_argument + 1;
                    
                 case 'T_OLDEX'
                %tests existing tree using previously loaded test set, and 
                %appends the results to a file named 'test.results', 
                %located in the root directory
                if(((nargin-1) - current_argument)>0)
                    current_argument = current_argument + 1;
                    if(ischar(varargin{current_argument}))%make sure arg after 'T' is a string
                        test_fname = sprintf('%s',varargin{current_argument});
                        %fname = sprintf('%s\\test.results',filestem);
                        fname = sprintf('test.results'); %NOTE: this saves test.results in whatever directory you've navigated to!!!
                        %try
                        fprintf('Appending test results to file %s\n',fname);
                        
                        %%%%%%%%%%%%%%%perform the actual tests
                        if(tree_exists)
                            %fprintf('display test results here\n');
%                             if(~strcmp(current_treetype,'iti_OLDEX'))
% %                                 tree = iti_tree;
% %                                 current_treetype = 'iti_tree';
%                                 error('error. tree type not OLDEX.\n');
%                             end
                            
                            if(n_testing_insts)
                                
                                %%%test tree_oldex_1
                                
                                clear class_name_test  %clear everything in case we're running multiple tests during a single session
                                clear class_name_true_test
                                class_num_test = zeros(n_testing_insts,1);
                                height_test = zeros(n_testing_insts,1);
                                
                                for i=1:n_testing_insts
                                    [class_num_test(i,1) height_test(i,1)] = tree_test(tree_oldex_1,1,test_set(i,:),0);
                                    class_name_test{i,1}=all_classes{class_num_test(i,1)};
                                    class_name_true_test{i,1}=test_set(i,1).classname;
                                end
                                
                                results=strcmp(class_name_test,class_name_true_test);
                                
                                test_set_accuracy = mean(results);
                                accuracy = 100*test_set_accuracy;
                                
                                %something is off with xtests, this result is a
                                %little high for pima
                                %...is xtests computed using the
                                %experimentally observed test_set tests or
                                %the actual branch heights?
                                
                                xpath = mean(height_test);  %this is the same as sum(height_test)/n_testing_insts;
                                %                     [n_insts,n_tests,n_leaves] = count_instances_tests_leaves(tree,tree,n_insts,n_tests,n_leaves,TRUE);
                                %                     if(n_insts)
                                %                         xpath = n_tests/n_insts;
                                %                     else
                                %                         xpath = 0;
                                %                     end
                                %
                                
                            else
                                accuracy = -1;
                                xpath = 0;
                            end
                            
                            %fprintf('accuracy=%3.3f',accuracy);
                            
                            n_leaves = count_leaves(tree,1,0);
                            
                            
                            
                            fprintf('Leaves: %d, xtests: %f, instances: %d',n_leaves,xpath,n_training_insts);
                            if(accuracy>=0)
                                fprintf(', accuracy: %f',accuracy);
                            end
                            fprintf(', total_cpu: %f\n',total_cpu);
                            %                     fprintf(', cpu: %f, transps: %f',total_cpu,total_transpositions);
                            %%%%%%%%%%%%%%%done perform the actual tests
                            
                            
                            %save results to file
                            fprintf('Writing test results to file %s ...',fname);
                            
                            fid_test = fopen(fname,'a+');
                            % temp2_name = pwd;
                            % temp3_name = horzcat(temp2_name,'\\test.results');
                            %fid_test = fopen('C:\\Users\\Brooks\\Documents\\MATLAB\\gaussian_irdt\\pima\\rbf_xval1\test.results','a+');
                            %fid_test = fopen(temp3_name,'a+');
                            
                            if(fid_test)
                                fprintf(fid_test,'%s\t%d\t%d\t%d\t%f\t%f\n',strcat(test_fname,'_tree_oldex_1'),n_leaves,xpath,n_training_insts,accuracy,total_cpu);
                                
                            end
                            
                            fclose(fid_test);
                            fprintf('done\n');
                            
                            %%%test tree_oldex_2
                            if(n_testing_insts)
                                
                                
                                clear class_name_test  %clear everything in case we're running multiple tests during a single session
                                clear class_name_true_test
                                class_num_test = zeros(n_testing_insts,1);
                                height_test = zeros(n_testing_insts,1);
                                
                                for i=1:n_testing_insts
                                    [class_num_test(i,1) height_test(i,1)] = tree_test(tree_oldex_2,1,test_set(i,:),0);
                                    class_name_test{i,1}=all_classes{class_num_test(i,1)};
                                    class_name_true_test{i,1}=test_set(i,1).classname;
                                end
                                
                                results=strcmp(class_name_test,class_name_true_test);
                                
                                test_set_accuracy = mean(results);
                                accuracy = 100*test_set_accuracy;
                                
                                %something is off with xtests, this result is a
                                %little high for pima
                                %...is xtests computed using the
                                %experimentally observed test_set tests or
                                %the actual branch heights?
                                
                                xpath = mean(height_test);  %this is the same as sum(height_test)/n_testing_insts;
                                %                     [n_insts,n_tests,n_leaves] = count_instances_tests_leaves(tree,tree,n_insts,n_tests,n_leaves,TRUE);
                                %                     if(n_insts)
                                %                         xpath = n_tests/n_insts;
                                %                     else
                                %                         xpath = 0;
                                %                     end
                                %
                                
                            else
                                accuracy = -1;
                                xpath = 0;
                            end
                            
                            %fprintf('accuracy=%3.3f',accuracy);
                            
                            n_leaves = count_leaves(tree,1,0);
                            
                            
                            
                            fprintf('Leaves: %d, xtests: %f, instances: %d',n_leaves,xpath,n_training_insts);
                            if(accuracy>=0)
                                fprintf(', accuracy: %f',accuracy);
                            end
                            fprintf(', total_cpu: %f\n',total_cpu);
                            %                     fprintf(', cpu: %f, transps: %f',total_cpu,total_transpositions);
                            %%%%%%%%%%%%%%%done perform the actual tests
                            
                            
                            %save results to file
                            fprintf('Writing test results to file %s ...',fname);
                            
                            fid_test = fopen(fname,'a+');
                            % temp2_name = pwd;
                            % temp3_name = horzcat(temp2_name,'\\test.results');
                            %fid_test = fopen('C:\\Users\\Brooks\\Documents\\MATLAB\\gaussian_irdt\\pima\\rbf_xval1\test.results','a+');
                            %fid_test = fopen(temp3_name,'a+');
                            
                            if(fid_test)
                                fprintf(fid_test,'%s\t%d\t%d\t%d\t%f\t%f\n',strcat(test_fname,'_tree_oldex_2'),n_leaves,xpath,n_training_insts,accuracy,total_cpu);
                                
                            end
                            
                            fclose(fid_test);
                            fprintf('done\n');
                            
                            %%%%%%%%%%%%%done saving results
                        else
                            fprintf('no tree to test\n');
                        end
                        
                        
                        
                        %                         catch
                        %                             fprintf('error, unable to save to file %s\n',fname);
                        %                             save datadump_main
                        %                         end
                    else
                        save datadump_main
                        error('error. unable to save to filename %s\n',fname);
                    end
                    
                else
                    save datadump_main
                    error('error. no input arguments after ''T''. saving data.\n');
                end
                current_argument = current_argument + 1;
            case 'u'
                current_argument = current_argument + 1;
            case 'v'
                current_argument = current_argument + 1;
            case 'W'
                current_argument = current_argument + 1;
            case 'w'
                current_argument = current_argument + 1;
            case 'x'
                current_argument = current_argument + 1;
            case 'y'
                current_argument = current_argument + 1;
            case 'b'
                current_argument = current_argument + 1;
            case 'N'
                current_argument = current_argument + 1;
            case 'V'
                current_argument = current_argument + 1;
            case 'o'
                current_argument = current_argument + 1;
            case 'F'
                %converts existing tree to classregtree format
                %stores previous tree as iti_tree
                %requires Statistics Toolbox V7.0 (matlab R2008b)
                fprintf('Converting ITI tree to classregtree object\n');
                
                if(~strcmp(current_treetype,'iti_tree'))
                    tree = iti_tree;
                    current_treetype = 'iti_tree';
                end
                
                tree = cleanup_for_classregtree(tree);
                iti_carttree = convert_iti_to_classregtree(tree);
                iti_classregtree = classregtree(iti_carttree);
                current_argument = current_argument + 1;
                
            case 'G'
                %converts iti-format tree to classregtree format, and 
                %displays the tree using a graphical viewer
                %requires Statistics Toolbox V7.0 (matlab R2008b)
                if(tree_exists)
                if(~strcmp(current_treetype,'iti_tree'))
                    tree = iti_tree;
                    current_treetype = 'iti_tree';
                end
                
                fprintf('converting and viewing ITI tree using classregtree viewer\n');
                tree = cleanup_for_classregtree(tree);
                iti_carttree = convert_iti_to_classregtree(tree);
                iti_classregtree = classregtree(iti_carttree);
                view(iti_classregtree)
                else
                    fprintf('No tree to display\n');
                end
                current_argument = current_argument + 1;
            case 'SHOW_OLDEX_TREES'
                %converts iti-format tree to classregtree format, and
                %displays the tree using a graphical viewer
                %requires Statistics Toolbox V7.0 (matlab R2008b)
                if(tree_exists)
                    if(~strcmp(current_treetype,'iti_OLDEX'))
                        %                         tree = iti_tree;
                        %                         current_treetype = 'iti_tree';
                        fprintf('converting and viewing ITI trees using classregtree viewer\n');
                        
                        fprintf('saving data prior to conversion for display...\n');
                        save OLDEX_prior_to_display
                        tree_oldex_1 = cleanup_for_classregtree(tree_oldex_1);
                        iti_carttree = convert_iti_to_classregtree(tree_oldex_1);
                        iti_classregtree = classregtree(iti_carttree);
                        view(iti_classregtree)
                        
                        tree_oldex_2 = cleanup_for_classregtree(tree_oldex_2);
                        iti_carttree = convert_iti_to_classregtree(tree_oldex_2);
                        iti_classregtree = classregtree(iti_carttree);
                        view(iti_classregtree)
                    else
                        error('error. current treetype is not OLDEX. Skipping ''Show OLDEX''.\n');
                    end
                    

                else
                    fprintf('No tree to display\n');
                end
                current_argument = current_argument + 1;
            case 'z'
                fprintf('\n will enter the manual later\n');
                
                fprintf('''load_mat_train_fast''\n');
                fprintf('\tloads training data from a .mat file and trains it offline\n');
                fprintf('\ttraining data must be stored in a matrix named\n');
                fprintf('\t''zip_train_data''.  Training classes must be stored in a\n');
                fprintf('\tcell array called ''zip_train_classes\n''');

                current_argument = current_argument + 1;
            case 'Z'
                fprintf('\n will enter the keystroke list later\n');
                current_argument = current_argument + 1;
            case 'output_type'
                %set the format of the tree output by the iti program
                %based on user input.  
                %NOTE: when it assigns the tree type, it doesn't check
                %whether the tree is a valid member of that type
                if(((nargin-1) - current_argument)>0)
                    current_argument = current_argument + 1;
                    if(ischar(varargin{current_argument}))
                        if(strcmp(varargin{current_argument},'classregtree'))
                            fprintf('output type is set to classregtree\n');
                            if(~strcmp(current_treetype,'iti_tree'))
                                tree = iti_tree;
                                current_treetype = 'iti_tree';
                            end
                            
                            iti_tree = tree;
                            tree = cleanup_for_classregtree(tree);
                            iti_carttree = convert_iti_to_classregtree(tree);
                            iti_classregtree = classregtree(iti_carttree);
                            tree = iti_classregtree;
                            current_treetype = 'classregtree';
                        end
                    end
                else
                    save datadump_main
                    error('error. no input arguments after ''output_type''. saving data.\n');
                end
                
                
                current_argument = current_argument + 1;
                
            case 'names_name'
                %reset the names settings using a different names file
                %this may affect the class names, number of attributes, and
                %attribute names.
                current_option_string = varargin{current_argument};
                if(((nargin-1) - current_argument)>0)  %make sure the current argument isn't the last one
                    current_argument = current_argument + 1;
                    if(ischar(varargin{current_argument}))  %ensures the following argument is a string
                        input_string = varargin{current_argument};
                        %%%%%%%%%%%%%%%%%%%insert code here %%%%%%%
                        
                        fname = sprintf('%s/%s',filestem,input_string);
                        
                        fp=fopen(fname,'r');
                        
                        %verbose_load_instances = 1;
                        try
                            if (fp)
                                fclose(fp);
                                fprintf('Loading variable names from names file %s...',fname);
                                [variable_name n_variables all_classes] = read_variable_names(fname,verbose_load_instances);
                                [dummy n_classes] = size(all_classes);  %n_classes directly from file
                                fprintf(' %d loaded\n',n_variables);
                                
                                if(~isstruct(tree))
                                    tree= get_tree_node(tree,n_variables,n_classes,1);
                                else
                                    fprintf('Tree already exists, renaming it to tree_old and initializing a new tree\n');
                                    tree_old = tree;
                                    tree= get_tree_node(tree,n_variables,n_classes,1);
                                end
                                
                                tree(1) = load_classnames_into_tree(tree(1),all_classes);
                                for i=1:n_variables
                                    tree(1).variables(i).variable_key = variable_name{i,1};
                                end
                                
                                tree(1).min_insts_second_majority = min_insts_second_majority;
                                
                            else
                                error('Unable to open names file %s, ignoring request\n',fname);
                            end
                        catch
                            error('Problem opening names file %s (file might be absent from directory %s\n',fname,filestem);
                        end
                        %%%%%%%%%%%%%%%%%%%end insert code here %%%%%
                    end %end ischar(varargin...
                else
                    save datadump_main
                    error('error. no input arguments after ''%s''. saving data.\n',current_option_string);
                end
                
                current_argument = current_argument + 1;
                
            case 'kernel'
                %setup tree for kernel-augmented attribute space
                %if a tree already exists, a new one will be created and
                %the number of attributes will be adjusted (in the future
                %this won't be necessary)
                current_option_string = varargin{current_argument};
                if(((nargin-1) - current_argument)>0)  %make sure the current argument isn't the last one
                                     current_argument = current_argument + 1;
                                     if(ischar(varargin{current_argument}))  %ensures the following argument is a string
                                         input_string = varargin{current_argument};
                                         %%%%%%%%%%%%%%%%%%%insert code here %%%%%%%
                                         
                                         kernel_type = input_string;
                                         
                                         %get attribute names
                                         [variable_name n_variables] = get_new_kernel_names(kernel_type,variable_name,n_variables);
                                         %number of classes doesn't change
                                         
                                         %init tree
                                         if(~isstruct(tree))
                                             tree= get_tree_node(tree,n_variables,n_classes,1);
                                         else
                                             fprintf('Tree already exists, renaming it to tree_old and initializing a new tree\n');
                                             tree_old = tree;
                                             tree= get_tree_node(tree,n_variables,n_classes,1);
                                         end
                                         
                                         tree(1) = load_classnames_into_tree(tree(1),all_classes);
                                         for i=1:n_variables
                                             tree(1).variables(i).variable_key = variable_name{i,1};
                                         end
                                         
                                         tree(1).min_insts_second_majority = min_insts_second_majority;
                                         
                                         %%%%%%%%%%%%%%%%%%%end insert code here %%%%%
                                     end %end ischar(varargin...
                else
                    save datadump_main
                    error('error. no input arguments after ''%s''. saving data.\n',current_option_string);
                end
                
                current_argument = current_argument + 1;                
            case 'kernel_pass_mat_train_fast' 
% % % % %                %loads training data passed to function as an input,
% % % % %                %augment data with kernel attributes, and train tree offline
% % % % %                 %this needs FOUR arguments after it - kernel_type, const, train_data,
% % % % %                 %train_classes.  train_data must be a numeric matrix,
% % % % %                 %train_classes a cell array of strings.
% % % % %                 current_option_string = varargin{current_argument};
% % % % %                 if(((nargin-2) - current_argument)>0)  %make sure there are two arguments after the current one

%loads training data passed to function as an input and trains tree offline
                %this needs TWO arguments after it - train_data and
                %train_classes.  train_data must be a numeric matrix,
                %train_classes a cell array of strings.
                current_option_string = varargin{current_argument};
                if(((nargin-4) - current_argument)>0)  %make sure there are four arguments after the current one
                    current_argument = current_argument + 1;
                    if(ischar(varargin{current_argument}))
                        kernel_type = varargin{current_argument};
                        current_argument = current_argument + 1;
                        if(isnumeric(varargin{current_argument}))
                            kernel_const = varargin{current_argument};
                            current_argument = current_argument + 1;
                            %if(ischar(varargin{current_argument}))  %ensures the following argument is a string
                            if(isnumeric(varargin{current_argument}))  %ensures the following argument is a string
                                fprintf('loading training data %s... ',inputname(current_argument));
                                train_data = varargin{current_argument};
                                [temp_insts temp_attributes] = size(train_data);
                                fprintf('%d instances loaded\n',temp_insts);
                                current_argument = current_argument + 1;
                                if(iscell(varargin{current_argument}))
                                    fprintf('loading training data classes %s... ',inputname(current_argument));
                                    train_classes = varargin{current_argument};
                                    fprintf('done\n');
                                    %%%%%%%%%%%%%%%%%%%insert code here %%%%%%%
                                    
                                    %transform data using kernel
                                    fprintf('performing kernel transformation on training data...');
                                    
                                    %                             kernel_type = 'rbf';
                                    %                             c=0.8;
                                    %                             kernel_const = 256*c; %from scholkopf & smola for usps dataset
                                    %[kernel_transform_table kernel_transform_table_ix] = init_kernel_transform_table;
                                    kernel_transforms = perform_kernel_transforms(kernel_type,kernel_const,train_data);
                                    save datadump
                                    kernelaug_train_data = horzcat(train_data,kernel_transforms);
                                    
                                    %modify n_variables and their names
                                    n_variables_original = n_variables;
                                    variable_name_original = variable_name;
                                    
                                    [variable_name n_variables] = get_new_kernel_names(kernel_type,variable_name,n_variables);

                                    %init tree
                                    if(~isstruct(tree))
                                        tree=get_tree_node(tree,n_variables,n_classes,1);
                                        tree_class_counts=get_tree_node(tree,n_variables,n_classes,1);
                                        tree_class_counts_tags=get_tree_node(tree,n_variables,n_classes,1);
                                        tree_numeric_value_counts=get_tree_node(tree,n_variables,n_classes,1);
                                    else
                                        tree_old = tree;
                                        
                                        tree=get_tree_node(tree,n_variables,n_classes,1);
                                        tree_class_counts=get_tree_node(tree,n_variables,n_classes,1);
                                        tree_class_counts_tags=get_tree_node(tree,n_variables,n_classes,1);
                                        tree_numeric_value_counts=get_tree_node(tree,n_variables,n_classes,1);
                                    end
                                    
                                    fprintf('new number of variables = %d...',n_variables);
                                    
                                    tree(1) = load_classnames_into_tree(tree(1),all_classes);
                                    for i=1:n_variables
                                        tree(1).variables(i).variable_key = variable_name{i,1};
                                    end
                                    
                                    tree(1).min_insts_second_majority = min_insts_second_majority;
                                    
                                    fprintf('done.\n');
                                    
                                    %tree = fast_train(tree,train_set,test_set,do_vpruning,do_performance_measuring,do_test_incrementally);
                                    %input_file = strcat(filestem,'/',input_string);
                                    tree = fast_train_mat_passed(tree,train_data,train_classes);
                                    current_treetype = 'iti_tree';
                                    %fprintf('\ntree exists? %d',does_tree_exist(tree));
                                    tree_exists = 1;
                                    %current_treetype = 'iti_tree';
                                    
                                    
                                    
                                    tag = 'iti-fast-kernel';
                                    
                                    %%%%%%%%%%%%%%%%%%%end insert code here %%%
                                else
                                    %fprintf('error: argument after %s is not a char array of classes, skip training\n',current_option_string);
                                    %current_argument
                                    fprintf('error: argument %s is not a char array of classes, skip training\n',inputname(current_argument));
                                end
                                
                            else
                                fprintf('error: argument %s is not a numeric array of data, skip training\n',inputname(current_option_string));
                            end %end isnumeric(varargin...
                        else
                            save datadump_main
                            error('error. ''%s'' is not a numeric value for kernel constant. skip training\n',current_option_string);
                        end
                    else
                        save datadump_main
                        error('error.  ''%s'' is not a string containing a kernel type. skip training\n',current_option_string);
                    end
                else
                    save datadump_main
                    error('error. insufficient input arguments after ''%s''. skip training\n',current_option_string);
                end
                
                current_argument = current_argument + 1;
                
            otherwise %default case
                
                if(ischar(varargin{current_argument}))
                    fprintf('invalid input argument %s\n',varargin{current_argument});
                elseif(isnumeric(varargin{current_argument}))
                    fprintf('invalid input argument %f\n',varargin{current_argument});
                else
                    fprintf('invalid input argument %d is of unknown type.\n',(current_argument + 1));
                end
                current_argument = current_argument + 1;
        end
        
        
        %repeat
    end
end

fprintf('\nEnding session, saving session data as ''datastore_main.mat''\n');
save datastore_main