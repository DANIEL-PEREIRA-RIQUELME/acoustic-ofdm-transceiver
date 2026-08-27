function Y_corr = correctOFDMSymbolRotation(Y, pilot_indices, pilot_symbols, verbose)
% CORRECTOFDMSYMBOLROTATION Pilot-assisted residual CFO phase tracking & derotation.
%
%   Y_corr = CORRECTOFDMSYMBOLROTATION(Y, pilot_indices, pilot_symbols, verbose)
%   estimates and removes symbol-by-symbol phase rotation caused by residual
%   Carrier Frequency Offset (CFO) and sampling clock drift.
%
%   Methodology:
%     For each OFDM block l, the phase error theta[l] across pilot subcarriers is:
%       theta[l] = angle( p^H * Y_pilots[l] )
%     where p is the known pilot symbol vector and Y_pilots[l] is the received
%     equalized pilot vector. The entire OFDM symbol is then derotated by exp(-j * theta[l]).
%
% Inputs:
%   Y             - Demodulated frequency-domain grid [N_carriers x N_symbols].
%   pilot_indices - Indices of pilot subcarriers.
%   pilot_symbols - Reference pilot symbols transmitted on pilot subcarriers.
%   verbose       - Optional flag to display rotation diagnostics (default: 0).
%
% Outputs:
%   Y_corr        - Phase-derotated frequency-domain symbol grid.
%
% Wireless Receivers: Algorithms and Architectures
% Telecommunications Circuits Laboratory (TCL), EPFL

    if nargin < 4, verbose = 0; end

    num_carriers = size(Y, 1);
    num_symbols  = size(Y, 2);

    if ~isvector(pilot_indices) || ~isvector(pilot_symbols)
        error('correctOFDMSymbolRotation:invalidPilots', 'pilot_indices and pilot_symbols must be vectors.');
    end

    if numel(pilot_symbols) ~= numel(pilot_indices)
        error('correctOFDMSymbolRotation:dimMismatch', 'pilot_symbols length must match pilot_indices length.');
    end

    % Least Squares estimation of phase rotation per OFDM symbol
    pilot_ref = pilot_symbols(:);
    Y_pilots = Y(pilot_indices, :);
    
    rotations = angle(pilot_ref' * Y_pilots);

    if verbose
        fprintf('\nSymbol-by-Symbol Phase Tracking Report:\n');
        for sym_idx = 1:min(num_symbols, 10)
            fprintf('  Symbol #%2d: Phase Drift = %+.2f deg\n', sym_idx, rad2deg(rotations(sym_idx)));
        end
        if num_symbols > 10
            fprintf('  ... (%d symbols total)\n', num_symbols);
        end
    end

    % Apply derotation phase correction across all subcarriers
    phase_corr = repmat(rotations, num_carriers, 1);
    Y_corr = Y .* exp(-1j * phase_corr);
end
