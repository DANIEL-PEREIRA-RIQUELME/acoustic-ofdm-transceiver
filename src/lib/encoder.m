function y = encoder(x, mapping)
%SOL_ENCODER Maps a vector of M-ary integers to constellation points
%   Y = SOL_ENCODER(X, MAPPING) outputs a vector of (possibly complex)
%   symbols from the constellation specified as second parameter,
%   corresponding to the integer valued symbols of X.  Input X can be
%   a row or column vector, and output Y has the same dimensions as X.
%   If the length of vector MAPPING is M, then the message symbols of
%   X must be integers between 0 and M-1.


M = length(mapping);

% Verify you do not have a matrix
if (size(x,1) > 1 && size(x,2) > 1)
    error('sol_encoder:wrongInputValues', 'X should be either a row or column vector, not a matrix!')
end

% Verify that x contains only INTEGER elements between 0 and M-1
if ~all((x >= 0) & (x < M) & (x == fix(x)))
    error('sol_encoder:wrongInputValues', 'Elements of input X must be integers in the range [0, %d]', M-1);
end

% Indexing outputs the same dimension as the INDEXED object, no matter the
% dimension of the indexing object (Well, for arbitrary indexing MxN matrices - not row or column - it outputs the same dimension as the matrix)
% So if the indexed object (mapping) does not have the same dimension as
% the indexing object, we transpose it

mapping = mapping(:); % we make it column
if (size(x, 1) == 1) % input is row vector
    mapping = transpose(mapping); % we make the mapping a row as well so the output is a row vector
end

% We can use the vector x directly to index vector mapping, we
% just need to add 1 to x since indices start at 1 and not at 0. 
y = mapping(x+1);
