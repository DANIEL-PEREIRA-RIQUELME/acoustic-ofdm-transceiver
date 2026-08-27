% =========================================================================
% Acoustic OFDM Transceiver - End-to-End Simulation & Test Benchmark
% =========================================================================
% Description:
%   Demonstrates complete baseband acoustic OFDM transmission and reception:
%     1. Configuration initialization & frame structure creation.
%     2. Pseudo-random payload bit generation.
%     3. Transmitter: FEC encoding, QPSK mapping, IFFT, CP, preamble prepend,
%        and digital upconversion (fc = 8 kHz).
%     4. Channel propagation: software acoustic emulator (Channels 1 to 5) or
%        real soundcard DAC/ADC over-the-air transmission.
%     5. Receiver: downconversion, sliding cross-correlation synchronization,
%        two-stage CFO estimation, FFT demodulation, asymmetric LMMSE CIR windowing,
%        pilot-based phase tracking, and Viterbi FEC decoding.
%     6. Bit Error Rate (BER) evaluation and performance reporting.
%
% Wireless Receivers: Algorithms and Architectures
% Telecommunications Circuits Laboratory (TCL), EPFL
% =========================================================================

clear; close all; clc;
setpath();
set(0, 'DefaultFigureColor', 'w');

% --- 1. Load System Configuration ---
conf = configurations();

% Operational settings
conf.audiosystem  = 'emulator'; % 'emulator' (simulated) or 'audio' (real soundcard)
conf.emulator_idx = 1;          % Channel ID: 1 (AWGN), 2 (Phase Drift), 3 (High Delay), 4 (Band Rejection), 5 (Multipath)
conf.emulator_snr = 15;         % Channel SNR in dB
conf.verbose      = 1;          % 1: Display diagnostic plots; 0: Silent console mode

fprintf('============================================================\n');
fprintf('        EPFL EE-442 ACOUSTIC OFDM TRANSCEIVER DEMO          \n');
fprintf('============================================================\n');
fprintf(' Mode: %s | Channel ID: %d | SNR: %d dB\n', conf.audiosystem, conf.emulator_idx, conf.emulator_snr);
fprintf(' Modulation: %s | FEC: %s\n', ...
    iif(conf.modulation_order==2, 'QPSK', '16-QAM'), ...
    iif(conf.coding.use_fec, 'Enabled (Rate 1/2 Conv + RS)', 'Disabled'));

% --- 2. Frame Geometry & Payload Initialization ---
global ofdmc;
ofdmConfig();

n_bits = ofdmc.nDataBits;
if isfield(conf, 'coding') && conf.coding.use_fec
    n_bits = floor(n_bits / 2); % Half payload capacity for Rate 1/2 code
end

data_bits = randi([0, 1], n_bits, 1);

% --- 3. Physical Layer Transmission ---
fprintf('\n[TX] Synthesizing passband OFDM waveform...\n');
tx_signal = transmitter(data_bits, ofdmc.preamble, conf)';

% Add 1-second guard silence before and after transmission
tx_signal_raw = [zeros(conf.f_s, 1); tx_signal; zeros(conf.f_s, 1)];

% --- 4. Channel Propagation ---
switch lower(conf.audiosystem)
    case 'emulator'
        fprintf('[Channel] Passing signal through acoustic emulator (Model %d)...\n', conf.emulator_idx);
        rx_signal = channel_emulator(tx_signal_raw, conf);
        
    case 'audio'
        fprintf('[Audio] Transmitting over-the-air via loudspeaker and recording via microphone...\n');
        txdur = length(tx_signal_raw) / conf.f_s;
        audiowrite('data/out_tx.wav', tx_signal_raw, conf.f_s);
        
        playobj = audioplayer(tx_signal_raw, conf.f_s, conf.bitsps);
        recobj  = audiorecorder(conf.f_s, conf.bitsps, 1);
        record(recobj);
        pause(1.0);
        playblocking(playobj);
        pause(1.0);
        stop(recobj);
        
        raw_rx = getaudiodata(recobj, 'int16');
        rx_signal = double(raw_rx) / double(intmax('int16'));
end

% --- 5. Digital Receiver Processing ---
fprintf('[RX] Processing received waveform...\n');
est_bits = receiver(rx_signal, ofdmc.preamble, conf);

% --- 6. Performance Evaluation ---
fprintf('\n============================================================\n');
fprintf('                   TRANSMISSION RESULTS                     \n');
fprintf('============================================================\n');
if isempty(est_bits)
    fprintf(' Status: [FAILED] Preamble synchronization not achieved.\n');
else
    n_compare = min(length(est_bits), length(data_bits));
    bit_errors = sum(est_bits(1:n_compare) ~= data_bits(1:n_compare));
    ber = bit_errors / n_compare;
    
    fprintf(' Transmitted Bits : %d\n', length(data_bits));
    fprintf(' Decoded Bits     : %d\n', length(est_bits));
    fprintf(' Bit Errors       : %d\n', bit_errors);
    fprintf(' Bit Error Rate   : %.6f (%.3f%%)\n', ber, ber * 100);
    
    if ber == 0
        fprintf(' Link Quality     : [EXCELLENT] Perfect Error-Free Transmission (BER = 0)\n');
    elseif ber < 1e-3
        fprintf(' Link Quality     : [GOOD] Below Quasi-Error-Free Target (BER < 1e-3)\n');
    else
        fprintf(' Link Quality     : [DEGRADED] Channel impairments exceed correction limits\n');
    end
end
fprintf('============================================================\n');

% Inline conditional helper
function out = iif(cond, val_true, val_false)
    if cond, out = val_true; else, out = val_false; end
end
