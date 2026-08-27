function tx_signal = transmitter(data_bits, preamble_bits, conf)
% TRANSMITTER Synthesizes the continuous-time passband acoustic OFDM waveform.
%
%   tx_signal = TRANSMITTER(data_bits, preamble_bits, conf) performs the
%   complete physical layer transmitter chain:
%     1. Optional Concatenated FEC encoding (Reed-Solomon outer + Convolutional inner).
%     2. Constellation mapping (QPSK / 16-QAM) with average energy normalization.
%     3. OFDM frame synthesis: training symbol insertion, pilot multiplexing,
%        IFFT modulation, and Cyclic Prefix (CP) extension.
%     4. Digital upsampling/interpolation to the DAC sampling frequency (Fs = 48 kHz).
%     5. Preamble generation: BPSK LFSR sequence with Root-Raised Cosine (RRC)
%        pulse-shaping for timing/CFO detection.
%     6. Frame assembly and digital upconversion to carrier frequency fc (8 kHz).
%
% Inputs:
%   data_bits     - Binary vector containing information payload bits.
%   preamble_bits - Binary vector containing synchronization preamble sequence.
%   conf          - Configuration structure from configurations().
%
% Outputs:
%   tx_signal     - Real-valued time-domain signal ready for channel transmission.
%
% Wireless Receivers: Algorithms and Architectures
% Telecommunications Circuits Laboratory (TCL), EPFL

    global ofdmc;
    if isempty(ofdmc)
        ofdmConfig(); 
    end

    % Input validation and vector alignment
    if ~isvector(data_bits)
        warning('transmitter:invalidDim', 'Input data_bits must be a 1D vector. Reshaping.');
    end
    data_bits = data_bits(:);

    % =====================================================================
    % 1. Forward Error Correction (FEC) Encoding
    % =====================================================================
    use_fec = false;
    if isfield(conf, 'coding') && isstruct(conf.coding) && isfield(conf.coding, 'use_fec')
        use_fec = conf.coding.use_fec;
    end

    if use_fec
        trellis = poly2trellis(7, [171 133]);
        encoded_bits = convenc(data_bits, trellis);
        current_bits = encoded_bits;
    else
        current_bits = data_bits;
    end

    % =====================================================================
    % 2. Framing & Zero-Padding
    % =====================================================================
    n_current = numel(current_bits);
    if n_current < ofdmc.nDataBits
        padding = randi([0, 1], ofdmc.nDataBits - n_current, 1);
        tx_payload = [current_bits; padding];
    elseif n_current > ofdmc.nDataBits
        warning('transmitter:payloadTruncated', 'Payload exceeds frame capacity (%d bits). Truncating.', ofdmc.nDataBits);
        tx_payload = current_bits(1:ofdmc.nDataBits);
    else
        tx_payload = current_bits;
    end

    % =====================================================================
    % 3. Constellation Mapping
    % =====================================================================
    bits_per_sym = log2(ofdmc.M);
    tx_bit_matrix = transpose(reshape(tx_payload, bits_per_sym, [])); 
    decimal_symbols = bi2de(tx_bit_matrix, 'left-msb'); 

    switch lower(ofdmc.constellationType)
        case 'qam'
            mapping = qamMap(ofdmc.M);
        case 'psk'
            mapping = pskMap(ofdmc.M);
        otherwise
            error('transmitter:unsupportedMod', 'Unsupported modulation format: %s', ofdmc.constellationType);
    end
    
    % Unit average power normalization
    mapping = mapping ./ sqrt(mean(abs(mapping).^2));
    data_symbols = encoder(decimal_symbols, mapping);

    % =====================================================================
    % 4. OFDM Multicarrier Modulation
    % =====================================================================
    ofdm_baseband = ofdm_tx_frame_with_pilots( ...
        ofdmc.nCarriers, ...
        ofdmc.psdMask, ...
        ofdmc.cpLength, ...
        ofdmc.trainingSymbols, ...
        ofdmc.pilotIndices, ...
        ofdmc.pilotSymbols, ...
        data_symbols, ...
        conf ...
    );

    % Power normalization
    ofdm_baseband = ofdm_baseband / sqrt(mean(abs(ofdm_baseband).^2));
    
    % Resampling to master DAC rate Fs (48 kHz)
    tx_ofdm_up = resample(ofdm_baseband, conf.ofdm.os_factor, 1, 10);

    % =====================================================================
    % 5. Preamble Generation & Pulse Shaping
    % =====================================================================
    preamble_bpsk = 2 * preamble_bits - 1;
    preamble_upsampled = upsample(preamble_bpsk, conf.sc.os_factor);
    preamble_shaped = conv(preamble_upsampled, conf.sc.txpulse, 'same');
    preamble_symbols = preamble_shaped / sqrt(mean(abs(preamble_shaped).^2));
    
    % Assemble complete time-domain baseband frame: [Preamble; Guard Zeros; OFDM Data]
    tx_frame = [preamble_symbols(:); ...
                zeros(ofdmc.nZeros, 1); ...
                tx_ofdm_up(:)];
             
    tx_frame = tx_frame(:).'; 

    % =====================================================================
    % 6. Digital Upconversion to Carrier Frequency fc
    % =====================================================================
    t = (0:length(tx_frame)-1) / conf.f_s;
    tx_signal = real(tx_frame .* exp(1j * 2 * pi * conf.f_c * t));
    
    % Peak-to-Average Power Ratio (PAPR) scaling / normalization to [-1, 1]
    tx_signal = tx_signal / max(abs(tx_signal));
    
    if conf.verbose
        tfplotReImPhase(tx_signal, conf.f_s, 's', 'TX Transmitted Signal');
    end
end
