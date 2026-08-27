% =========================================================================
% Acoustic OFDM Transceiver - Multi-Frame Image Transmission Benchmark
% =========================================================================
% Description:
%   Demonstrates robust real-world multi-frame transmission of a 2D bitmap image.
%     1. Loads test bitmap image and flattens pixel byte stream into bit payload.
%     2. Fragments image into 10 independent OFDM frames (each with dedicated
%        preamble, training symbol, and pilot tracking) to adapt to time-varying
%        acoustic channel multipath and Doppler drifts.
%     3. Transmits frames sequentially over software emulator or acoustic soundcard.
%     4. Demodulates, equalizes (LMMSE), and applies Viterbi FEC decoding.
%     5. Reconstructs 2D image matrix, calculates exact end-to-end BER, and
%        renders side-by-side comparison of original vs received image.
%
% Wireless Receivers: Algorithms and Architectures
% Telecommunications Circuits Laboratory (TCL), EPFL
% =========================================================================

clear; close all; clc;
setpath();
set(0, 'DefaultFigureColor', 'w');

% --- 1. Load System Configuration ---
conf = configurations();
conf.audiosystem  = 'emulator'; % 'emulator' or 'audio'
conf.emulator_idx = 2;          % Channel ID
conf.emulator_snr = 15;         % Channel SNR [dB]
conf.verbose      = 0;          % Keep console clean during multi-frame execution

fprintf('============================================================\n');
fprintf('     EPFL EE-442 ACOUSTIC OFDM IMAGE TRANSMISSION DEMO      \n');
fprintf('============================================================\n');

global ofdmc;
ofdmConfig();

n_bits_per_frame = ofdmc.nDataBits;
if isfield(conf, 'coding') && conf.coding.use_fec
    n_bits_per_frame = floor(n_bits_per_frame / 2);
end

% --- 2. Load & Prepare Image Data ---
image_path = fullfile('data', 'test-image.bmp');
if ~exist(image_path, 'file')
    image_path = fullfile('data', 'test_image.bmp');
end

img = imread(image_path);
img_reduced = imresize(img, 0.1);  % Scale down for fast demonstration
img_size = size(img_reduced);
img_bits = reshape(de2bi(img_reduced(:), 'left-msb', 8)', [], 1);

total_payload_bits = numel(img_bits);
frames_needed = ceil(total_payload_bits / n_bits_per_frame);
received_bits_total = zeros(frames_needed * n_bits_per_frame, 1);

fprintf(' Image Resolution   : %d x %d (%d channels)\n', img_size(1), img_size(2), img_size(3));
fprintf(' Total Payload Bits : %d bits\n', total_payload_bits);
fprintf(' Frame Capacity     : %d bits/frame\n', n_bits_per_frame);
fprintf(' Total Frames       : %d frames\n', frames_needed);
fprintf(' Channel Model      : %d | SNR: %d dB\n', conf.emulator_idx, conf.emulator_snr);
fprintf('------------------------------------------------------------\n');

% --- 3. Sequential Frame Transmission Loop ---
for frame_idx = 1:frames_needed
    fprintf(' Transmitting Frame [%2d / %2d] ... ', frame_idx, frames_needed);
    
    % Slice payload segment
    bit_start = (frame_idx - 1) * n_bits_per_frame + 1;
    bit_end   = min(frame_idx * n_bits_per_frame, total_payload_bits);
    
    payload_segment = img_bits(bit_start : bit_end);
    % Zero-pad last frame if necessary
    frame_tx_bits = [payload_segment; zeros(n_bits_per_frame - length(payload_segment), 1)];

    % Synthesize passband waveform
    tx_signal = transmitter(frame_tx_bits, ofdmc.preamble, conf)';
    tx_signal_raw = [zeros(200, 1); tx_signal; zeros(200, 1)];

    % Channel propagation
    switch lower(conf.audiosystem)
        case 'emulator'
            rx_signal = channel_emulator(tx_signal_raw, conf);
        case 'audio'
            playobj = audioplayer(tx_signal_raw, conf.f_s, conf.bitsps);
            recobj  = audiorecorder(conf.f_s, conf.bitsps, 1);
            record(recobj);
            pause(0.5);
            playblocking(playobj);
            pause(0.5);
            stop(recobj);
            raw_rx = getaudiodata(recobj, 'int16');
            rx_signal = double(raw_rx) / double(intmax('int16'));
    end

    % Receiver demodulation
    est_frame_bits = receiver(rx_signal, ofdmc.preamble, conf);

    if isempty(est_frame_bits)
        fprintf('[SYNC FAILED]\n');
        received_bits_total(bit_start : bit_start + n_bits_per_frame - 1) = zeros(n_bits_per_frame, 1);
    else
        n_store = min(length(est_frame_bits), n_bits_per_frame);
        received_bits_total(bit_start : bit_start + n_store - 1) = est_frame_bits(1:n_store);
        
        frame_errors = sum(est_frame_bits(1:length(payload_segment)) ~= payload_segment);
        fprintf('[OK] (Errors: %d)\n', frame_errors);
    end
end

% --- 4. Reconstruct Received Image ---
received_bits_clean = received_bits_total(1 : total_payload_bits);
received_bytes = bi2de(reshape(received_bits_clean, 8, [])', 'left-msb');
received_img = uint8(reshape(received_bytes, img_size));

total_bit_errors = sum(received_bits_clean ~= img_bits);
overall_ber = total_bit_errors / total_payload_bits;

fprintf('\n============================================================\n');
fprintf('                   RECONSTRUCTION REPORT                    \n');
fprintf('============================================================\n');
fprintf(' Total Bits Evaluated : %d\n', total_payload_bits);
fprintf(' Total Bit Errors     : %d\n', total_bit_errors);
fprintf(' Overall System BER   : %.6f (%.3f%%)\n', overall_ber, overall_ber * 100);
fprintf(' Output File Saved    : data/received_image.bmp\n');
fprintf('============================================================\n');

% Save output reconstructed image
imwrite(received_img, fullfile('data', 'received_image.bmp'));

% Render Side-by-Side Figure
figure('Name', 'Acoustic OFDM Image Transmission Result', 'Position', [150, 200, 800, 400]);
subplot(1, 2, 1);
imshow(img_reduced);
title('Transmitted Original Image', 'FontSize', 12, 'FontWeight', 'bold');

subplot(1, 2, 2);
imshow(received_img);
title(sprintf('Received Image (BER: %.4f)', overall_ber), 'FontSize', 12, 'FontWeight', 'bold');
