% =========================================================================
% Acoustic OFDM Transceiver - Channel Equalization Strategy Analysis
% =========================================================================
% Description:
%   Evaluates BER vs SNR performance across various equalization techniques:
%     1. No Equalization (Raw demodulation)
%     2. Standard Frequency-Domain Least Squares (LS)
%     3. Practical Circular Windowed LMMSE across multiple CIR window lengths
%        (L = 5, 15, 25, 150 taps)
%
% Wireless Receivers: Algorithms and Architectures
% Telecommunications Circuits Laboratory (TCL), EPFL
% =========================================================================

clear; close all; clc;
setpath();
set(0, 'DefaultFigureColor', 'w');

% --- 1. Simulation Parameters ---
snr_range_dB       = 0:2:20;  % SNR sweep range [dB]
n_frames_per_point = 10;      % Frames averaged per SNR point
ch_model_idx       = 5;       % Multipath Channel (5)

% Define equalization test curves
curves = [ ...
    struct('name', 'No Equalization', 'mode', 0, 'len', 0), ...
    struct('name', 'Least Squares (LS)', 'mode', 1, 'len', 0), ...
    struct('name', 'Windowed LMMSE (L=5)',   'mode', 2, 'len', 5), ...
    struct('name', 'Windowed LMMSE (L=15)',  'mode', 2, 'len', 15), ...
    struct('name', 'Windowed LMMSE (L=25)',  'mode', 2, 'len', 25), ...
    struct('name', 'Windowed LMMSE (L=150)', 'mode', 2, 'len', 150) ...
];

ber_results = zeros(length(snr_range_dB), length(curves));

% --- 2. Load Base Configuration ---
conf = configurations();
conf.audiosystem  = 'emulator';
conf.emulator_idx = ch_model_idx;
conf.verbose      = 0;

global ofdmc;
ofdmConfig();

n_bits_total = ofdmc.nDataBits;
if isfield(conf, 'coding') && conf.coding.use_fec
    n_bits_total = floor(n_bits_total / 2);
end

fprintf('============================================================\n');
fprintf('     EQUALIZATION STRATEGY BENCHMARK (CHANNEL %d)           \n', ch_model_idx);
fprintf('============================================================\n');
fprintf('%-10s | %-24s | %-12s\n', 'SNR (dB)', 'Equalizer Strategy', 'BER');
fprintf('------------------------------------------------------------\n');

% --- 3. Monte-Carlo Evaluation Loop ---
for i_snr = 1:length(snr_range_dB)
    curr_snr = snr_range_dB(i_snr);
    conf.emulator_snr = curr_snr;
    
    for i_curve = 1:length(curves)
        conf.eq.mode   = curves(i_curve).mode;
        conf.ch.length = curves(i_curve).len;
        
        cumulative_errors = 0;
        total_bits_checked = 0;
        
        for i_frame = 1:n_frames_per_point
            data_bits = randi([0, 1], n_bits_total, 1);
            tx_signal = transmitter(data_bits, ofdmc.preamble, conf)';
            tx_raw = [zeros(conf.f_s, 1); tx_signal; zeros(conf.f_s, 1)];
            
            rx_signal = channel_emulator(tx_raw, conf);
            est_bits  = receiver(rx_signal, ofdmc.preamble, conf);
            
            if ~isempty(est_bits)
                n_comp = min(length(est_bits), length(data_bits));
                errs = sum(est_bits(1:n_comp) ~= data_bits(1:n_comp));
                cumulative_errors = cumulative_errors + errs;
                total_bits_checked = total_bits_checked + n_comp;
            else
                cumulative_errors = cumulative_errors + floor(n_bits_total / 2);
                total_bits_checked = total_bits_checked + n_bits_total;
            end
        end
        
        avg_ber = cumulative_errors / total_bits_checked;
        ber_results(i_snr, i_curve) = avg_ber;
        fprintf('%-10.1f | %-24s | %-1.2e\n', curr_snr, curves(i_curve).name, avg_ber);
    end
    fprintf('------------------------------------------------------------\n');
end

% --- 4. Plot Comparison Curves ---
figure('Name', 'Equalization Strategies Comparison', 'Position', [150, 150, 850, 500]);
markers = {'o--', 's-', 'd-', '^-', 'v-', 'x-'};
colors  = lines(length(curves));

for i_curve = 1:length(curves)
    semilogy(snr_range_dB, max(ber_results(:, i_curve), 1e-5), markers{i_curve}, ...
        'LineWidth', 1.8, 'DisplayName', curves(i_curve).name, 'Color', colors(i_curve, :));
    hold on;
end

grid on;
xlabel('SNR (dB)', 'FontSize', 11);
ylabel('Bit Error Rate (BER)', 'FontSize', 11);
title(sprintf('Channel %d Equalization Benchmark: LS vs Asymmetric LMMSE CIR Windowing', ch_model_idx), ...
    'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'SouthWest', 'FontSize', 10);
axis([min(snr_range_dB), max(snr_range_dB), 1e-5, 1]);
