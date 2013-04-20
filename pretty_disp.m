function pretty_disp(matrix_struct_names, num_matrices, struct, vals_per_line)

for j=1:num_matrices
    dot=find(matrix_struct_names{j}=='.');
    temp = eval(['struct' matrix_struct_names{j}(dot:end)]);
    disp(matrix_struct_names{j});
    len=length(temp);
    
    if iscell(temp)
        cell_array=temp;
        cell_array
    else
        for i=1:(vals_per_line+1):len
            if i+vals_per_line<=len
                disp(num2str(temp(i:i+vals_per_line)))
            else
                disp(num2str(temp(i:end)))
            end
        end
    end
end
