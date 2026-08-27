function c = qamMap(M)
%SOL_QAMMAP Creates constellation for square QAM modulations
%   C = SOL_QAMMAP(M) outputs a 1xM vector with the constellation for the
%   quadrature amplitude modulation of alphabet size M, where M is of 
%   the form 2^(2m) for some positive integer m. The signal
%   constellation is a square constellation.


% Verify that M is the square of a power of two
if log2(sqrt(M)) ~= fix(log2(sqrt(M)))
    error('sol_qamMap:invalidSize', 'M must be in the form of M = 2^(2K), where K is a positive integer.');
end

aux = (-(sqrt(M)-1):2:sqrt(M)-1);
	
[x, y] = meshgrid(aux, fliplr(aux));
	
c = x + 1i*y;

% We finally reshape c to be a row vector
% The columns are stacked on each other as in the homework assignment
% figures
c = transpose(c(:));
