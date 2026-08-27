function lambda = channel_estLS(Rf, training_symbols)
% CHANNEL_ESTLS Frequency-Domain Least Squares (LS) Channel Estimator.
%
%   lambda = CHANNEL_ESTLS(Rf, training_symbols) computes the Channel Frequency
%   Response (CFR) across active subcarriers by dividing the received training
%   symbol by the known transmitted training sequence.
%
%   Mathematical Model:
%     Y[k] = H[k] * X[k] + Z[k]
%     H_LS[k] = Y[k] / X[k] = H[k] + Z[k] / X[k]
%
% Inputs:
%   Rf               - Demodulated frequency-domain grid [useful_carriers x total_blocks],
%                      where the first column Rf(:,1) contains the training symbol.
%   training_symbols - Known transmitted training symbols on active carriers.
%
% Outputs:
%   lambda           - Column vector of estimated channel frequency coefficients H_LS.
%
% Wireless Receivers: Algorithms and Architectures
% Telecommunications Circuits Laboratory (TCL), EPFL

    % Extract received training symbol (first OFDM block)
    Y_training = Rf(:, 1);

    % Element-wise frequency domain deconvolution (Least Squares division)
    lambda = Y_training ./ training_symbols(:);
end
