classdef Freeverb < audioPlugin
 % Freeverb
    %   This is an Audio System Toolbox implementation of the Freeverb
    %   created by Jezar at Dreampoint - http://www.dreampoint.co.uk 
    %   The implementation is guided by Julius O. Smith's description of
    %   the Freeverb implementation
    %   Webpage: 'Physical Audio Signal Processing', link: https://ccrma.stanford.edu/~jos/pasp/Freeverb.html  
    
    properties
        f = 0.82; % RoomSize
        g = 0.5;  % Gain of allpass filter
       
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
        combBuffer = zeros(128,1);
    end
    properties(Constant, Access = private)
        % M values for Comb and allpass filters
        APValues = [225, 556, 441, 341];
        cValues = [1557, 1617, 1491, 1422, 1277, 1356, 1188, 1116];
        stereospread = 23; % delay between left and right channel
        % lowpass coefficients
        bLow = 1-0.25; % 0.25 is the damping value
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
            'UniqueId', '1abf',...
            audioPluginParameter('f','DisplayName','Roomsize','Mapping',{'lin' 0 1}),...
            audioPluginParameter('g','DisplayName','Gain','Mapping',{'lin' 0.1 0.7}),...
            audioPluginParameter('stereoseparation','DisplayName','Stereoseparation','Mapping',{'lin' 0 1}),...
            audioPluginParameter('Mix','DisplayName','Mix','Mapping',{'lin' 0 1}));
    end
    
    methods
        function p = Freeverb
            % Comb filter implementation from dsp class. Inspired by audioexample.FreeverbReverberator
            p.Lowpass = dsp.IIRFilter('Numerator',p.bLow, 'Denominator', p.aLow);
            p.CombDelay = dsp.Delay([p.cValues, p.cValues + p.stereospread]);

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
           
            % Variables and buffers to keep track of signal framesize 
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
            p.combBuffer = zeros(128, 1);
            reset(p.CombDelay);
            reset(p.Lowpass);
        end
        function out = parallelComb(p, x) % function from audioexample.FreeverbReverberator, needed for efficiency
            l = size(x,1); % if the size of x is lower than 128 samples
            p.combBuffer(1:l) = sum(x,2); % sum left and right and add them to the buffer
            t = repmat(0.015*p.combBuffer, 1,16); % scale down the amplitude of the signal and make 16 copies
            scaling = log2(7*p.f+1)/log2(8); % scaling of the feedback component, needs to be less than one for stability 
            o = output(p.CombDelay, t); 
            update(p.CombDelay, t + scaling*p.Lowpass(o));
            out = [ sum(o(:,1:8),2) sum(o(:,9:16),2) ]; % sum the left 1:8 and right 9:16 together 
        end
        function out = rev(p, x)
            % for each channel
            % 8*2 parallel comb filters --> 4 AP    
            if size(x,1) ~= p.SamplesPerFrame % If the frameSize has changed
               p.SamplesPerFrame = size(x,1); % Update it and calculate new NumOfFrames
               p.NumOfFrames = ceil(p.SamplesPerFrame/p.FrameSize);
            end
            if p.SamplesPerFrame <= 128 % If the frame size is equal or below 128, run it through the comb filter
               p.WetBuffer(1:p.FrameSize,:) = parallelComb(p, x);
            else       
                p.DryBuffer(1:p.SamplesPerFrame, :) = x; % Else add the signal into the DryBuffer, 
                for i = 0:p.NumOfFrames-1                % and dividede the signal into 128 samples and run it through the comb filter 
                    p.WetBuffer(i*p.FrameSize + 1 : (i+1)*p.FrameSize,:) = parallelComb(p, p.DryBuffer(i*p.FrameSize + 1 : (i+1)*p.FrameSize,:));                  
                end   
            end
            % Cut of buffers to obtain original length again.
            left = p.WetBuffer(1:p.SamplesPerFrame,1); right = p.WetBuffer(1:p.SamplesPerFrame,2);
            % 4 allpass filters in series for both left and right channel
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
            out = (1-mix)*x + mix*wet; 
        end
        function set.f(p, f)
            p.f = f;
        end

        function set.g(p, g)
            p.g = g;
            calcCoeff(p); % Calculate new coeffients every time a parameter has changed
        end

        function calcCoeff(p)
            % Calculate filter coefficients           
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
function [b, a] = APCoeffs(M, g)
    % All pass filters in series
    %   H(z) = (-g + z^-M )/ (1- g * z^M)
    b = [-1 zeros(1, M-1) 1+g];
    a = [1, zeros(1,M-1), -g];
end
