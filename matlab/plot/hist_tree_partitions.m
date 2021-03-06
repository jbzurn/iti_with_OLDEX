function hist_tree_partitions(tree,x,nodes,zip_train_data,zip_train_classes,markersize)
%draw a histogram based on 1 attributes and partition it based on the
%cut values in the tree
%requires: descend_partition.m 
%inputs:
%tree:iti tree
%x:attribute (column) to get histogram for
%nodes: maximum nodes to traverse (0=traverse entire tree)
%zip_train_data,zip_train_classes: data and classes to hist and partition

%first separate the classes
[insts atts] = size(zip_train_data);

classes=unique(zip_train_classes);
[num_classes dummy] = size(classes);

%get distributions for each class

%how many different values for all classes?
hist_vals = unique(zip_train_data(:,x));
[num_vals dummy] = size(hist_vals);

%setup matrix for bar graph. each column is a separate class
class_counts = zeros(num_vals,num_classes);

for i=1:num_classes
    %get data for current class
    this_class = strcmp(zip_train_classes,classes{i});
    %get distribution of data values, with respect to known hist_vals
    class_counts(:,i) = hist(zip_train_data(this_class,x),hist_vals); %don't need [n xout] = ... b/c we supplied hist_vals for categories
end

%bar graph the class counts
hold off
figure
bar(hist_vals,class_counts)
hold on


    
% figure
% [zip_train_classes_numeric zip_train_classes_numeric_key] = get_numeric_classes(zip_train_classes);
% scatter_shapes(zip_train_data(:,x),zip_train_data(:,y),markersize,zip_train_classes_numeric(:,1));

if(nodes<1)
    [dummy nodes]=size(tree);
end

cutvars = zeros(nodes,1);
cutvals = cutvars;

for i=1:nodes
   % get cutvar
   cutvars(i,1)=tree(1,i).best_variable;
   % get cutval
   if(cutvars(i,1)>0)
    cutvals(i,1)=tree(1,i).variables(1,(cutvars(i,1))).cutpoint{1};
   end
end

%now start partitioning
partitions_x = zeros(nodes,2);
partitions_y = zeros(nodes,2);

% xmin = min(zip_train_data(:,x));
% xmax = max(zip_train_data(:,x));
% ymin = 0;
% ymax = max(max(class_counts));
temp=xlim;
xmin = temp(1,1);
xmax = temp(1,2);
temp=ylim;
ymin=temp(1,1);
ymax=temp(1,2);


%descend starting at node 1 (root)
[partitions_x,partitions_y] = descend_partition(tree,1,cutvars,cutvals,x,x,xmin,xmax,ymin,ymax,partitions_x,partitions_y);

%draw the partitions on the scatterplot
%hold on  already set this earlier

for i=1:nodes
    line(partitions_x(i,:),partitions_y(i,:));
end

%reset plot limits to data limits
axis([xmin xmax ymin ymax])
colormap(copper)
hold off
