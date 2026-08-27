function [ofdm_samples] = ofdm_rx_resampling(ofdm_samples_os,conf)
%OFDM_RX_RESAMPLING resample the OFDM signal sampled at conf.f_s  
% to match the target sampling rate (conf.ofdm.ncarrier*conf.ofdm.spacing)
%
%   INPUTS 
%   - ofdm_samples: samples of OFDM signal at a sampling rate conf.f_s
%   - conf: system configuration
%
%   OUTPUTS
%   - ofdm_samples_os: OFDM signal with a sampling rate of (conf.ofdm.ncarrier*conf.ofdm.spacing)

if ~(size(ofdm_samples_os,1) == 1 |size(ofdm_samples_os,2) == 1 )
    error("ofdm_samples_os should be a vector");
end

% Downsample the signal
if(conf.ofdm.os_factor>1)
    [ofdm_samples, ~] = resample(ofdm_samples_os,conf.ofdm.bandwidth,conf.f_s);
else
    ofdm_samples = ofdm_samples_os;
end
end