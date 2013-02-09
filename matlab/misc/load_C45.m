function [data classes] = load_C45(filename,instances,attributes)
%load a C4.5 format data file (text, CSV, last value == class, period at
%end of line.
%Author: J. Brooks Zurn
%inputs:
%filename: name of file to read
%instances: number of instances to load
%attributes: number of attributes per instance (assume we previously loaded
%this from a 'names' file
%outputs:
%data: an [instances x attributes] array of numerical data
%classes: an {instances x 1} cell array of class names

if(instances>=1)
    if(array_is_empty(findstr(filename,'.data')))
        filename = strcat(filename,'.data');
    end
    fid = fopen(filename,'r');
        
    data = zeros(instances,attributes);
    classes = cell(instances,1);
    
    for i=1:instances
        
        tempdata = fscanf(fid,['%f,'])';
        [rows cols] = size(tempdata);
        if(cols>attributes) %then the class label is a number and was grabbed by accident
            
            for j=1:attributes
            %data(i,:)=tempdata(1,1:attributes);
            data(i,j)=tempdata(1,j);
            end
            classes{i,1} = sprintf('%d',tempdata(1,cols));
        else %otherwise the class label is a string. get it.
            for j=1:attributes
            %data(i,:)=tempdata;
            
            data(i,j)=tempdata(1,j);
            end
            class_temp = fscanf(fid,'%s.');
            class_temp2 = textscan(class_temp,'%[^.]');
            classes{i,1} = char(class_temp2{1});
        end
    end
else
    fprintf('(load_C45) error: specified number of instances is zero. No data loaded.\n');
    data=0;
    classes='none';
end
fclose(fid);




