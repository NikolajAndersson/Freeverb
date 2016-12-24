classdef Freeverb < audioPlugin
 % Freeverb
    %   This is an Audio System Toolbox implementation of the Freeverb
    %   created by Jezar at Dreampoint - http://www.dreampoint.co.uk 
    %   The implementation is guided by Juluis O. Smith's description of
    %   the Freeverb implementation
    %   Webpage: 'Physical Audio Signal Processing', link: https://ccrma.stanford.edu/~jos/pasp/Freeverb.html  
    
    properties
        f = 0.82; % RoomSize
        d = 0.2;  % Damping
        g = 0.5;  % Gain
        
        stereoseparation = 0;
        Mix = 0.5;
    end
    properties (Access = private)
        
        APLengthL = [];
        APLengthR = [];
        
        APBufferL = [];
        APBufferR = [];
       
        bAPL = [];
        aAPL = [];
        
        bAPR = [];
        aAPR = [];
        
        stereolength = 200;
        
        CombDelay
        Lowpass
        SamplesPerFrame
        FrameSize
        NumOfFrames
        DryBuffer
        WetBuffer
    end
    properties(Constant, Access = private)
        % M values for Comb and allpass filters
        APValues = [225, 556, 441, 341];
        cValues = [1557, 1617, 1491, 1422, 1277, 1356, 1188, 1116];
        stereospread = 23;
        bLow = 1-0.25;
        aLow = [1,-0.25];
    end
    properties (Constant)

        % audioPluginInterface manages the number of input/output channels
        % and uses audioPluginParameter to generate plugin UI parameters.
        PluginInterface = audioPluginInterface(...
            'InputChannels',2,...
            'OutputChannels',2,...
            'PluginName','Freeverb',...
            'VendorName', '', ...
            'VendorVersion', '3.0', ...
            'UniqueId', '1abb',...
            audioPluginParameter('f','DisplayName','Roomsize','Mapping',{'lin' 0 1}),...
            audioPluginParameter('d','DisplayName','Damp','Mapping',{'lin' 0.1 0.7}),...
            audioPluginParameter('g','DisplayName','Gain','Mapping',{'lin' 0.1 0.7}),...
            audioPluginParameter('stereoseparation','DisplayName','Stereoseparation','Mapping',{'lin' 0 1}),...
            audioPluginParameter('Mix','DisplayName','Mix','Mapping',{'lin' 0 1}));
    
            % audioPluginParameter('stereospread','DisplayName','Stereospread','Mapping',{'lin' 0 100})

    end
    
    methods
        function p = Freeverb
            % Comb filter fron dsp class. Inspired by audioexample.FreeverbReverberator
%             if (isempty(p.pCombDelay) && isempty(p.pLowpass))
%                 p.pCombDelay = dsp.Delay([p.cValues p.cValues + 23]);
%                 p.pLowpass = dsp.IIRFilter('Numerator',1-0.25, 'Denominator', [1,-0.25]);
%             end
            p.Lowpass = dsp.IIRFilter('Numerator',p.bLow, 'Denominator', p.aLow);
            p.CombDelay = dsp.Delay([p.cValues, p.cValues + 23]);

            % Create buffers for all coefficients
            p.APLengthL = p.APValues;
            p.APLengthR = p.APValues + p.stereolength;
            
            p.bAPL = zeros(length(p.APLengthL),max(p.APLengthL)+1);
            p.aAPL = zeros(length(p.APLengthL),max(p.APLengthL)+1);
            
            p.bAPR = zeros(length(p.APLengthR),max(p.APLengthR)+1);
            p.aAPR = zeros(length(p.APLengthR),max(p.APLengthR)+1);
                    
            % Calculate filter coefficients 
            calcCoeff(p);
            
            % Create empty buffers
            p.APBufferL = zeros(max(p.APLengthL),length(p.APValues));
            p.APBufferR = zeros(max(p.APLengthR),length(p.APValues));
           
            p.DryBuffer = zeros(9000, 2);
            p.WetBuffer = p.DryBuffer;
            p.SamplesPerFrame = 1024;
            p.FrameSize = 128;
            p.NumOfFrames = ceil(p.SamplesPerFrame/p.FrameSize);
        end
        
        function reset(p)
            % Emptry buffer  
            p.APBufferL = zeros(max(p.APLengthL),length(p.APValues));
            p.APBufferR = zeros(max(p.APLengthR),length(p.APValues));
           
            reset(p.CombDelay);
            reset(p.Lowpass);
        end
        function out = pComb(obj, x)
            in = zeros(obj.FrameSize,1,'like',x);
            l = size(x,1);
            in(1:l) = sum(x,2);
            t = repmat(0.015*in, 1,16);
            scaling = log2(7*obj.f+1)/log2(8);
            o = output(obj.CombDelay, t);
            update(obj.CombDelay, t + scaling*obj.Lowpass(o));
            out = [ sum(o(:,1:8),2) sum(o(:,9:16),2) ];
        end
        function out = rev(p, x)
            % for each channel
            % 4*2 parallel LBCF --> 4 AP
           
            if size(x,1) ~= p.SamplesPerFrame
               p.SamplesPerFrame = size(x,1);
               p.NumOfFrames = ceil(p.SamplesPerFrame/p.FrameSize);
            end
            if p.SamplesPerFrame <= 128
                p.WetBuffer(1:p.FrameSize,:) = pComb(p, x);
            else
                p.DryBuffer(1:p.SamplesPerFrame, :) = x;
                for i = 0:p.NumOfFrames-1
                    p.WetBuffer(i*p.FrameSize + 1 : (i+1)*p.FrameSize,:) = pComb(p, p.DryBuffer(i*p.FrameSize + 1 : (i+1)*p.FrameSize,:));                  
                end  
               % 
            end
            
            left = p.WetBuffer(1:p.SamplesPerFrame,1); right = p.WetBuffer(1:p.SamplesPerFrame,2);
            % 4 allpass filters in series
            for i = 1:length(p.APValues)
                [left, p.APBufferL(1:p.APValues(i), i)] = filter(p.bAPL(i,1:p.APLengthL(i) + 1), p.aAPL(i,1:p.APLengthL(i) + 1), left, p.APBufferL(1:p.APValues(i), i));
                [right, p.APBufferR(1:p.APValues(i) + p.stereospread, i)] = filter(p.bAPR(i,1:p.APValues(i) + p.stereospread + 1), p.aAPR(i,1:p.APValues(i) + p.stereospread + 1), right, p.APBufferR(1:p.APValues(i) + p.stereospread, i));
            end
            
            % Calculate separation between left and right, 0 and 1 yields maximum separation,
            % 0.5, both sides are send to both speakers   
            wet1 = 1-p.stereoseparation; wet2 = p.stereoseparation;
            wet = [left*wet1+right*wet2 right*wet1+left*wet2];
            
            % Mix the wet signal with the dry signal
            mix = p.Mix;
            out = (1-mix)*x + mix*(wet*(1-p.g)); % need to scale wet down in a smart way, else gets distorted. not super smart right now
        end
        % Calculate new coeffients every time a parameter has changed
        function set.f(p, f)
            p.f = f;
            calcCoeff(p);
        end
        function set.d(p, d)
            p.d = d;
            calcCoeff(p);
        end
        function set.g(p, g)
            p.g = g;
            calcCoeff(p);
        end
%         function set.stereospread(p, s)
%             p.stereospread = floor(s); % to make sure s is an integer
% %             release(p.pCombDelay);
% %             p.pCombDelay = dsp.Delay([p.cValues p.cValues + p.stereospread]);
%             calcCoeff(p);
%         end
        function calcCoeff(p)
            % Calculate filter coefficients
            %p.pCombDelay.Length(9:16) = p.cValues + p.stereospread;

%             p.pLowpass.Numerator = 1 - p.f;
%             p.pLowpass.Denominator = [1, -p.f];
            for i = 1:length(p.APValues)
                [p.bAPL(i, 1:p.APLengthL(i) + 1), p.aAPL(i, 1:p.APLengthL(i) + 1)] = APCoeffs(p.APValues(i), p.g);
                [p.bAPR(i, 1:p.APValues(i) + p.stereospread + 1), p.aAPR(i, 1:p.APValues(i) + p.stereospread + 1)] = APCoeffs(p.APValues(i) + p.stereospread, p.g);
            end
        end
        function out = process(plugin, x)
            out = rev(plugin, x);
        end
    end
end
% Transfer function from Smiths website
% function [b, a] = LBCFCoeffs(m, d, f)
%     % LBCF = z^-m/1-f(1-d/1-dz^-1)z^-m
%     % d = damp = initialdamp * scaledamp = 0.5 * 0.4 = 0.2
%     % f = roomsize = initialroom * scaleroom + offsetroom = 0.5 * 0.28 + 0.7 = 0.84
% 
%     b = [1 zeros(1,m) -d];
%     a = [1 -d zeros(1,m-1) -f*(1-d)];
% end
function [b, a] = APCoeffs(M, g)
    % All pass filters in series
    %   H(z) = (-g + z^-M )/ (1- g * z^M)
    b = [-1 zeros(1, M-1) 1+g];
    a = [1, zeros(1,M-1), -g];
end
