function [lambda_LMMSE, metrics] = ChannelMetrics(lambda_LS, ofdmc, conf)
% CHANNELMETRICS Asymmetric Windowed LMMSE Channel Estimator & ISI Metric Suite.
%
%   [lambda_LMMSE, metrics] = CHANNELMETRICS(lambda_LS, ofdmc, conf)
%
%   Refines the noisy Least Squares (LS) frequency-domain channel estimate
%   using a practical time-domain CIR circular windowing technique (LMMSE approximation):
%     1. Converts frequency-domain H_LS to the Channel Impulse Response (CIR) via IFFT.
%     2. Centers the peak tap (cursor) at N/2 using circular shift to handle
%        boundary wrap-around and synchronization offsets.
%     3. Applies an asymmetric time-domain window:
%        - Retains `conf.ch.back` taps before the cursor (pre-cursors).
%        - Retains `conf.ch.length` taps starting from cursor (post-cursors).
%        - Zeroes out all remaining taps, effectively suppressing noise outside
%          the actual physical channel delay spread.
%     4. Restores original circular shift and converts back to frequency domain via FFT.
%     5. Computes analytical Inter-Symbol Interference (ISI) metrics:
%        - Peak Distortion: D_peak = sum_{k != d} |h[k]| / |h[d]|
%        - Robustness Factor: eta = (d_min / 2) / |A_max|
%        - Total ISI Ratio: gamma_isi = D_peak / eta (gamma < 1 ensures open eye diagram).
%
% Inputs:
%   lambda_LS    - Raw Least Squares channel estimate vector.
%   ofdmc        - Global OFDM system structure.
%   conf         - Configuration structure containing CIR window lengths (.ch.length, .ch.back).
%
% Outputs:
%   lambda_LMMSE - Noise-suppressed frequency-domain channel response.
%   metrics      - Struct with fields: .D_peak, .gamma_isi, .eta.
%
% Wireless Receivers: Algorithms and Architectures
% Telecommunications Circuits Laboratory (TCL), EPFL

    % =====================================================================
    % 1. Frequency to Time-Domain Transformation (Noisy CIR)
    % =====================================================================
    H_LS_full = zeros(ofdmc.nCarriers, 1);
    active_idx = find(ofdmc.psdMask);
    H_LS_full(active_idx) = lambda_LS;
    
    h_LS = ifft(H_LS_full);
    N = length(h_LS);
    
    % =====================================================================
    % 2. Circular Shift Energy Centering
    % =====================================================================
    [max_pwr, idx_peak] = max(abs(h_LS).^2);
    center_idx = floor(N / 2);
    shift_amount = center_idx - idx_peak;
    
    h_centered = circshift(h_LS, shift_amount);
    
    % =====================================================================
    % 3. Asymmetric Windowing (Noise Truncation)
    % =====================================================================
    len_fwd  = 15;
    len_back = 2;
    if isfield(conf, 'ch')
        if isfield(conf.ch, 'length'), len_fwd  = conf.ch.length; end
        if isfield(conf.ch, 'back'),   len_back = conf.ch.back;   end
    end
    
    idx_start = max(1, center_idx - len_back);
    idx_end   = min(N, center_idx + len_fwd - 1);
    
    mask_keep = false(N, 1);
    mask_keep(idx_start : idx_end) = true;
    
    h_centered_clean = h_centered;
    h_centered_clean(~mask_keep) = 0;
    
    % =====================================================================
    % 4. Restore Shift & Transform to Frequency Domain
    % =====================================================================
    h_LMMSE = circshift(h_centered_clean, -shift_amount);
    H_LMMSE_full = fft(h_LMMSE);
    lambda_LMMSE = H_LMMSE_full(active_idx); 
    
    % =====================================================================
    % 5. Inter-Symbol Interference (ISI) Quantification
    % =====================================================================
    h_clean_norm = abs(h_LMMSE) / sqrt(max_pwr);
    isi_sum = sum(h_clean_norm) - 1; 
    D_peak = max(0, isi_sum);
    
    switch lower(ofdmc.constellationType)
        case 'qam', constellation = qamMap(ofdmc.M);
        case 'psk', constellation = pskMap(ofdmc.M);
        otherwise,  constellation = qamMap(4);
    end
    A_max = max(abs(constellation));
    dist_mat = abs(constellation - constellation.');
    dist_mat(dist_mat == 0) = inf;
    d_min = min(dist_mat(:));
    
    eta = (d_min / 2) / A_max;
    gamma_isi = D_peak / eta;

    metrics.D_peak    = D_peak;
    metrics.gamma_isi = gamma_isi;
    metrics.eta       = eta;

    % =====================================================================
    % 6. Optional Diagnostics & Plotting
    % =====================================================================
    if isfield(conf, 'verbose') && conf.verbose
        figure('Name', 'LMMSE Channel Estimation Diagnostic', 'Color', 'w');
        
        subplot(2, 2, 1);
        stem(1:N, abs(h_centered), 'Color', [0.8 0.8 0.8], 'Marker', '.'); hold on;
        stem(1:N, abs(h_centered_clean), 'b', 'LineWidth', 1.2, 'Marker', 'none');
        xline(idx_start, 'r--', 'Back Cutoff');
        xline(idx_end, 'r--', 'Fwd Cutoff');
        xline(center_idx, 'k:', 'Peak (Cursor)');
        title('Centered Impulse Response'); xlabel('Shifted Index'); ylabel('Magnitude');
        grid on; xlim([center_idx - len_back - 20, center_idx + len_fwd + 20]);
        
        subplot(2, 2, 2);
        stem(0:N-1, abs(h_LS), 'Color', [0.8 0.8 0.8], 'Marker', '.'); hold on;
        stem(0:N-1, abs(h_LMMSE), 'b', 'LineWidth', 1.2, 'Marker', 'none');
        title('Restored CIR (Circular)'); xlabel('Tap Index [n]'); grid on; xlim([0 N]);
        
        subplot(2, 2, [3, 4]);
        f_axis = (-ofdmc.nCarriers/2 : ofdmc.nCarriers/2 - 1);
        plot(f_axis, abs(fftshift(H_LS_full)), 'Color', [0.7 0.7 0.7], 'DisplayName', 'Raw LS (Noisy)'); hold on;
        plot(f_axis, abs(fftshift(H_LMMSE_full)), 'b-', 'LineWidth', 1.5, 'DisplayName', 'LMMSE (Windowed)');
        title('Channel Frequency Response |H(f)|'); xlabel('Subcarrier Index'); ylabel('Gain');
        grid on; legend('Location', 'Best'); xlim([min(f_axis) max(f_axis)]);

        fprintf('\n--- Asymmetric LMMSE Channel Estimation Report ---\n');
        fprintf('  Pre-cursor Window (Back)  : %d taps\n', len_back);
        fprintf('  Post-cursor Window (Fwd)  : %d taps\n', len_fwd);
        fprintf('  Peak Distortion (D_peak)  : %.4f\n', D_peak);
        fprintf('  ISI Ratio (gamma_isi)     : %.4f\n', gamma_isi);
        if gamma_isi < 1
            fprintf('  Eye Diagram Status        : OPEN (gamma_isi < 1)\n');
        else
            fprintf('  Eye Diagram Status        : CLOSED (gamma_isi >= 1)\n');
        end
        fprintf('--------------------------------------------------\n');
    end
end