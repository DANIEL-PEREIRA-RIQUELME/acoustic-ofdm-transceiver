function z = decoder(y, mapping)
%SOL_DECODER Minimum distance slicer
%   Z = SOL_DECODER(Y, MAPPING) demodulates vector Y by finding
%   the element of the specified constellation that is closest to each
%   element of input Y. Y contains the outputs of the matched filter of
%   the receiver, and it can be a row or column vector. MAPPING specifies
%   the constellation used, it can also be a row or column vector.
%   Output Z has the same dimensions as input Y. The elements of Z are
%   M-ary symbols, i.e., integers between 0 and [M=length(MAPPING)]-1.

% For each element of y, we need to compute the distance to each symbol of the constellation, and
% find the one that is closest

% Make sure y is a vector
[nrows, ncols] = size(y);
if ((nrows ~= 1) && (ncols ~= 1))
	error('sol_decoder:inputNotVector', 'Input Y must be a vector');
end

% If y is a column vector, transpose it to make sure y is a row vector
if (nrows ~= 1)
	y = transpose(y); 
end	

% Make sure mapping is a column vector
mapping = mapping(:);

% Compute all Euclidean distances
M = length(mapping); % size of the constellation
L = length(y);
distances = abs(repmat(y, M, 1) - repmat(mapping, 1, L)); 
    % Another way to do this is to use meshgrid instead of repmat:
    % [y_rep, mappping_rep] = meshgrid(y, mapping);
    % distances = abs(y_rep - mapping_rep);
    
    % Yet another option is to use ndgrid - this works for both row/column
    % entries, so no need to worry about y and mapping orientation
    % [mappping_rep, y_rep] = ndgrid(mapping, y);
    % distances = abs(y_rep - mapping_rep);

% distances is M x L, and column i contains the distance of received symbol i to all constellation points, i=1..L
% The slicer just needs to find the minimum of every column of this matrix
% The result of min is a row vector, containing the minimum/position value of each column.
[mindistances, positions] = min(distances);  %#ok<ASGLU>

    % Since we do not use mindistances later on, modern versions of Matlab
    % (versions > R2009b) allow this syntax: [~, positions] = min(distances)
    % to indicate that an output argument of a function call is to be ignored

% The second output argument of min returns the row number for which the 
% minimum was found in each column
z = positions - 1; % Go from [1, M] indices to [0, M-1] M-ary symbols

% z is a row vector; modify it if necessary to return a vector of the same orientation as the input
if (nrows ~= 1)
	z = transpose(z);
end
