function [start_idx, cfo_est] = estimateTauAndCFO(preamble, received, os_factor, thr, T, cfo_range, conf)
% ESTIMATETAUANDCFO Detects frame arrival and estimates Carrier Frequency Offset.
%
%   [start_idx, cfo_est] = ESTIMATETAUANDCFO(preamble, received, os_factor, ...
%       thr, T, cfo_range, conf)
%
%   Executes robust time and frequency synchronization:
%     1. Packet Detection: Evaluates energy-normalized sliding cross-correlation
%        M(d) between the received baseband signal and the known RRC-filtered preamble.
%     2. Timing Synchronization: Identifies peak above detection threshold `thr`
%        to pinpoint the exact sample marking the end of the preamble.
%     3. Coarse CFO Estimation: Evaluates frequency correlation across a Doppler
%        grid spanning `cfo_range` to find maximum spectral correlation.
%     4. Fine CFO Estimation: Applies a 3-point parabolic/quadratic interpolation
%        around the coarse peak to achieve sub-Hertz CFO estimation accuracy.
%
% Inputs:
%   preamble  - Reference BPSK preamble sequence (at symbol rate).
%   received  - Received oversampled baseband signal.
%   os_factor - Preamble oversampling factor (Fs / Fsym).
%   thr       - Normalized correlation threshold for frame detection.
%   T         - Audio sampling period (1 / Fs).
%   cfo_range - Grid of frequency hypotheses for coarse search [Hz].
%   conf      - Configuration structure (optional, for plotting).
%
% Outputs:
%   start_idx - Sample index marking the end of the preamble (start of OFDM payload).
%   cfo_est   - Estimated Carrier Frequency Offset [Hz].
%
% References:
%   - Schmidl & Cox, "Robust Frequency and Timing Synchronization for OFDM",
%     IEEE Transactions on Communications, 1997.
%
% Wireless Receivers: Algorithms and Architectures
% Telecommunications Circuits Laboratory (TCL), EPFL

    global ofdmc;
    if nargin < 7
        conf.verbose = false;
    end

    Np = length(preamble);
    Np_u = os_factor * Np;
    Nr = length(received);
    
    c_norm = zeros(Nr - Np_u - 1, 1);
    start_idx = -1;
    cfo_est = 0;

    % =====================================================================
    % 1. Energy-Normalized Sliding Cross-Correlation
    % =====================================================================
    for i = Np_u + 1 : Nr
        r_chunk = received(i - Np_u : os_factor : i - os_factor);
        
        energy = abs(r_chunk' * r_chunk);
        if energy == 0, energy = eps; end
        
        c = preamble' * r_chunk;
        c_norm(i - Np_u) = abs(c)^2 / energy; 

        % Threshold check with latency lag
        check_idx = i - Np_u - os_factor + 1;
        
        if (i >= Np_u + os_factor + 1) && (c_norm(check_idx) > thr)
            % Peak localization within observation window
            window_indices = check_idx : (i - Np_u);
            [max_val, rel_idx] = max(c_norm(window_indices));
            
            peak_idx_corr = window_indices(1) + rel_idx - 1; 
            start_idx = i - os_factor + rel_idx; 
            
            % =============================================================
            % 2. Two-Stage Carrier Frequency Offset (CFO) Estimation
            % =============================================================
            % Extract synchronized preamble chunk
            idx_start = start_idx - Np_u + 1;
            rx_chunk_up = received(idx_start : start_idx);
            
            % Downsample to symbol rate
            rx_chunk = rx_chunk_up(1:os_factor:end);
            t = (0:length(rx_chunk)-1)' * T;
            
            % A. Coarse Search over Grid
            ip_coarse = zeros(size(cfo_range));
            for d = 1:numel(cfo_range)
                rx_rot = rx_chunk .* exp(-1j * 2 * pi * cfo_range(d) * t);
                ip_coarse(d) = abs(rx_rot' * preamble);
            end
            
            [~, idx_max] = max(ip_coarse);
            cfo_coarse = cfo_range(idx_max);
            
            % B. Fine Parabolic Interpolation
            if isempty(ofdmc), ofdmConfig(); end
            step = ofdmc.fCorr;
            cfo_fine_grid = cfo_coarse + [-1; 0; 1] * step;
            ip_fine = zeros(3, 1);
            
            for k = 1:3
                rx_rot = rx_chunk .* exp(-1j * 2 * pi * cfo_fine_grid(k) * t);
                ip_fine(k) = abs(rx_rot' * preamble);
            end
            
            % Fit quadratic curve: y = a*f^2 + b*f + c
            X = [cfo_fine_grid.^2, cfo_fine_grid, ones(3, 1)];
            abc = X \ ip_fine;
            
            if abc(1) < 0 % Valid concave parabola
                cfo_est = -abc(2) / (2 * abc(1));
            else
                cfo_est = cfo_coarse;
            end

            if conf.verbose
                fprintf('[Sync] Frame detected at sample %d (Metric: %.2f)\n', start_idx, max_val);
                fprintf('[Sync] Estimated CFO: %.2f Hz\n', cfo_est);
                plot_sync_metrics(received, c_norm, start_idx, peak_idx_corr, thr);
            end
            return;
        end
    end

    if start_idx < 0
        if isfield(conf, 'verbose') && conf.verbose
            warning('estimateTauAndCFO:NotFound', 'Frame synchronization preamble not detected.');
            plot_sync_metrics(received, c_norm, -1, -1, thr);
        end
    end
end

% Helper function for synchronization visualization
function plot_sync_metrics(received, c_norm, start_idx, peak_idx, thr)
    figure('Name', 'Synchronization Metrics', 'Color', 'w');
    
    subplot(2, 1, 1);
    plot(abs(received), 'Color', [0.2 0.2 0.8]); hold on;
    if start_idx > 0
        xline(start_idx, 'r-', 'LineWidth', 2);
        plot(start_idx, abs(received(start_idx)), 'ro', 'MarkerFaceColor', 'r');
        text(start_idx, max(abs(received))*0.9, ' Preamble End', 'Color', 'r', 'FontWeight', 'bold');
    end
    title('Received Signal Magnitude'); ylabel('Amplitude'); grid on;
    xlim([1 length(received)]);

    subplot(2, 1, 2);
    plot(c_norm, 'k', 'LineWidth', 1.5); hold on;
    yline(thr, 'b--', 'Detection Threshold', 'LineWidth', 1.2);
    if peak_idx > 0
        plot(peak_idx, c_norm(peak_idx), 'p', 'MarkerSize', 12, 'MarkerFaceColor', 'g');
        xlim([max(1, peak_idx-300), min(length(c_norm), peak_idx+300)]);
    end
    title('Energy-Normalized Correlation Metric M(d)'); ylabel('Metric'); grid on;
end