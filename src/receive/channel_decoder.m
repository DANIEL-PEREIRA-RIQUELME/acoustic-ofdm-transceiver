function decoded_bits = channel_decoder(rx_coded_bits, conf)
% CHANNEL_DECODER Implements Concatenated Forward Error Correction (FEC) decoding.
%
%   decoded_bits = CHANNEL_DECODER(rx_coded_bits, conf) performs:
%     1. Inner Decoding: Viterbi decoder (hard decision) with configurable traceback.
%     2. Outer Decoding: Reed-Solomon RS(255, 239) decoder with graceful error fallback.
%     3. Formatting: Serializes decoded Galois Field symbols back to original bitstream.
%
% Inputs:
%   rx_coded_bits - Demodulated hard-decision binary bit vector.
%   conf          - Configuration structure matching the transmitter encoder parameters.
%
% Outputs:
%   decoded_bits  - Error-corrected binary information bits.
%
% References:
%   - Lin & Costello, "Error Control Coding: Fundamentals and Applications", 
%     Prentice-Hall, 2004.
%
% Wireless Receivers: Algorithms and Architectures
% Telecommunications Circuits Laboratory (TCL), EPFL

    if ~isfield(conf, 'coding')
        error('channel_decoder:MissingConf', 'Configuration structure must include the .coding field.');
    end

    rx_coded_bits = rx_coded_bits(:);

    % =====================================================================
    % 1. Inner Decoding: Viterbi Decoder (Hard Decision)
    % =====================================================================
    tb_depth = conf.coding.traceback;
    viterbi_out = vitdec(rx_coded_bits, conf.coding.trellis, tb_depth, 'trunc', 'hard');

    % =====================================================================
    % 2. Outer Decoding: Reed-Solomon RS(n, k)
    % =====================================================================
    m = conf.coding.rs_m;
    n = conf.coding.rs_n;
    k = conf.coding.rs_k;
    
    % Group bits into GF(2^m) integer symbols
    num_bits = length(viterbi_out);
    valid_len = floor(num_bits / m) * m;
    viterbi_clean = viterbi_out(1:valid_len);
    
    rx_syms_int = bi2de(reshape(viterbi_clean, m, []).', 'left-msb');
    
    % Block alignment for RS codeword boundary (multiples of n)
    num_blocks = floor(length(rx_syms_int) / n);
    rx_syms_aligned = rx_syms_int(1 : num_blocks * n);
    
    if isempty(rx_syms_aligned)
        warning('channel_decoder:insufficientBits', 'Insufficient data for complete RS block.');
        decoded_bits = [];
        return;
    end

    % Execute RS decoding with fallback protection
    try
        rs_dec_int = rsdec(rx_syms_aligned, n, k);
    catch
        warning('channel_decoder:rsUncorrectable', 'RS decoding threshold exceeded. Passing systematic data.');
        % Fallback: Extract systematic data symbols directly from codeword
        matrix_syms = reshape(rx_syms_aligned, n, []);
        rs_dec_int = matrix_syms(1:k, :);
        rs_dec_int = rs_dec_int(:);
    end

    % =====================================================================
    % 3. Format Output Bits
    % =====================================================================
    decoded_bits_mat = de2bi(rs_dec_int, m, 'left-msb');
    decoded_bits = decoded_bits_mat.';
    decoded_bits = decoded_bits(:);
end