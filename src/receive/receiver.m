function rxbits = receiver(rxsignal, preamble_bits, conf)
% RECEIVER Demodulates and decodes the incoming acoustic OFDM signal.
%
%   rxbits = RECEIVER(rxsignal, preamble_bits, conf) executes the complete
%   physical layer digital receiver pipeline:
%     1. Digital downconversion from carrier frequency fc to baseband.
%     2. Lowpass anti-aliasing filtering to reject out-of-band noise.
%     3. Packet detection via energy-normalized cross-correlation with the preamble.
%     4. 2-stage Carrier Frequency Offset (CFO) estimation (Coarse grid + Fine parabolic).
%     5. Phase derotation of the time-domain baseband signal to compensate for CFO.
%     6. Payload extraction and decimation/downsampling to OFDM sampling rate.
%     7. Cyclic Prefix (CP) removal and FFT multicarrier demodulation.
%     8. Channel Frequency Response (CFR) estimation:
%        - Mode 1: Frequency-Domain Least Squares (LS).
%        - Mode 2: Circular-Shift Asymmetric Windowed LMMSE (Noise-Suppressed CIR).
%     9. Single-tap frequency-domain Zero-Forcing / MMSE equalization.
%    10. Pilot-based symbol-by-symbol residual phase drift tracking and correction.
%    11. Minimum-distance Euclidean constellation demapping.
%    12. Optional Concatenated FEC decoding (Viterbi hard-decision + Reed-Solomon).
%
% Inputs:
%   rxsignal      - Real-valued time-domain signal captured from channel/soundcard.
%   preamble_bits - Known binary synchronization sequence.
%   conf          - Master configuration structure from configurations().
%
% Outputs:
%   rxbits        - Estimated binary information payload bits.
%
% Wireless Receivers: Algorithms and Architectures
% Telecommunications Circuits Laboratory (TCL), EPFL

    global ofdmc;
    if isempty(ofdmc)
        ofdmConfig();
    end

    % Ensure column vector format
    rxsignal = rxsignal(:);

    % =====================================================================
    % 1. Digital Downconversion & Lowpass Filtering
    % =====================================================================
    t = (0:length(rxsignal)-1)' / conf.f_s;
    rxsignal_bb = rxsignal .* exp(-1j * 2 * pi * conf.f_c * t);
    
    % Anti-aliasing and image rejection lowpass filter
    rxsignal_bb = ofdmlowpass(rxsignal_bb, conf);
    
    if conf.verbose
        tfplotReImPhase(rxsignal_bb, conf.f_s, 's', 'RX Baseband Signal');
    end

    % =====================================================================
    % 2. Preamble Synchronization & CFO Estimation
    % =====================================================================
    preamble_bpsk = 2 * preamble_bits - 1; 
    
    [data_start_idx, cfo_estim] = estimateTauAndCFO( ...
        preamble_bpsk, ...
        rxsignal_bb, ...
        conf.sc.os_factor, ...
        conf.preamble.thr, ...
        ofdmc.T, ...
        ofdmc.rangeCFO, ...
        conf ...
    );

    % Abort gracefully if frame preamble is not detected
    if isempty(data_start_idx) || data_start_idx <= 0
        if isfield(conf, 'verbose') && conf.verbose
            warning('receiver:syncFailure', 'Preamble synchronization failed. Packet dropped.');
        end
        rxbits = [];
        return;
    end

    % =====================================================================
    % 3. Time-Domain CFO Derotation
    % =====================================================================
    t_bb = (0:length(rxsignal_bb)-1)' * ofdmc.T;
    rxsignal_bb = rxsignal_bb .* exp(-1j * 2 * pi * cfo_estim * t_bb);

    % =====================================================================
    % 4. Payload Extraction & Decimation
    % =====================================================================
    payload_start = data_start_idx + ofdmc.nZeros;
    samples_per_symbol_up = (ofdmc.nCarriers + ofdmc.cpLength) * conf.ofdm.os_factor;
    required_samples = ofdmc.nOFDMSymbols * samples_per_symbol_up;
    payload_end = payload_start + required_samples - 1;
    
    if payload_end > length(rxsignal_bb)
        if isfield(conf, 'verbose') && conf.verbose
            warning('receiver:truncatedSignal', 'Received signal shorter than expected frame duration. Truncating.');
        end
        rx_payload_up = rxsignal_bb(payload_start:end);
    else
        rx_payload_up = rxsignal_bb(payload_start : payload_end);
    end
    
    % Decimate back to OFDM baseband sampling rate (2 kHz)
    rx_payload_bb = resample(rx_payload_up, 1, conf.ofdm.os_factor);

    % =====================================================================
    % 5. OFDM Demodulation (CP Stripping & FFT)
    % =====================================================================
    Rf = ofdm_rx_frame(rx_payload_bb, ofdmc.nCarriers, ofdmc.psdMask, ofdmc.cpLength);
    
    if isempty(Rf)
        if isfield(conf, 'verbose') && conf.verbose
            warning('receiver:emptyFrame', 'OFDM frame extraction yielded empty grid.');
        end
        rxbits = [];
        return;
    end

    % =====================================================================
    % 6. Channel Estimation & LMMSE CIR Windowing
    % =====================================================================
    lambda_LS = channel_estLS(Rf, ofdmc.trainingSymbols);
    [lambda_clean, ~] = ChannelMetrics(lambda_LS, ofdmc, conf);
    
    % =====================================================================
    % 7. Frequency-Domain Equalization
    % =====================================================================
    switch conf.eq.mode
        case 1 % Standard Least Squares (LS)
            Rf_eq = Rf ./ repmat(lambda_LS(:), 1, size(Rf, 2));
        case 2 % Asymmetric Windowed LMMSE
            Rf_eq = Rf ./ repmat(lambda_clean(:), 1, size(Rf, 2));
        otherwise % No Equalization
            Rf_eq = Rf;
    end
    
    % =====================================================================
    % 8. Dynamic Residual Phase Tracking & Derotation via Pilots
    % =====================================================================
    Y_full = zeros(ofdmc.nCarriers, size(Rf_eq, 2));
    Y_full(ofdmc.psdMask, :) = Rf_eq;
    Y_corrected = correctOFDMSymbolRotation(Y_full, ofdmc.pilotIndices, ofdmc.pilotSymbols, 0);
    
    % =====================================================================
    % 9. Data Subcarrier Extraction & Constellation Demapping
    % =====================================================================
    % Discard the first symbol (training symbol)
    Y_data_blocks = Y_corrected(:, 2:end);
    
    data_mask = ofdmc.psdMask;
    data_mask(ofdmc.pilotIndices) = false;
    
    rx_data_symbols = Y_data_blocks(data_mask, :);
    rx_data_symbols = rx_data_symbols(:);
    
    if conf.verbose
        figure('Name', 'Equalized RX Constellation');
        plot(real(rx_data_symbols), imag(rx_data_symbols), '.');
        title('Equalized Constellation Symbols'); grid on; axis square;
    end

    % Minimum-distance constellation slicer
    switch lower(ofdmc.constellationType)
        case 'qam'
            mapping = qamMap(ofdmc.M);
        case 'psk'
            mapping = pskMap(ofdmc.M);
        otherwise
            error('receiver:unsupportedMod', 'Unsupported modulation: %s', ofdmc.constellationType);
    end
    
    mapping = mapping ./ sqrt(mean(abs(mapping).^2));
    rx_int_symbols = decoder(rx_data_symbols, mapping);
    
    % Integer symbol to binary bit conversion
    bits_per_sym = log2(ofdmc.M);
    rx_bits_mat = de2bi(rx_int_symbols, 'left-msb', bits_per_sym);
    raw_rx_bits = rx_bits_mat.';
    raw_rx_bits = raw_rx_bits(:);
    
    if length(raw_rx_bits) > ofdmc.nDataBits
        raw_rx_bits = raw_rx_bits(1:ofdmc.nDataBits);
    end

    % =====================================================================
    % 10. Forward Error Correction (FEC) Decoding
    % =====================================================================
    use_fec = false;
    if isfield(conf, 'coding') && isstruct(conf.coding) && isfield(conf.coding, 'use_fec')
        use_fec = conf.coding.use_fec;
    end

    if use_fec
        trellis = poly2trellis(7, [171 133]);
        traceBackDepth = 35;
        rxbits = vitdec(raw_rx_bits, trellis, traceBackDepth, 'trunc', 'hard');
    else
        rxbits = raw_rx_bits;
    end
end