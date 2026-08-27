% =========================================================================
% Acoustic OFDM Transceiver - Path Configuration Script
% =========================================================================
% Description:
%   Adds all source directories (config, transmit, receive, lib) and data 
%   folders to the MATLAB environment search path.
%
% Usage:
%   run setpath;
% =========================================================================

function setpath()
    project_root = fileparts(mfilename('fullpath'));
    
    addpath(fullfile(project_root, 'src', 'config'));
    addpath(fullfile(project_root, 'src', 'transmit'));
    addpath(fullfile(project_root, 'src', 'receive'));
    addpath(fullfile(project_root, 'src', 'lib'));
    addpath(fullfile(project_root, 'data'));
    
    fprintf('[OFDM System] MATLAB paths successfully initialized.\n');
end
