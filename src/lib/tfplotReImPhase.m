function tfplotReImPhase(s, fs, name, plottitle)
% TFPLOT Time and frequency plot
%    TFPLOT(S, FS, NAME, TITLE) displays a figure window with two
%    subplots.  Above, the signal S is plotted in time domain; below,
%    the signal is plotted in frequency domain. NAME is the "name" of the
%    signal, e.g., if NAME is 's', then the labels on the y-axes will be
%    's(t)' and '|s_F(f)|', respectively.  TITLE is the title that will
%    appear above the two plots.


% Note: Since TITLE is the name of a built-in Matlab function, you cannot
% use it as the name of a function argument.  In the following code, we
% called the argument PLOTTITLE instead 

if ~isscalar(fs)
    error('Fs must be scalar');
end

% Compute the time and frequency axes
Ts = 1/fs;
t = linspace(0, (length(s)-1)*Ts, length(s));

NFFT = 2^nextpow2(length(s)); % for computational efficiency
Tp = NFFT*Ts;
f = linspace(-1/(2*Ts), 1/(2*Ts)-1/Tp, NFFT);

% Compute the FFT
s_f = fft(s,NFFT);
% Correct the scaling and the frequency axis
% Use fftshift to move the negative frequencies to the left
s_f = Ts * fftshift(s_f);

figure;

% First plot: time
subplot(2,2,1); plot(t, real(s)); grid on;
xlabel('t [s]'); ylabel(sprintf('\\Re[%s(t)]', name));


subplot(2,2,2); plot(t, imag(s)); grid on;
xlabel('t [s]'); ylabel(sprintf('\\Im[%s(t)]', name));



% Second plot: frequency
subplot(2,2,3); plot(f, abs(s_f)); grid on;
xlabel('f [Hz]'); 
ylabel(sprintf('|%s_F(f)|', name));


subplot(2,2,4); plot(f, angle(s_f)); grid on;
xlabel('f [Hz]'); 
ylabel(sprintf('\\angle %s_F(f)|', name));

sgtitle(plottitle);

end