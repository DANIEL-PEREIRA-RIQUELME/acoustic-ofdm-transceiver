% =========================================================================
% Acoustic OFDM Transceiver - BER / PER / Throughput Performance Suite
% =========================================================================
% Description:
%   Automated Monte-Carlo simulation suite evaluating:
%     1. Bit Error Rate (BER) Waterfall curves (Uncoded vs. Concatenated FEC).
%     2. Packet Error Rate (PER) vs SNR.
%     3. Effective Useful Throughput (Goodput in bits/packet).
%
% Wireless Receivers: Algorithms and Architectures
% Telecommunications Circuits Laboratory (TCL), EPFL
% =========================================================================

clear; close all; clc;
setpath();

% --- 1. Simulation Setup ---
SNR_dB_range = -14:2:10;    % SNR test sweep [dB]
N_PACKETS    = 15;          % Packets evaluated per SNR point
CH_MODEL     = 1;           % Channel Model (1: AWGN, 2: Phase, 5: Multipath)

fprintf('============================================================\n');
fprintf('     EPFL EE-442 OFDM PERFORMANCE BENCHMARK SUITE          \n');
fprintf('============================================================\n');
fprintf(' SNR Range: [%d dB to %d dB] | Packets/point: %d | Channel: %d\n', ...
    min(SNR_dB_range), max(SNR_dB_range), N_PACKETS, CH_MODEL);
fprintf('------------------------------------------------------------\n');

global ofdmc;
conf = configurations();
ofdmConfig();

conf.audiosystem  = 'emulator';
conf.emulator_idx = CH_MODEL;
conf.verbose      = false;

% Preallocate results structure
results = struct();
results.snr         = SNR_dB_range;
results.ber_uncoded = zeros(size(SNR_dB_range));
results.ber_coded   = zeros(size(SNR_dB_range));
results.per_uncoded = zeros(size(SNR_dB_range));
results.per_coded   = zeros(size(SNR_dB_range));
results.thr_uncoded = zeros(size(SNR_dB_range));
results.thr_coded   = zeros(size(SNR_dB_range));

preamble = ofdmc.preamble;

% Suppress popup windows during batch simulation
set(0, 'DefaultFigureVisible', 'off');

try
    for i_snr = 1:length(SNR_dB_range)
        curr_snr = SNR_dB_range(i_snr);
        conf.emulator_snr = curr_snr;
        fprintf('Testing SNR: %3d dB | ', curr_snr);
        
        % -----------------------------------------------------------------
        % PART A: UNCODED TRANSMISSION
        % -----------------------------------------------------------------
        conf.coding.use_fec = false;
        err_bits = 0; tot_bits = 0; err_pkts = 0;
        
        for k = 1:N_PACKETS
            tx_bits = randi([0, 1], ofdmc.nDataBits, 1);
            [rx_bits, success] = run_transmission_silent(tx_bits, preamble, conf);
            
            L = min(length(tx_bits), length(rx_bits));
            if L == 0 || ~success
                bit_diff = length(tx_bits);
            else
                bit_diff = sum(tx_bits(1:L) ~= rx_bits(1:L));
            end
            
            err_bits = err_bits + bit_diff;
            tot_bits = tot_bits + length(tx_bits);
            if bit_diff > 0 || ~success, err_pkts = err_pkts + 1; end
        end
        
        results.ber_uncoded(i_snr) = err_bits / max(tot_bits, 1);
        results.per_uncoded(i_snr) = err_pkts / N_PACKETS;
        results.thr_uncoded(i_snr) = (1 - results.per_uncoded(i_snr)) * ofdmc.nDataBits;
        fprintf('Uncoded BER: %.4e | ', results.ber_uncoded(i_snr));

        % -----------------------------------------------------------------
        % PART B: CODED TRANSMISSION (Concatenated FEC)
        % -----------------------------------------------------------------
        conf.coding.use_fec = true;
        err_bits = 0; tot_bits = 0; err_pkts = 0;
        n_useful = floor(ofdmc.nDataBits / 2);
        
        for k = 1:N_PACKETS
            tx_bits = randi([0, 1], n_useful, 1);
            [rx_bits, success] = run_transmission_silent(tx_bits, preamble, conf);
            
            L = min(length(tx_bits), length(rx_bits));
            if L == 0 || ~success
                bit_diff = length(tx_bits);
            else
                bit_diff = sum(tx_bits(1:L) ~= rx_bits(1:L));
            end
            
            err_bits = err_bits + bit_diff;
            tot_bits = tot_bits + length(tx_bits);
            if bit_diff > 0 || ~success, err_pkts = err_pkts + 1; end
        end
        
        results.ber_coded(i_snr) = err_bits / max(tot_bits, 1);
        results.per_coded(i_snr) = err_pkts / N_PACKETS;
        results.thr_coded(i_snr) = (1 - results.per_coded(i_snr)) * n_useful;
        fprintf('Coded BER: %.4e\n', results.ber_coded(i_snr));
    end
catch ME
    set(0, 'DefaultFigureVisible', 'on');
    rethrow(ME);
end

% Restore figure visibility for presentation
set(0, 'DefaultFigureVisible', 'on');
close all;

% --- 2. Visualization & Comparative Plotting ---
figure('Name', 'OFDM System Performance Benchmark', 'Position', [100, 150, 1100, 400]);

% Subplot 1: BER Waterfall
subplot(1, 3, 1);
semilogy(SNR_dB_range, max(results.ber_uncoded, 1e-5), '-o', 'LineWidth', 2, 'Color', '#D95319'); hold on;
semilogy(SNR_dB_range, max(results.ber_coded, 1e-5),   '-s', 'LineWidth', 2, 'Color', '#0072BD');
yline(1e-3, '--k', 'QEF Target (10^{-3})', 'LineWidth', 1.2);
grid on; title('Bit Error Rate (BER)', 'FontWeight', 'bold');
xlabel('SNR (dB)'); ylabel('BER (log scale)');
legend('Uncoded', 'Coded (Rate 1/2 + RS)', 'Location', 'SouthWest');
ylim([1e-5, 1]);

% Subplot 2: PER Packet Error Rate
subplot(1, 3, 2);
plot(SNR_dB_range, results.per_uncoded * 100, '-o', 'LineWidth', 2, 'Color', '#D95319'); hold on;
plot(SNR_dB_range, results.per_coded * 100,   '-s', 'LineWidth', 2, 'Color', '#0072BD');
grid on; title('Packet Error Rate (PER)', 'FontWeight', 'bold');
xlabel('SNR (dB)'); ylabel('Packet Loss (%)');
legend('Uncoded', 'Coded', 'Location', 'NorthEast');
ylim([-5, 105]);

% Subplot 3: Effective Useful Goodput
subplot(1, 3, 3);
b = bar(SNR_dB_range, [results.thr_uncoded(:), results.thr_coded(:)], 'grouped');
b(1).FaceColor = [0.85 0.33 0.10];
b(2).FaceColor = [0.00 0.45 0.74];
grid on; title('Useful Goodput', 'FontWeight', 'bold');
xlabel('SNR (dB)'); ylabel('Useful Bits / Packet');
legend('Uncoded', 'Coded', 'Location', 'NorthWest');

sgtitle('Acoustic OFDM Transceiver Performance & Coding Gain Analysis', 'FontSize', 13, 'FontWeight', 'bold');

% --- Helper Function ---
function [rx_bits, success] = run_transmission_silent(tx_bits, preamble, conf)
    try
        tx_sig = transmitter(tx_bits, preamble, conf)';
        n_pad = round(conf.f_s * 0.05);
        tx_raw = [zeros(n_pad, 1); tx_sig(:); zeros(n_pad, 1)];
        rx_raw = channel_emulator(tx_raw, conf);
        rx_bits = receiver(rx_raw, preamble, conf);
        success = ~isempty(rx_bits);
    catch
        rx_bits = [];
        success = false;
    end
end
