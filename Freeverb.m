classdef Freeverb < audioPlugin
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        f = 0.89;
        d = 0.2;
        g = 0.5;
        stereospread = 0;
        
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
    end
    properties (Access = private)
        
    end
    properties (Constant)
%         % comb filters m values
%         m1 = 1557;
%         m2 = 1617;
%         m3 = 1491;
%         m4 = 1422;
%         m5 = 1277;
%         m6 = 1356;
%         m7 = 1188;
%         m8 = 1116;
%         % allpass M values
%         M1 = 225;
%         M2 = 556;
%         M3 = 441;
%         M4 = 341;
        % audioPluginInterface manages the number of input/output channels
        % and uses audioPluginParameter to generate plugin UI parameters.
        PluginInterface = audioPluginInterface(...
            'InputChannels',2,...
            'OutputChannels',2,...
            'PluginName','Freeverb',...
            'VendorName', '', ...
            'VendorVersion', '1.0', ...
            'UniqueId', '1aaa',...
            audioPluginParameter('g','DisplayName','Gain','Mapping',{'lin' 0 1}));
    end
    methods
        function plugin = Freeverb
        end
        function out = process(plugin, x)
            out = calcReverb(plugin, x);
        end
    end
    
end

