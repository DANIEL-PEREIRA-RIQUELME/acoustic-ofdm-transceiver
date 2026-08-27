function Rf = ofdm_rx_frame(rx_symbols, num_carriers, psd_mask, prefix_length)
% OFDM_RX_FRAME Demodulates baseband OFDM symbols from time domain to frequency grid.
%
%   Rf = OFDM_RX_FRAME(rx_symbols, num_carriers, psd_mask, prefix_length)
%   performs:
%     1. Truncates the serialized time-domain signal to an integer number of blocks.
%     2. Reshapes into a matrix with (num_carriers + prefix_length) rows.
%     3. Strips the Cyclic Prefix (CP) guard interval.
%     4. Applies the Discrete Fourier Transform (FFT) on each symbol block.
%     5. Extracts only active subcarriers specified by `psd_mask`.
%
% Inputs:
%   rx_symbols    - Received time-domain baseband sample vector.
%   num_carriers  - Total subcarrier count / FFT size N (e.g., 512).
%   psd_mask      - Logical active subcarrier mask (length N).
%   prefix_length - Cyclic Prefix length in samples (e.g., 256).
%
% Outputs:
%   Rf            - Matrix of frequency-domain complex symbols [useful_carriers x num_blocks].
%
% Wireless Receivers: Algorithms and Architectures
% Telecommunications Circuits Laboratory (TCL), EPFL

    if ~isscalar(num_carriers) || num_carriers <= 0 || mod(num_carriers, 1) ~= 0
        error('ofdm_rx_frame:invalidN', 'num_carriers must be a positive integer.');
    end
    if ~isscalar(prefix_length) || prefix_length < 0 || mod(prefix_length, 1) ~= 0
        error('ofdm_rx_frame:invalidCP', 'prefix_length must be a non-negative integer.');
    end
    if ~isvector(psd_mask) || numel(psd_mask) ~= num_carriers
        error('ofdm_rx_frame:invalidMask', 'psd_mask must have length equal to num_carriers.');
    end

    psd_mask = logical(psd_mask);
    rx_symbols = rx_symbols(:);

    % Calculate total complete OFDM blocks present
    symbol_total_len = num_carriers + prefix_length;
    num_ofdm_symbols = floor(length(rx_symbols) / symbol_total_len);
    
    if num_ofdm_symbols == 0
        Rf = [];
        return;
    end
    
    % Truncate tail samples that do not form a complete block
    rx_symbols = rx_symbols(1 : num_ofdm_symbols * symbol_total_len);

    % Reshape to columns of length (N + CP)
    rx_withCP = reshape(rx_symbols, symbol_total_len, num_ofdm_symbols); 
    
    % Remove Cyclic Prefix (first prefix_length rows)
    rx_noCP = rx_withCP(prefix_length + 1 : end, :);

    % Multicarrier Demodulation via FFT
    grid_full = fft(rx_noCP, num_carriers);

    % Filter active subcarriers according to PSD mask
    Rf = grid_full(psd_mask, :);
end