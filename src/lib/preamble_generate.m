function [preamble] = preamble_generate(length)
    % preamble_generate() 
    % input : length: a scaler value, desired length of preamble.
    % output: preamble: preamble bits
    preamble = zeros(length, 1);
    lfsr_reg = ones(1,8);
    xor_loc = [6,5,4];
    
    for i=1:length
        %Output
        preamble(i)=lfsr_reg(end);
        
        %Feedback
        feedback = xor(lfsr_reg(end),lfsr_reg(xor_loc(1)));
        feedback = xor(feedback, lfsr_reg(xor_loc(2)));
        feedback = xor(feedback,lfsr_reg(xor_loc(3)));

        %Input and shifting
        lfsr_reg = [feedback lfsr_reg(1:end-1)];
    end
end