# Acoustic OFDM Transceiver & Wireless Communication System

[![MATLAB](https://img.shields.io/badge/MATLAB-R2022b%2B-blue.svg)](https://www.mathworks.com/products/matlab.html)
[![DSP](https://img.shields.io/badge/DSP-OFDM%20%7C%20Synchronization%20%7C%20LMMSE-brightgreen.svg)]()
[![FEC](https://img.shields.io/badge/FEC-Reed--Solomon%20%2B%20Viterbi%20Conv-orange.svg)]()
[![EPFL](https://img.shields.io/badge/EPFL-EE--442%20Wireless%20Receivers-red.svg)](https://www.epfl.ch)
[![Documentation](https://img.shields.io/badge/Documentation-Technical%20Report%20(PDF)-informational.svg)](docs/report.pdf)

> **Autonomous acoustic multicarrier communication system designed, implemented, and experimentally validated for highly reverberant, multipath-rich indoor acoustic channels.**  
> Developed at the **Telecommunications Circuits Laboratory (TCL), EPFL** (Lausanne, Switzerland) as part of the *EE-442: Wireless Receivers — Algorithms and Architectures* curriculum.

---

## 📑 Table of Contents
1. [Executive Summary](#-executive-summary)
2. [System Specifications & Parameters](#-system-specifications--parameters)
3. [Transceiver Architecture & Signal Flow](#-transceiver-architecture--signal-flow)
4. [Key Algorithmic & DSP Highlights](#-key-algorithmic--dsp-highlights)
   - [1. Time Synchronization & Frame Detection](#1-time-synchronization--frame-detection)
   - [2. Two-Stage Carrier Frequency Offset (CFO) Estimation](#2-two-stage-carrier-frequency-offset-cfo-estimation)
   - [3. Asymmetric Circular Windowed LMMSE Channel Estimation](#3-asymmetric-circular-windowed-lmmse-channel-estimation)
   - [4. Symbol-by-Symbol Pilot Phase Tracking](#4-symbol-by-symbol-pilot-phase-tracking)
   - [5. Concatenated Forward Error Correction (RS + Convolutional)](#5-concatenated-forward-error-correction-rs--convolutional)
5. [Channel Models & Performance Analysis](#-channel-models--performance-analysis)
6. [Over-the-Air Experimental Validation](#-over-the-air-experimental-validation)
7. [Repository & Code Organization](#-repository--code-organization)
8. [Quick Start Guide](#-quick-start-guide)
9. [Authors & Academic Context](#-authors--academic-context)

---

## 🚀 Executive Summary

This repository contains a full-featured, modular **Orthogonal Frequency Division Multiplexing (OFDM)** transceiver operating over acoustic audio passband frequencies ($f_c = 8\text{ kHz}$). Acoustic channels exhibit severe physical impairments including **extreme multipath delay spread (long reverberation times), Doppler shift, frequency-selective fading, deep spectral notches, and carrier frequency offsets (CFO)**.

To overcome these challenges, this system implements an industry-standard physical layer architecture featuring:
- **Schmidl-Cox inspired energy-normalized sliding cross-correlation** for sub-sample packet detection.
- **Two-stage Doppler / CFO compensation** combining a coarse grid search with a 3-point parabolic interpolation ($<0.1\text{ Hz}$ resolution).
- **Novel Asymmetric Circular-Shift LMMSE Channel Estimator** that isolates true Channel Impulse Response (CIR) taps while zeroing out out-of-band noise.
- **Continuous Pilot-Assisted Residual Phase Derotation** to counteract phase drift across long OFDM blocks.
- **Two-tier Concatenated Forward Error Correction (FEC)** combining an outer byte-oriented Reed-Solomon $RS(255, 239)$ code with an inner Rate $1/2$ constraint length $K=7$ Convolutional Code (Viterbi hard-decision decoding).

The transceiver has been thoroughly validated via both high-fidelity Monte Carlo channel emulation and **live over-the-air (OTA) audio transmissions** (loudspeaker-to-microphone) in the **EPFL Rolex Learning Center (RLC)**, achieving **$BER = 0.000000$ (error-free)** image transmission over severe reverberant multipath.

---

## 📊 System Specifications & Parameters

| Parameter | Symbol / Variable | Value | Description |
| :--- | :--- | :--- | :--- |
| **Audio Sampling Rate** | $f_s$ | $48\text{ kHz}$ | Standard audio DAC/ADC hardware rate |
| **Acoustic Carrier Frequency** | $f_c$ | $8\text{ kHz}$ | Digital upconversion / downconversion frequency |
| **Baseband Bandwidth** | $B$ | $2\text{ kHz}$ | Bandwidth of the OFDM signal |
| **Oversampling / Interpolation** | $L_{\text{os}}$ | $24$ | Ratio $f_s / B$ for DAC upsampling |
| **Total Subcarriers (FFT Size)** | $N$ | $512$ | Fast Fourier Transform block size |
| **Subcarrier Spacing** | $\Delta f$ | $3.90625\text{ Hz}$ | $\Delta f = B / N$ |
| **Cyclic Prefix (CP) Length** | $N_{\text{CP}}$ | $256\text{ samples}$ | Guard interval duration ($5.33\text{ ms}$) |
| **Active Subcarriers** | $N_{\text{active}}$ | $512$ | Configurable via PSD mask for notch mitigation |
| **Pilot Subcarriers** | $N_{\text{pilots}}$ | $6$ | Subcarrier indices: `[101, 277, 301, 348, 440, 501]` |
| **Data Subcarriers** | $N_{\text{data}}$ | $506$ | Subcarriers allocated for payload per OFDM symbol |
| **OFDM Frame Geometry** | $N_{\text{sym}}$ | $51\text{ symbols}$ | $1$ Training Symbol + $50$ Data Symbols |
| **Modulation Schemes** | $\mathcal{M}$ | QPSK / 16-QAM | Gray-mapped, unit average power normalized |
| **Preamble Sequence** | $L_{\text{preamble}}$ | $500\text{ symbols}$ | BPSK LFSR sequence with RRC pulse shaping ($\beta = 0.22$) |
| **Outer Channel Code** | $RS(n,k)$ | $RS(255, 239)$ | Galois Field $GF(2^8)$, corrects up to $t=8$ symbol errors |
| **Inner Channel Code** | Conv $R=1/2$ | $K=7, (171, 133)_8$ | NASA standard convolutional code with Viterbi decoding ($L_{\text{tb}}=35$) |
| **Net Payload Capacity** | $C_{\text{frame}}$ | $25,300\text{ bits}$ | Useful information bits per frame under Rate $1/2$ FEC |

---

## 🏗 Transceiver Architecture & Signal Flow

```mermaid
flowchart LR
    subgraph Transmitter Chain
        A[Payload Bits] --> B[Concatenated FEC<br/>RS + Conv Rate 1/2]
        B --> C[QPSK / 16-QAM<br/>Constellation Mapper]
        C --> D[OFDM Framing &<br/>Pilot Multiplexing]
        D --> E[512-IFFT +<br/>Cyclic Prefix 256]
        E --> F[Interpolation 24x<br/>+ RRC Preamble]
        F --> G[Digital Upconversion<br/>fc = 8 kHz]
    end
    G ==>|Acoustic Channel / Emulator| H
    subgraph Receiver Chain
        H[Passband Signal] --> I[Digital Downconversion<br/>+ Lowpass Filter]
        I --> J[Normalized Cross-Corr<br/>Frame Detection]
        J --> K[Two-Stage CFO<br/>Grid + Parabolic Fit]
        K --> L[Time Derotation<br/>+ Decimation 1/24]
        L --> M[CP Removal +<br/>512-FFT]
        M --> N[Asymmetric Windowed<br/>LMMSE Equalizer]
        N --> O[Pilot-Assisted<br/>Phase Derotation]
        O --> P[Constellation Demapper<br/>+ Viterbi Decoder]
        P --> Q[Recovered Bits]
    end
```

### OFDM Frame Structure
The transmission frame consists of a **Root-Raised Cosine (RRC) shaped single-carrier preamble**, followed by a **channel estimation training symbol**, and a sequence of **$50$ OFDM data symbols** carrying interspersed pilot tones:

<p align="center">
  <img src="docs/figures/ofdm_frame_structure.png" alt="OFDM Frame Structure" width="750"/>
</p>

---

## 🔬 Key Algorithmic & DSP Highlights

### 1. Time Synchronization & Frame Detection
Frame arrival is identified using an **energy-normalized sliding cross-correlation** between the incoming baseband stream $r[n]$ and the known BPSK preamble sequence $p[n]$:

$$M(d) = \frac{\left| \sum_{n=0}^{L-1} r^*[d+n] \, p[n] \right|^2}{\sum_{n=0}^{L-1} |r[d+n]|^2}$$

Normalizing by the local window energy ensures robust, volume-independent thresholding ($\text{threshold} = 250$), reliably locating the frame boundary even in high-noise and attenuated acoustic channels.

<p align="center">
  <img src="docs/figures/sync_correlation_metric.png" alt="Synchronization Metric" width="600"/>
</p>

---

### 2. Two-Stage Carrier Frequency Offset (CFO) Estimation
Carrier frequency offsets (caused by hardware oscillator mismatch and Doppler shifts) rotate the constellation and destroy subcarrier orthogonality. The receiver applies a two-step estimation:
1. **Coarse Grid Search:** Evaluates correlation across a frequency grid $\Delta f_{\text{grid}} \approx 9.6\text{ Hz}$ spanning $[-1200\text{ Hz}, +1200\text{ Hz}]$.
2. **Fine Parabolic Interpolation:** Fits a concave quadratic polynomial $y = a f^2 + b f + c$ across the peak sample and its two immediate neighbors, yielding sub-Hertz CFO estimation accuracy:

$$f_{\text{CFO}} = -\frac{b}{2a}$$

The time-domain baseband stream is derotated by $e^{-j 2\pi f_{\text{CFO}} t}$ prior to multicarrier demodulation.

---

### 3. Asymmetric Circular Windowed LMMSE Channel Estimation
Raw Least Squares (LS) frequency-domain channel estimation divides the received training block by the known reference:

$$\hat{H}_{\text{LS}}[k] = \frac{Y_{\text{training}}[k]}{X_{\text{training}}[k]} = H[k] + \frac{Z[k]}{X_{\text{training}}[k]}$$

While unbiased, LS amplifies the noise floor $Z[k]$. This project implements a **practical, noise-suppressing time-domain windowing technique (LMMSE approximation)**:
1. **CIR Transformation:** Computes the raw Channel Impulse Response via IFFT: $\hat{h}_{\text{LS}}[n] = \text{IFFT}\{\hat{H}_{\text{LS}}[k]\}$.
2. **Circular Shift Centering:** Detects the main energy cursor (tap with peak power) and circularly shifts it to index $N/2$. This eliminates boundary edge artifacts caused by circular convolution wrap-around.
3. **Asymmetric Mask Filtering:** Applies an asymmetric time-domain window retaining $N_{\text{back}} = 2$ pre-cursor taps and $N_{\text{fwd}} = 15\text{ to }50$ post-cursor taps, zeroing out all noise samples outside the true physical delay spread.
4. **Restoration & FFT:** Shifts the cleaned CIR back to its original delay offset and converts to frequency domain: $\hat{H}_{\text{LMMSE}}[k] = \text{FFT}\{\hat{h}_{\text{clean}}[n]\}$.

<p align="center">
  <img src="docs/figures/channel5_cir_lmmse.png" alt="LMMSE Channel Impulse Response Filtering" width="700"/>
</p>

#### ISI Quantification
The system quantitatively evaluates Inter-Symbol Interference (ISI) and eye diagram opening via:

$$D_{\text{peak}} = \sum_{k \neq d} \frac{|h[k]|}{|h[d]|}, \quad \eta = \frac{d_{\text{min}}/2}{|A|_{\text{max}}}, \quad \gamma_{\text{ISI}} = \frac{D_{\text{peak}}}{\eta}$$

A condition of $\gamma_{\text{ISI}} < 1$ guarantees an open eye diagram and error-free decodability in high-SNR regimes.

---

### 4. Symbol-by-Symbol Pilot Phase Tracking
Residual frequency offsets and sampling clock frequency drift induce a slow, cumulative phase rotation across consecutive OFDM blocks. For each OFDM block $l$, the receiver estimates the phase error $\theta[l]$ across the 6 dedicated pilot subcarriers:

$$\theta[l] = \arg\left( \mathbf{p}^H \mathbf{Y}_{\text{pilots}}[l] \right)$$

The entire OFDM symbol is then derotated by $e^{-j \theta[l]}$, preventing constellation rotation over long multi-symbol frames.

---

### 5. Concatenated Forward Error Correction (RS + Convolutional)
To guarantee link reliability over hostile channels, a two-stage concatenated coding scheme is implemented:
- **Inner Code:** Rate $1/2$ Convolutional Code ($K=7$, generators $[171_8, 133_8]$), decoded with the Viterbi algorithm (hard-decision, $L_{\text{tb}} = 35$). This efficiently suppresses random channel noise.
- **Outer Code:** Byte-oriented Reed-Solomon $RS(255, 239)$ over $GF(2^8)$, correcting up to $t=8$ symbol errors per block. This eliminates residual error bursts produced by Viterbi traceback errors.

<p align="center">
  <img src="docs/figures/ber_fec_comparison.png" alt="BER Waterfall and Coding Gain" width="550"/>
</p>

---

## 📡 Channel Models & Performance Analysis

The system was evaluated across 5 distinct channel models representing canonical physical phenomena:

| Channel Model | Impairment Profile | Optimal Equalizer & Strategy |
| :--- | :--- | :--- |
| **Channel 1** | AWGN + Front-End Filter Attenuation | Windowed LMMSE ($N_{\text{fwd}}=15$) eliminates out-of-band noise amplification. |
| **Channel 2** | Dynamic Carrier Frequency Offset / Phase Drift | Pilot-based phase tracking corrects continuous constellation rotation. |
| **Channel 3** | High Delay Spread (Sparse multipath with long delay) | Wide window LMMSE or Least Squares (LS) captures dispersed multipath energy. |
| **Channel 4** | Severe Spectral Notch (Band Rejection) | PSD subcarrier nulling / masking prevents infinite noise amplification. |
| **Channel 5** | Realistic Acoustic Multipath (Exponential delay profile) | Asymmetric LMMSE CIR windowing achieves substantial SNR gain ($>6\text{ dB}$). |

<p align="center">
  <img src="docs/figures/channel5_constellation_lmmse.png" alt="Channel 5 Equalized Constellation" width="450"/>
</p>

---

## 🏫 Over-the-Air Experimental Validation

The transceiver was validated through physical over-the-air transmission of a 24-bit color bitmap image in the **EPFL Rolex Learning Center (RLC)**:
- **Physical Channel:** High-reverberation open hall with glass walls and acoustic reflection paths.
- **Frame Segmentation:** The image is split into 10 independent OFDM frames (each with its own preamble and training symbol) to continuously track slow acoustic variations.
- **Result:** Complete image reconstruction with **zero uncorrected bit errors** ($BER = 0.000000$), proving the robustness of the combined LMMSE equalization and concatenated FEC pipeline.

<p align="center">
  <img src="docs/figures/rlc_experimental_setup.png" alt="EPFL Rolex Learning Center Setup" width="550"/>
  <br/>
  <em>Figure: Physical experimental transmission environment in EPFL Rolex Learning Center.</em>
</p>

<p align="center">
  <img src="docs/figures/image_transmission_result.png" alt="Transmitted vs Reconstructed Image" width="650"/>
  <br/>
  <em>Figure: Original transmitted image (left) vs reconstructed image at the receiver (right).</em>
</p>

---

## 📂 Repository & Code Organization

```
.
├── README.md                      # Comprehensive project overview & documentation
├── setpath.m                      # Environment initialization script
├── main_transceiver_demo.m        # Quick start: end-to-end payload transmission test
├── main_image_transmission.m      # Image transmission benchmark (emulator or audio)
├── main_ber_benchmark.m           # Monte Carlo BER / PER / Goodput waterfall curves
├── main_equalizer_analysis.m      # Comparative analysis of LS vs Windowed LMMSE
│
├── src/                           # Transceiver Source Code
│   ├── config/                    # System & OFDM parameter initialization
│   │   ├── configurations.m       # Master system parameters (sampling, FEC, channels)
│   │   └── ofdmConfig.m           # Subcarrier allocation, PSD masks, pilot indices
│   ├── transmit/                  # Physical layer transmitter
│   │   ├── transmitter.m          # Baseband frame orchestration & digital upconversion
│   │   ├── ofdm_tx_frame_with_pilots.m # Multicarrier IFFT modulation & pilot insertion
│   │   └── channel_encoder.m      # Concatenated FEC encoder (RS + Convolutional)
│   ├── receive/                   # Physical layer digital receiver
│   │   ├── receiver.m             # Complete downconversion, sync, demod & decoding
│   │   ├── estimateTauAndCFO.m    # Normalized cross-correlation sync & 2-stage CFO
│   │   ├── channel_estLS.m        # Frequency-domain Least Squares channel estimation
│   │   ├── ChannelMetrics.m       # Asymmetric windowed LMMSE & ISI metric suite
│   │   ├── correctOFDMSymbolRotation.m # Pilot-assisted residual phase derotation
│   │   ├── ofdm_rx_frame.m        # CP stripping, FFT demodulation & subcarrier demux
│   │   └── channel_decoder.m      # Concatenated FEC decoder (Viterbi + Reed-Solomon)
│   └── lib/                       # Signal processing utilities & channel emulator
│       ├── channel_emulator.p     # EPFL acoustic channel emulator (Models 1 to 5)
│       ├── preamble_generate.m    # LFSR pseudo-random preamble generator
│       ├── rrc.m                  # Root-Raised Cosine pulse shaping filter
│       ├── ofdmlowpass.m          # Anti-aliasing / image rejection lowpass filter
│       ├── qamMap.m / pskMap.m    # Constellation mapping utilities
│       ├── encoder.m / decoder.m  # Constellation modulation & Euclidean slicing
│       └── bi2de.m / de2bi.m      # Bit-to-symbol integer conversion routines
│
├── data/                          # Test assets and outputs
│   ├── test_image.bmp             # Original sample image
│   └── received_image.bmp         # Reconstructed received image
│
└── docs/                          # Technical documentation
    ├── report.pdf                 # Complete EPFL EE-442 Project Report (PDF)
    ├── figures/                   # High-resolution architectural & performance plots
    └── latex/                     # Full LaTeX source code and build files
```

---

## ⚡ Quick Start Guide

### 1. Prerequisites
- MATLAB R2022b or later.
- Signal Processing Toolbox & Communications Toolbox.

### 2. Environment Setup
Clone the repository and initialize MATLAB paths:
```matlab
% In MATLAB command window:
cd '/path/to/OFDM-Project'
run setpath;
```

### 3. Running Simulations & Demos

#### A. Basic Transceiver Demonstration
Transmits a random binary payload through the acoustic emulator and verifies error-free decoding:
```matlab
main_transceiver_demo
```

#### B. Full Image Transmission Demonstration
Transmits a 2D bitmap image across 20 segmented frames and renders the reconstructed result:
```matlab
main_image_transmission
```

#### C. BER Waterfall & Coding Gain Benchmark
Generates Monte Carlo BER, PER, and Goodput curves comparing Uncoded vs Concatenated FEC across SNRs:
```matlab
main_ber_benchmark
```

#### D. Equalizer Comparison Suite
Compares raw Least Squares (LS) against Asymmetric Windowed LMMSE across multiple CIR window lengths:
```matlab
main_equalizer_analysis
```

#### E. Over-the-Air Audio Transmission (Real Hardware)
To transmit acoustically through your PC's speaker and record via microphone:
1. Open `src/config/configurations.m`.
2. Set `conf.audiosystem = 'audio';`.
3. Execute `main_transceiver_demo` or `main_image_transmission`.

---

## 📄 Full Technical Report
For the complete mathematical derivations, proof of ISI bounds, spectral efficiency trade-offs, and in-depth experimental discussions, refer to the full academic report:
👉 [**Read Full Technical Report (PDF)**](docs/report.pdf)

---

## 👥 Authors & Academic Context
- **Daniel Pereira Riquelme**
- **Jérémie Joël Moullet**
- **Dominic Stratila**

**Supervision:** Telecommunications Circuits Laboratory (TCL), **École Polytechnique Fédérale de Lausanne (EPFL)**, Switzerland.  
**Course:** *EE-442 Wireless Receivers: Algorithms and Architectures*.

---

## 💡 Recommendations for Portfolio & CV Presentation

If you are showcasing this project for telecom, DSP, and wireless firmware engineering roles (e.g., **Nokia Helsinki, Qualcomm, Ericsson, Apple, Broadcom**), consider highlighting the following:

1. **Short Video / GIF Demo:**
   - Record a 5-second animated GIF or short video showing `main_image_transmission` running in real time (side-by-side display of the incoming image blocks reconstructing the image, or a constellation scatter plot converging as equalization turns on).
2. **Audio Waveform Sample:**
   - Attach a short `.wav` sample of the audible chirped OFDM acoustic transmission to showcase real-world physical layer operation.
3. **Key CV Bullet Points:**
   - *“Designed and implemented an end-to-end baseband/passband acoustic OFDM transceiver in MATLAB featuring 512-IFFT/FFT, 256-sample cyclic prefix, and pilot-assisted dynamic phase tracking.”*
   - *“Engineered a novel asymmetric windowed LMMSE channel estimator in the time domain (CIR), reducing noise amplification and achieving >6 dB SNR coding gain over reverberant indoor multipath.”*
   - *“Implemented a two-tier concatenated FEC pipeline (outer Reed-Solomon RS(255, 239) + inner Viterbi Rate 1/2 Convolutional Code), validating error-free OTA image transmission in the EPFL Rolex Learning Center.”*
