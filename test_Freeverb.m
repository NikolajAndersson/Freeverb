% for each channel 
% 4*2 parallel LBCF --> 4 AP
f = 0.89; 
d = 0.2;
g = 0.5;

% comb filters m values
m1 = 1557;
m2 = 1617;
m3 = 1491;
m4 = 1422;
m5 = 1277;
m6 = 1356;
m7 = 1188; 
m8 = 1116;
% allpass M values
M1 = 225;
M2 = 556;
M3 = 441;
M4 = 341;

[x,fs] = audioread('PianoA5.wav');
x = [1 1; zeros(fs-1,1) zeros(fs-1,1)];
x1 = x(:,1);
x2 = x(:,2);
% left -----------
c = LBCF(x1,d,f,m1) + LBCF(x1,d,f,m2) + LBCF(x1,d,f,m3) + LBCF(x1,d,f,m4) + LBCF(x1,d,f,m5)...
    + LBCF(x1,d,f,m6)+ LBCF(x1,d,f,m7) + LBCF(x1,d,f,m8); 

[a,zi1] = AP(c, g,M1,[]);
[a,zi2] = AP(a, g,M2,[]);
[a,zi3] = AP(a, g,M3,[]);
[left,zi4] = AP(a, g,M4,[]);

% right -----------
stereospread = 23;
c2 = LBCF(x2,d,f,m1 + stereospread) + LBCF(x2,d,f,m2 + stereospread) + LBCF(x2,d,f,m3 + stereospread) + LBCF(x2,d,f,m4 + stereospread) + LBCF(x2,d,f,m5 + stereospread)...
    + LBCF(x2,d,f,m6 + stereospread)+ LBCF(x2,d,f,m7 + stereospread) + LBCF(x2,d,f,m8 + stereospread); 

[a2,~] = AP(c2, g, M1 + stereospread,[]);
[a2,~] = AP(a2, g ,M2 + stereospread,[]);
[a2,~] = AP(a2, g, M3 + stereospread,[]);
[right,~] = AP(a2, g, M4 + stereospread,[]);

wet = [left right];
mix = x*0.2 + 0.8*wet;

soundsc(mix,fs)