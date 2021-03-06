%function [tree_oldex_1,tree_oldex_2] = OLDEX(tree,tree_oldex_1,tree_oldex_2,filename)
function [tree_oldex_1,tree_oldex_2] = OLDEX(filename)

%use OLDEX to fill two different trees with appropriate data
%author: J. Brooks Zurn
%inputs:
%tree1,tree2: pre-initialized but empty trees
%filename: file containing zip_train_data and zip_train_classes
%outputs:
%tree1,tree2: filled and restructured trees

global total_cpu

global n_variables
global n_OLDEX_variables

%globalize the basic tree structures
global tree_class_counts
global tree_class_counts_tags
global tree_numeric_value_counts

%globalize the oldex tree structures
global tree_oldex_1_class_counts
global tree_oldex_1_class_counts_tags
global tree_oldex_1_numeric_value_counts

global tree_oldex_2_class_counts
global tree_oldex_2_class_counts_tags
global tree_oldex_2_numeric_value_counts

%initialize tree structures if they doesn't exist
tree = load_names(filename);
tree_oldex_1 = load_names(filename);
tree_oldex_2 = load_names(filename);

begin_cpu = tic;

%load data
load(filename,'zip_train_data','zip_train_classes');
% data = zip_train_data;
% classes = zip_train_classes;

%figure out which data belongs with which tree
nan_rows = find_nan_rows(zip_train_data);
nan_ix = find(nan_rows);
non_nan_rows = ~nan_rows;
non_nan_ix = find(~nan_rows);

%init trees

%%%% tree1

%send first set of non-NaN data to tree
[nan_rows nan_cols] = size(nan_ix);
if (nan_rows>0)
    data1 = zip_train_data(1:(nan_ix(1,1)-1),:);
    classes1 = zip_train_classes(1:(nan_ix(1,1)-1),:);
    tree = quick_load_mat_passed(tree,data1,classes1);
    tree = get_node_class(tree,1);
    
    %copy current tag info to tree 1 structs
    tree_oldex_1 = tree;
    tree_oldex_1_class_counts = tree_class_counts;
    tree_oldex_1_class_counts_tags = tree_class_counts_tags;
    tree_oldex_1_numeric_value_counts = tree_numeric_value_counts;
end

%%%% tree2


%init second tree based on current (first) tree

tree_oldex_2 = tree;
tree_oldex_2_class_counts = tree_class_counts;
tree_oldex_2_class_counts_tags = tree_class_counts_tags;
tree_oldex_2_numeric_value_counts = tree_numeric_value_counts;

%figure out which attributes are missing
nan_cols = find_nan_rows(zip_train_data');
nan_cols_ix = find(nan_cols);

%virtually prune missing attributes from new tree by removing before they
%are used
%remove missing attributes from new tree settings
%set value counts to zeros for those attributes (columns)
[num_nan_atts dummy] = size(nan_cols_ix);

for i=1:num_nan_atts
    [tree_oldex_2,tree_oldex_2_class_counts,tree_oldex_2_class_counts_tags]=clear_counts_this_value(nan_cols_ix(i,1),tree_oldex_2,tree_oldex_2_class_counts,tree_oldex_2_class_counts_tags);
end



%incorporate all new missing-attribute data into new tree
% data2 = zip_train_data(nan_ix,:);
% classes2 = zip_train_classes(nan_ix,:);

[nan_rows dummy] = size(nan_ix);
if (nan_rows>0)
    
    data2 = zip_train_data(nan_rows,:);
    classes2 = zip_train_classes(nan_rows,:);
    tree = tree_oldex_2;
    tree_class_counts = tree_oldex_2_class_counts;
    tree_class_counts_tags = tree_oldex_2_class_counts_tags;
    tree_numeric_value_counts = tree_oldex_2_numeric_value_counts;
    
    n_variables_old = n_variables;
    n_variables_new = n_variables - num_nan_atts; %this only valid b/c only end attributes are removed
    n_variables = n_variables_new;
    
    tree = quick_load_mat_passed(tree,data2,classes2);
    tree = get_node_class(tree,1);
    
    %store and reset variables
    tree_oldex_2 = tree;
    tree_oldex_2_class_counts = tree_class_counts;
    tree_oldex_2_class_counts_tags = tree_class_counts_tags;
    tree_oldex_2_numeric_value_counts = tree_numeric_value_counts;
    n_variables = n_variables_old;
end
%now incorporate all non-missing-attribute data into original tree
%reset tree1 as current tree
tree = tree_oldex_1;
tree_class_counts = tree_oldex_1_class_counts;
tree_class_counts_tags = tree_oldex_1_class_counts_tags;
tree_numeric_value_counts = tree_oldex_1_numeric_value_counts;

%incrementally update current tree
%actually, just rebuild using all non-missing-attribute data
%nan_rows = find_nan_rows(zip_train_data);

data3 = zip_train_data(non_nan_rows,:);
classes3 = zip_train_classes(non_nan_rows,:);
tree = quick_load_mat_passed(tree,data3,classes3);
tree = get_node_class(tree,1);

tree_oldex_1 = tree;
tree_oldex_1_class_counts = tree_class_counts;
tree_oldex_1_class_counts_tags = tree_class_counts_tags;
tree_oldex_1_numeric_value_counts = tree_numeric_value_counts;


%backup
save('oldex_out.mat', ...
    'tree_oldex_1',...
    'tree_oldex_1_class_counts',...
    'tree_oldex_1_class_counts_tags',...
    'tree_oldex_1_numeric_value_counts',...
    'tree_oldex_2',...
    'tree_oldex_2_class_counts',...
    'tree_oldex_2_class_counts_tags',...
    'tree_oldex_2_numeric_value_counts');
%end backup

% % % % %restructure loaded trees
% % % % %start with tree1
% % % % fprintf('\nSplitting first OLDEX tree...\n');
% % % % tree = split_node_if_impure(tree,1);
% % % % fprintf('\nRestructuring first OLDEX tree...\n');
% % % % tree = ensure_best_variable(tree,1);
% % % % 
% % % % %move to tree1
% % % % tree_oldex_1 = tree;
% % % % tree_oldex_1_class_counts = tree_class_counts;
% % % % tree_oldex_1_class_counts_tags = tree_class_counts_tags;
% % % % tree_oldex_1_numeric_value_counts = tree_numeric_value_counts;
% % % % 
% % % % %now do tree2
% % % % %move data to tree
% % % % tree = tree_oldex_2;
% % % % tree_class_counts = tree_oldex_2_class_counts;
% % % % tree_class_counts_tags = tree_oldex_2_class_counts_tags;
% % % % tree_numeric_value_counts = tree_oldex_2_numeric_value_counts;
% % % % n_variables = n_variables_new;
% % % % 
% % % % %restructure tree2
% % % % fprintf('\nSplitting second OLDEX tree...\n');
% % % % tree = split_node_if_impure(tree,1);
% % % % fprintf('\nRestructuring second OLDEX tree...\n');
% % % % tree = ensure_best_variable(tree,1);
% % % % %copy tree back to tree2

% % % % tree_oldex_2 = tree;
% % % % tree_oldex_2_class_counts = tree_class_counts;
% % % % tree_oldex_2_class_counts_tags = tree_class_counts_tags;
% % % % tree_oldex_2_numeric_value_counts = tree_numeric_value_counts;
% % % % n_variables = n_variables_old;
% % % % n_OLDEX_variables = n_variables_old;

total_cpu = toc(begin_cpu);

% % % % %now save the trees out
% % % % tree = tree_oldex_1;
% % % % tree_class_counts = tree_oldex_1_class_counts;
% % % % tree_class_counts_tags = tree_oldex_1_class_counts_tags;
% % % % tree_numeric_value_counts = tree_oldex_1_numeric_value_counts;
% % % % 
% % % % 
% % % % save('oldex_out.mat', ...
% % % %     'tree_oldex_1',...
% % % %     'tree_oldex_1_class_counts',...
% % % %     'tree_oldex_1_class_counts_tags',...
% % % %     'tree_oldex_1_numeric_value_counts',...
% % % %     'tree_oldex_2',...
% % % %     'tree_oldex_2_class_counts',...
% % % %     'tree_oldex_2_class_counts_tags',...
% % % %     'tree_oldex_2_numeric_value_counts');
% % % % 
