function coded_bits = channel_encoder(raw_bits, conf)
% CHANNEL_ENCODER Implements Concatenated Forward Error Correction (FEC).
%
%   coded_bits = CHANNEL_ENCODER(raw_bits, conf) encodes information bits
%   using a synergistic two-tier concatenated coding scheme:
%     1. Outer Code: Reed-Solomon RS(255, 239) over Galois Field GF(2^8).
%        Corrects burst errors escaping the inner convolutional decoder.
%     2. Inner Code: Rate 1/2 Convolutional Code (K=7, polynomials [171, 133]).
%        Suppresses the channel noise floor.
%
% Inputs:
%   raw_bits   - Binary column vector containing unencoded information bits.
%   conf       - Master configuration structure containing .coding parameters:
%                  .rs_n    (e.g., 255)
%                  .rs_k    (e.g., 239)
%                  .rs_m    (e.g., 8)
%                  .trellis (e.g., poly2trellis(7, [171 133]))
%
% Outputs:
%   coded_bits - Encoded binary column vector ready for constellation mapping.
%
% References:
%   - Lin & Costello, "Error Control Coding: Fundamentals and Applications", 
%     Prentice-Hall, 2004.
%
% Wireless Receivers: Algorithms and Architectures
% Telecommunications Circuits Laboratory (TCL), EPFL

    if ~isfield(conf, 'coding')
        error('channel_encoder:MissingConf', 'Configuration structure must include the .coding field.');
    end

    raw_bits = raw_bits(:);

    % =====================================================================
    % 1. Outer Encoder: Reed-Solomon RS(n, k)
    % =====================================================================
    m = conf.coding.rs_m;
    n = conf.coding.rs_n;
    k = conf.coding.rs_k;

    % Bit-to-symbol alignment (padding to integer multiple of m bits)
    num_bits = length(raw_bits);
    pad_bits = mod(m - mod(num_bits, m), m);
    if pad_bits == m, pad_bits = 0; end
    bits_padded = [raw_bits; zeros(pad_bits, 1)];
    
    % Group into GF(2^m) integer symbols
    syms_int = bi2de(reshape(bits_padded, m, []).', 'left-msb');
    
    % Block alignment (padding to integer multiple of k RS symbols)
    num_syms = length(syms_int);
    pad_syms = mod(k - mod(num_syms, k), k);
    if pad_syms == k, pad_syms = 0; end
    syms_padded = [syms_int; zeros(pad_syms, 1)];
    
    % Execute RS encoding
    rs_enc_int = rsenc(syms_padded, n, k);
    
    % Convert RS symbols back to binary bitstream
    rs_bits_mat = de2bi(rs_enc_int, m, 'left-msb');
    rs_bits = rs_bits_mat.';
    rs_bits = rs_bits(:);

    % =====================================================================
    % 2. Inner Encoder: Rate 1/2 Convolutional Code
    % =====================================================================
    coded_bits = convenc(rs_bits, conf.coding.trellis);
end