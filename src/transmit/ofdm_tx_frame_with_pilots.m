function tx_symbols = ofdm_tx_frame_with_pilots(num_carriers, psd_mask, prefix_length, training_symbols, pilot_indices, pilot_symbols, data_symbols, conf)
% OFDM_TX_FRAME_WITH_PILOTS Constructs a multicarrier time-domain OFDM frame.
%
%   tx_symbols = OFDM_TX_FRAME_WITH_PILOTS(num_carriers, psd_mask, ...
%       prefix_length, training_symbols, pilot_indices, pilot_symbols, ...
%       data_symbols, conf)
%
%   Processes the serial symbol stream into an OFDM frame structure:
%     1. Validates subcarrier, mask, cyclic prefix, and pilot dimensions.
%     2. Prepends a dedicated Training Symbol in the first OFDM block for
%        frequency-domain channel estimation (Channel Frequency Response).
%     3. Multiplexes pilot subcarriers into every subsequent data block for
%        dynamic phase tracking / residual CFO derotation.
%     4. Maps data and pilots onto active subcarriers defined by the PSD mask.
%     5. Computes the IFFT to convert from frequency domain to time domain.
%     6. Appends a Cyclic Prefix (CP) to each OFDM symbol to prevent ISI.
%     7. Serializes the parallel multicarrier blocks into a single column vector.
%
% Inputs:
%   num_carriers     - FFT block size N (e.g., 512).
%   psd_mask         - Logical vector of active subcarriers (length N).
%   prefix_length    - Cyclic prefix guard interval length in samples (e.g., 256).
%   training_symbols - Known training sequence mapped to active subcarriers.
%   pilot_indices    - Subcarrier indices allocated for phase tracking pilots.
%   pilot_symbols    - Known reference symbols modulated on pilot carriers.
%   data_symbols     - Complex constellation data symbols to be transmitted.
%   conf             - Master transceiver configuration structure.
%
% Outputs:
%   tx_symbols       - Serialized time-domain baseband OFDM waveform.
%
% Wireless Receivers: Algorithms and Architectures
% Telecommunications Circuits Laboratory (TCL), EPFL

    % --- Input Validation ---
    if ~isscalar(num_carriers) || num_carriers <= 0 || mod(num_carriers, 1) ~= 0
        error('ofdm_tx_frame:invalidN', 'num_carriers must be a positive integer.');
    end
    if ~isscalar(prefix_length) || prefix_length < 0 || mod(prefix_length, 1) ~= 0
        error('ofdm_tx_frame:invalidCP', 'prefix_length must be a non-negative integer.');
    end
    if ~isvector(psd_mask) || numel(psd_mask) ~= num_carriers
        error('ofdm_tx_frame:maskDim', 'psd_mask length must equal num_carriers (%d).', num_carriers);
    end
    if ~isvector(pilot_indices) || ~isvector(pilot_symbols) || numel(pilot_indices) ~= numel(pilot_symbols)
        error('ofdm_tx_frame:pilotDim', 'pilot_indices and pilot_symbols must have identical dimensions.');
    end

    psd_mask = logical(psd_mask);
    num_useful_carriers = sum(psd_mask);
    
    if numel(training_symbols) ~= num_useful_carriers
        error('ofdm_tx_frame:trainingDim', 'training_symbols length must match active carriers count (%d).', num_useful_carriers);
    end

    % --- Subcarrier Allocation ---
    num_data_carriers = num_useful_carriers - numel(pilot_indices);
    num_data_symbols  = numel(data_symbols);
    num_data_blocks   = ceil(num_data_symbols / num_data_carriers);
    
    % Pad data symbols with zeros to fill integer OFDM blocks
    padding_needed = (num_data_blocks * num_data_carriers) - num_data_symbols;
    data_padded = [data_symbols(:); zeros(padding_needed, 1)];

    % Total OFDM blocks in frame = 1 Training Symbol + N data blocks
    total_ofdm_blocks = num_data_blocks + 1;
    
    % Frequency-domain grid for active subcarriers: [useful_carriers x total_blocks]
    B = zeros(num_useful_carriers, total_ofdm_blocks);
    
    % First block: Dedicated Channel Estimation Training Symbol
    B(:, 1) = training_symbols(:);

    % Construct pilot subcarrier mask on active subcarriers
    pilot_full_mask = false(1, num_carriers);
    pilot_full_mask(pilot_indices) = true;
    pilot_active_mask = pilot_full_mask(psd_mask);

    % Populate subsequent blocks with data and pilot symbols
    B(~pilot_active_mask, 2:end) = reshape(data_padded, num_data_carriers, []);
    B(pilot_active_mask,  2:end) = repmat(pilot_symbols(:), 1, num_data_blocks);

    % Expand to full FFT grid according to PSD mask (zeroing out notches/guard bands)
    A = zeros(num_carriers, total_ofdm_blocks);
    A(psd_mask, :) = B;

    % --- Multicarrier Modulation (IFFT) & Cyclic Prefix Extension ---
    % Perform column-wise IFFT
    time_blocks = ifft(A, num_carriers);

    % Append Cyclic Prefix: copy last prefix_length samples to the beginning
    cp_segment = time_blocks(num_carriers - prefix_length + 1 : num_carriers, :);
    time_blocks_cp = [cp_segment; time_blocks];

    % Serialize into continuous time-domain baseband stream
    tx_symbols = time_blocks_cp(:);

    if isfield(conf, 'verbose') && conf.verbose
        tfplotReImPhase(tx_symbols, 2000, 's', 'OFDM Baseband Waveform with Pilots');
    end
end
