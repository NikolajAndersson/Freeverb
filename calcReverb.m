function [ mix ] = calcReverb(plugin, x )
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

% for each channel 
% 4*2 parallel LBCF --> 4 AP
f = 0.9; 
d = 0.2;
g = 0.2;

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

x1 = x(:,1);
x2 = x(:,2);
% left -----------
[c1, plugin.m1Buf] = LBCF(x1,d,f,m1, plugin.m1Buf);  
[c2, plugin.m2Buf] = LBCF(x1,d,f,m2, plugin.m2Buf); 
[c3, plugin.m3Buf] = LBCF(x1,d,f,m3, plugin.m3Buf);
[c4, plugin.m4Buf] = LBCF(x1,d,f,m4, plugin.m4Buf);
[c5, plugin.m5Buf] = LBCF(x1,d,f,m5, plugin.m5Buf);
[c6, plugin.m6Buf] = LBCF(x1,d,f,m6, plugin.m6Buf);
[c7, plugin.m7Buf] = LBCF(x1,d,f,m7, plugin.m7Buf); 
[c8, plugin.m8Buf] = LBCF(x1,d,f,m8, plugin.m8Buf); 

c = c1 + c2 + c3 + c4 + c5 + c6 + c7 + c7+ c8;
c = c*0.01;

[a,plugin.M1Buf] = AP(c, g,M1,plugin.M1Buf);
[a,plugin.M2Buf] = AP(a, g,M2,plugin.M2Buf);
[a,plugin.M3Buf] = AP(a, g,M3,plugin.M3Buf);
[left,plugin.M4Buf] = AP(a, g,M4,plugin.M4Buf);

% % right -----------
% stereospread = 23;
% c2 = LBCF(x2,d,f,m1 + stereospread) + LBCF(x2,d,f,m2 + stereospread) + LBCF(x2,d,f,m3 + stereospread) + LBCF(x2,d,f,m4 + stereospread) + LBCF(x2,d,f,m5 + stereospread)...
%     + LBCF(x2,d,f,m6 + stereospread)+ LBCF(x2,d,f,m7 + stereospread) + LBCF(x2,d,f,m8 + stereospread); 
% 
% [a2,~] = AP(c2, g, M1 + stereospread,[]);
% [a2,~] = AP(a2, g ,M2 + stereospread,[]);
% [a2,~] = AP(a2, g, M3 + stereospread,[]);
% [right,~] = AP(a2, g, M4 + stereospread,[]);

wet = [left left];
mix = wet;

end

