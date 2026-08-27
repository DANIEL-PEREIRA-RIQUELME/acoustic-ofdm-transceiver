function [ofdm_samples_os] = ofdm_tx_resampling(ofdm_samples, conf)
%OFDM_TX_RESAMPLING resample the OFDM signal sampled at (conf.ofdm.ncarrier*conf.ofdm.spacing) 
% to match the target sampling rate conf.f_s
%
%   INPUTS 
%   - ofdm_samples: samples of OFDM signal
%   - conf: system configuration
%
%   OUTPUTS
%   - ofdm_samples_os: OFDM signal with a sampling rate of conf.f_s

if ~(size(ofdm_samples,1) == 1 | size(ofdm_samples,2) == 1 )
    error("ofdm_samples should be a vector");
end

if (mod(conf.f_s, conf.ofdm.bandwidth)~= 0)
    error("f_s/bw should be an integer for resampling");
end

    
if(conf.ofdm.os_factor > 1)
    GCD = gcd(conf.f_s, conf.ofdm.ncarrier*conf.ofdm.spacing);
    b = fir1(120, 1.5/conf.ofdm.os_factor);
    [ofdm_samples_os ,~]= resample(ofdm_samples,conf.f_s/GCD,conf.ofdm.ncarrier*conf.ofdm.spacing/GCD,b);
else
    ofdm_samples_os = ofdm_samples;
end
end