function [ out, z ] = LBCF(x,d,f, m, z )
% d = damp = initialdamp * scaledamp = 0.5 * 0.4 = 0.2
% Feedback f = roomsize = initialroom * scaleroom + offsetroom = 0.5 * 0.28 + 0.7 = 0.84 
b = [1 zeros(1,m) -d];
%b0 = [1-d]; a0 = [1 -d*1];
a = [1 -d zeros(1,m-1) -f*(1-d)];

[out, z] = filter(b,a,x,z);

end

