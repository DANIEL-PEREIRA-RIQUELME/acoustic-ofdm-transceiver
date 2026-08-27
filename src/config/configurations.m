function conf = configurations()
% CONFIGURATIONS Central configuration structure for the acoustic OFDM transceiver.
%
%   conf = CONFIGURATIONS() returns a structure containing physical layer,
%   framing, modulation, synchronization, channel emulation, equalization,
%   and Forward Error Correction (FEC) parameters.
%
% Outputs:
%   conf - Master configuration structure with fields:
%          .audiosystem    - Transmission mode: 'emulator' (simulated channel) or 
%                            'audio' (real-time soundcard DAC/ADC).
%          .emulator_idx   - Channel model index (1 to 5).
%          .emulator_snr   - Channel Signal-to-Noise Ratio [dB].
%          .verbose        - Diagnostic verbosity flag (0: silent, 1: plots & logs).
%          .f_s            - Audio sampling frequency [Hz] (48 kHz).
%          .f_c            - Carrier frequency [Hz] (8 kHz).
%          .bitsps         - Audio bit depth (16 bits/sample).
%          .sc             - Single-carrier preamble & pulse-shaping parameters.
%          .ofdm           - Multicarrier grid & bandwidth parameters.
%          .modulation_order - Bits per constellation symbol (e.g., 2 for QPSK).
%          .coding         - Concatenated FEC configuration (Reed-Solomon + Convolutional).
%          .preamble       - Frame detection correlation threshold.
%          .ch             - Asymmetric LMMSE CIR windowing parameters.
%          .eq             - Equalization mode (0: None, 1: LS, 2: Windowed LMMSE).
%
% Wireless Receivers: Algorithms and Architectures
% Telecommunications Circuits Laboratory (TCL), EPFL

    global conf;

    % =====================================================================
    % 1. Operational Mode & Diagnostics
    % =====================================================================
    % Options:
    %   'emulator' : Use software acoustic channel emulator (Channels 1 - 5)
    %   'audio'    : Real over-the-air transmission via PC speaker & microphone
    conf.audiosystem  = 'emulator'; 
    conf.emulator_idx = 1;        % Channel ID: 1 (AWGN), 2 (Phase Drift), 3 (Long Delay), 4 (Band Notch), 5 (Multipath)
    conf.emulator_snr = 15;       % Emulator SNR in dB
    conf.verbose      = 0;        % 0: Minimal console output; 1: Full diagnostic plots

    % =====================================================================
    % 2. System Sampling & RF / Acoustic Passband Parameters
    % =====================================================================
    conf.f_s    = 48000;          % Audio hardware sampling rate [Hz]
    conf.f_c    = 8000;           % Acoustic carrier frequency [Hz]
    conf.bitsps = 16;             % Audio resolution (bits per sample)

    % =====================================================================
    % 3. Single-Carrier Synchronization Preamble (RRC-Filtered BPSK)
    % =====================================================================
    conf.sc.f_sym         = 1000; % Preamble symbol rate [Baud]
    conf.sc.nsyms         = 500;  % Number of preamble symbols
    conf.sc.os_factor     = conf.f_s / conf.sc.f_sym; % Preamble oversampling factor (48)
    conf.sc.rolloff       = 0.22; % RRC pulse rolloff factor
    conf.sc.txpulse_length = 20 * conf.sc.os_factor;
    conf.sc.txpulse       = rrc(conf.sc.os_factor, conf.sc.rolloff, conf.sc.txpulse_length);
    conf.preamble.thr     = 250;  % Normalized cross-correlation detection threshold

    if mod(conf.sc.os_factor, 1) ~= 0
        warning('conf:syncOsMismatch', 'Audio Fs must be an integer multiple of preamble symbol rate.');
    end

    % =====================================================================
    % 4. OFDM Multicarrier Grid Parameters
    % =====================================================================
    conf.ofdm.bandwidth   = 2000; % Baseband transmission bandwidth [Hz]
    conf.ofdm.ncarrier    = 512;  % Total subcarriers (FFT size N)
    conf.ofdm.cplen       = 256;  % Cyclic prefix length [samples] (5.33 ms guard interval)
    conf.modulation_order = 2;    % 2 for QPSK (4-QAM), 4 for 16-QAM

    conf.ofdm.spacing     = conf.ofdm.bandwidth / conf.ofdm.ncarrier; % Subcarrier spacing: 3.90625 Hz
    conf.ofdm.os_factor   = conf.f_s / (conf.ofdm.ncarrier * conf.ofdm.spacing); % 24

    % =====================================================================
    % 5. Channel Estimation & Equalizer Settings
    % =====================================================================
    % Equalizer mode:
    %   0: No Equalization (Raw demodulation)
    %   1: Standard Frequency-Domain Least Squares (LS)
    %   2: Asymmetric Windowed Linear Minimum Mean Square Error (LMMSE)
    conf.eq.mode   = 2;
    conf.ch.length = 15;          % Post-cursor CIR window length (samples from peak forward)
    conf.ch.back   = 2;           % Pre-cursor CIR window length (samples before peak)

    % =====================================================================
    % 6. Forward Error Correction (FEC) - Concatenated RS + Convolutional
    % =====================================================================
    conf.coding.use_fec   = true; % Enable/disable concatenated FEC pipeline
    
    % Outer Code: Reed-Solomon RS(255, 239) over GF(2^8)
    conf.coding.rs_n      = 255;  % Codeword block length
    conf.coding.rs_k      = 239;  % Message length (corrects up to t=8 symbol errors)
    conf.coding.rs_m      = 8;    % Bits per symbol (byte-oriented)
    
    % Inner Code: Rate 1/2 Convolutional Code (NASA Standard)
    % Constraint Length K=7, Generators [171, 133] octal
    conf.coding.trellis   = poly2trellis(7, [171 133]);
    conf.coding.traceback = 35;   % Viterbi traceback depth (approx 5*K)
end