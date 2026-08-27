function d = bi2de(b, msbflag)
%SOL_BI2DE Convert binary vectors to decimal numbers
%   D = SOL_BI2DE(B) converts a binary vector B to a decimal value D. When
%   B is a matrix, the conversion is performed row-wise and the output
%   D is a column vector of decimal values. The default orientation of
%   the binary input is Right-MSB: the first element in B represents
%   the least significant bit.
%
%   In addition to the input matrix, an optional parameter MSBFLAG can
%   be given:
%
%   D = SOL_BI2DE(B, MSBFLAG) uses MSBFLAG to determine the input
%   orientation. MSBFLAG has two possible values, 'right-msb' and
%   'left-msb'. Giving a 'right-msb' MSBFLAG does not change the
%   function's default behavior. Giving a 'left-msb' MSBFLAG flips the
%   input orientation such that the MSB is on the left.

% Set defaults
if (nargin < 2)
    msbflag = 'right-msb';
end

% Test that the matrix contains only ones and zeros
if ~all(all(b == 1 | b == 0))
    error('sol_bi2de:nonBinaryValuesInInput', 'Binary matrix B can only contain values 1 and 0');
end

% Determine dimension of input, and prepare vector containing powers of 2
% Assume b is row by row matrix (each row corresponds to a binary representation of a decimal value)
ncols = size(b, 2);
ptwo = 2 .^ (0:ncols-1)'; % column vector

% Flip the input if MSB is left
switch lower(msbflag)
    case 'left-msb'
        b = fliplr(b);
    case 'right-msb'
        % do nothing
    otherwise
        error('sol_bi2de:wrongMSBflag','Unsupported value for MSBFLAG');
end

% Multiply and sum
d = b * ptwo;
