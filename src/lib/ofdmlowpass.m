function [after] = ofdmlowpass(before,conf,f)
% LOWPASS lowpass filter
% Low pass filter for extracting the baseband signal 
%
%   before  : Unfiltered signal
%   conf    : Global configuration variable
%   f       : Corner Frequency, default to 1.5*bandwidth/2
%
%   after   : Filtered signal
%
% Note: This filter is very simple but should be decent for most 
% application. For very high symbol rates and/or low carrier frequencies
% it might need tweaking.
%
arguments
    before;
    conf;
    f = 1.5*conf.ofdm.bandwidth/2
end
after = lowpass(before, f,conf.f_s, StopbandAttenuation=30);

