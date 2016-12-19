classdef Freeverb < audioPlugin
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        f = 0.89;
        d = 0.2;
        g = 0.5;
        
        stereospread = 23;
        stereoseparation = 0;
        Mix = 0.5;
    end
    properties (Access = private)
%          m1 = 1557;
%                 m2 = 1617;
%                 m3 = 1491;
%                 m4 = 1422;
%                 m5 = 1277;
%                 m6 = 1356;
%                 m7 = 1188;
%                 m8 = 1116;
%                 % allpass M values
%                 M1 = 225;
%                 M2 = 556;
%                 M3 = 441;
%                 M4 = 341;
        m1Buf = [];
        m2Buf = [];
        m3Buf = [];
        m4Buf = [];
        m5Buf = [];
        m6Buf = [];
        m7Buf = [];
        m8Buf = [];
        M1Buf = [];
        M2Buf = [];
        M3Buf = [];
        M4Buf = [];
        
        m1BufR = [];
        m2BufR = [];
        m3BufR = [];
        m4BufR = [];
        m5BufR = [];
        m6BufR = [];
        m7BufR = [];
        m8BufR = [];
        M1BufR = [];
        M2BufR = [];
        M3BufR = [];
        M4BufR = [];
    end
    properties (Constant)
        %         % comb filters m values
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
        % audioPluginInterface manages the number of input/output channels
        % and uses audioPluginParameter to generate plugin UI parameters.
        PluginInterface = audioPluginInterface(...
            'InputChannels',2,...
            'OutputChannels',2,...
            'PluginName','Freeverb',...
            'VendorName', '', ...
            'VendorVersion', '1.0', ...
            'UniqueId', '1aaa',...
            audioPluginParameter('f','DisplayName','Roomsize','Mapping',{'lin' 0 1}),...    
            audioPluginParameter('d','DisplayName','Damp','Mapping',{'lin' 0 1}),...    
            audioPluginParameter('g','DisplayName','Gain','Mapping',{'lin' 0 0.7}),...
            audioPluginParameter('stereospread','DisplayName','Stereospread','Mapping',{'lin' 0 500}),...
            audioPluginParameter('stereoseparation','DisplayName','Stereoseparation','Mapping',{'lin' 0 1}),...
            audioPluginParameter('Mix','DisplayName','Mix','Mapping',{'lin' 0 1}));
    end
    methods
        function plugin = Freeverb
            plugin.m1Buf = zeros(plugin.m1 + 1,1);
            plugin.m2Buf = zeros(plugin.m2 + 1,1);
            plugin.m3Buf = zeros(plugin.m3 + 1,1);
            plugin.m4Buf = zeros(plugin.m4 + 1,1);
            plugin.m5Buf = zeros(plugin.m5 + 1,1);
            plugin.m6Buf = zeros(plugin.m6 + 1,1);
            plugin.m7Buf = zeros(plugin.m7 + 1,1);
            plugin.m8Buf = zeros(plugin.m8 + 1,1);
            plugin.M1Buf = zeros(plugin.M1,1);
            plugin.M2Buf = zeros(plugin.M2,1);
            plugin.M3Buf = zeros(plugin.M3,1);
            plugin.M4Buf = zeros(plugin.M4,1);    
            stereolength = 1000;
            plugin.m1BufR = zeros(plugin.m1 + 1 + stereolength,1);
            plugin.m2BufR = zeros(plugin.m2 + 1 + stereolength,1);
            plugin.m3BufR = zeros(plugin.m3 + 1 + stereolength,1);
            plugin.m4BufR = zeros(plugin.m4 + 1 + stereolength,1);
            plugin.m5BufR = zeros(plugin.m5 + 1 + stereolength,1);
            plugin.m6BufR = zeros(plugin.m6 + 1 + stereolength,1);
            plugin.m7BufR = zeros(plugin.m7 + 1 + stereolength,1);
            plugin.m8BufR = zeros(plugin.m8 + 1 + stereolength,1);
            plugin.M1BufR = zeros(plugin.M1 + stereolength,1);
            plugin.M2BufR = zeros(plugin.M2 + stereolength,1);
            plugin.M3BufR = zeros(plugin.M3 + stereolength,1);
            plugin.M4BufR = zeros(plugin.M4 + stereolength,1); 
            
        end
        function out = calcReverb(plugin, x )
            %UNTITLED Summary of this function goes here
            %   Detailed explanation goes here
            
            % for each channel
            % 4*2 parallel LBCF --> 4 AP
            f = plugin.f;
            d = plugin.d;
            g = plugin.g;
            
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
            c = c*0.05;
            
            [a,plugin.M1Buf] = AP(c, g,M1,plugin.M1Buf);
            [a,plugin.M2Buf] = AP(a, g,M2,plugin.M2Buf);
            [a,plugin.M3Buf] = AP(a, g,M3,plugin.M3Buf);
            [left,plugin.M4Buf] = AP(a, g,M4,plugin.M4Buf);
            
            % % right -----------
            stereospread = floor(plugin.stereospread);
            %stereospread = 23;
            [Rc1, plugin.m1BufR(1:m1 + stereospread + 1)] = LBCF(x2,d,f,m1 + stereospread, plugin.m1BufR(1:m1 + stereospread + 1)); 
            [Rc2, plugin.m2BufR(1:m2 + stereospread + 1)] = LBCF(x2,d,f,m2 + stereospread, plugin.m2BufR(1:m2 + stereospread + 1)); 
            [Rc3, plugin.m3BufR(1:m3 + stereospread + 1)] = LBCF(x2,d,f,m3 + stereospread, plugin.m3BufR(1:m3 + stereospread + 1)); 
            [Rc4, plugin.m4BufR(1:m4 + stereospread + 1)] = LBCF(x2,d,f,m4 + stereospread, plugin.m4BufR(1:m4 + stereospread + 1));  
            [Rc5, plugin.m5BufR(1:m5 + stereospread + 1)] = LBCF(x2,d,f,m5 + stereospread, plugin.m5BufR(1:m5 + stereospread + 1));
            [Rc6, plugin.m6BufR(1:m6 + stereospread + 1)] = LBCF(x2,d,f,m6 + stereospread, plugin.m6BufR(1:m6 + stereospread + 1));
            [Rc7, plugin.m7BufR(1:m7 + stereospread + 1)] = LBCF(x2,d,f,m7 + stereospread, plugin.m7BufR(1:m7 + stereospread + 1));
            [Rc8, plugin.m8BufR(1:m8 + stereospread + 1)] = LBCF(x2,d,f,m8 + stereospread, plugin.m8BufR(1:m8 + stereospread + 1));
            Rc = Rc1 + Rc2 + Rc3 + Rc4 + Rc5 + Rc6 + Rc7 + Rc7+ Rc8;
            Rc = Rc*0.05;
            [a2, plugin.M1BufR(1:M1 + stereospread)] = AP(Rc, g, M1 + stereospread, plugin.M1BufR(1:M1 + stereospread));
            [a2, plugin.M2BufR(1:M2 + stereospread)] = AP(a2, g, M2 + stereospread, plugin.M2BufR(1:M2 + stereospread));
            [a2, plugin.M3BufR(1:M3 + stereospread)] = AP(a2, g, M3 + stereospread, plugin.M3BufR(1:M3 + stereospread));
            [right, plugin.M4BufR(1:M4 + stereospread)] = AP(a2, g, M4 + stereospread, plugin.M4BufR(1:M4 + stereospread));
            
            wet1 = 1-plugin.stereoseparation; wet2 = plugin.stereoseparation;
            wet = [left*wet1+right*wet2 right*wet1+left*wet2];
            
            mix = plugin.Mix;
            out = (1-mix)*x + mix*(wet*(1-g));
            %out = (1-mix)*x;
        end
        
        function out = process(plugin, x)
            out = calcReverb(plugin, x);
        end
    end
    
end

