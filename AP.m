function [ out,zi ] = AP(x, g,M,zi )
% All pass filters in series
%   H(z) = (-g + z^-M )/ (1- g * z^M)
    
%    for i = 1:length(M)
%     b = [-g, zeros(1, M(i)-1), 1];
%     a = [1, zeros(1,M(i)-1), -g];
%     s = filter(b, a, s); 
%    end

% freeverb allpass
   b = [-1 zeros(1, M-1) 1+g];
   a = [1, zeros(1,M-1), -g];
   [out, zi] = filter(b,a,x, zi);

end

