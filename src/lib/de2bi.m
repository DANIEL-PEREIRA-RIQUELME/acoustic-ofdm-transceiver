function b = de2bi(d, msbflag, n)
%SOL_DE2BI Convert decimal numbers to binary numbers
%   B = SOL_DE2BI(D) converts a vector D of non-negative integers from base
%   10 to a binary matrix B. Each row of the binary matrix B corresponds
%   to one element of D. The default orientation of the binary output
%   is Right-MSB, i.e., the first element in a row of B represents the
%   least significant bit. If D is a matrix rather than a row or column
%   vector, the matrix is first converted to a vector (column-wise).
%
%   In addition to the input vector D, two optional parameters can
%   be given:
%
%   B = SOL_DE2BI(D,MSBFLAG) uses MSBFLAG to determine the output
%   orientation. MSBFLAG has two possible values, 'right-msb' and
%   'left-msb'. Giving a 'right-msb' MSBFLAG does not change the
%   function's default behavior. Giving a 'left-msb' MSBFLAG flips the
%   output orientation to display the MSB to the left.
%
%   B = SOL_DE2BI(D,MSBFLAG,N) uses N to define how many binary digits
%   (columns) are output. The number of bits must be large enough to
%   represent the largest number in D.

% first we do various tests
    if ~isfloat(d)
        d = double(d);
        % Promote input to double, so that we can handle other types (uint8, etc)
        % This is necessary since log2 can only handle doubles, and other
        % functions used below, such as kron, cannot mix double and uint
        % inputs
    end
    
    % assume d is a row/column vector
    % Convert d to column if necessary
    d = d(:);
    
	% Check number of arguments and assign default values as necessary	
    nmax = max(1, floor(1+log2(double(max(d)))));    
	if (nargin < 3)
		n = nmax;       
	elseif (nmax > n)
		error('sol_de2bi:insufficientNbits', ...
            'Specified number of bits is too small to represent some of the decimal inputs,\n at least %d bits are required', nmax);
	end			
					
	if (nargin < 2)	
		msbflag = 'right-msb';
	end
	
	% Make sure input is nonnegative decimal
    if any((d < 0) | (d ~= fix(d)) | isnan(d) | isinf(d))
        error('sol_de2bi:invalidInput', 'Input must contain only finite positive integers.');
    end
    
    % We are ready to get the job done
    % We use two approaches
    % The idea is to use a function that manipulates bits ...
    % and manipulate them in such a way that we get a hold of various bits.
    % One approach uses bitshift; the other approach uses bitand
    % The following is useful in both approaches
    
    switch lower(msbflag)
		case 'left-msb'
			shifts=-(n-1:-1:0);
		case 'right-msb'
			shifts=-(0:n-1);
		otherwise
			error('sol_de2bi:wrongMSBflag', 'Unsupported value for MSBFLAG');
    end
    
    
    % bitshift approach
    % ----------------
    % Here is the main idea:
    % Suppose that d=11 is the number that we want to convert into binary
    % To get 4 bits of d, we run the command 
    % b=bitshift([d d d d],[0 -1 -2 -3])
    % This returns b=[11 5 2 1]
    % Since 11 is odd, the first bit of d is 1
    % Since 5 is odd, the second bit of d is 1
    % Since 2 is even, the third bit of d is 0 etc. 
    % Hence mod(b,2) returns the binary representation 1 1 0 1 (left LSB)
   
%     c = mod(bitshift(repmat(d, size(shifts)), repmat(shifts, size(d))), 2);
%     b = logical(c);
%     
    % bitand approach
    % ---------------
    % Here is the main idea:
    % Suppose that d=11 is the number that we want to convert into binary
    % To get 4 bits of d, we run the command
    % b=bitand([d d d d],[1 2 4 8])
    % This returns b=[1 2 0 8]
    % The nonzero positions of b is where the bit is 1
    % Hence b~=0 (or logical(b)) returns the binary representation 1 1 0 1
    

   powersOf2=2.^-shifts;
   c = bitand(repmat(d, size(powersOf2)), repmat(powersOf2, size(d)));
   b = logical(c);
   
