classdef Freeverb < audioPlugin
    % Freeverb by Nikolaj Andersson
    %   This is an Audio System Toolbox implementation of the Freeverb
    %   created by Jezar at Dreampoint - http://www.dreampoint.co.uk
    %   The implementation is guided by Julius O. Smith's description of
    %   the Freeverb implementation.
    %   Webpage: 'Physical Audio Signal Processing', link: https://ccrma.stanford.edu/~jos/pasp/Freeverb.html
    
    properties
        f = 0.84; % RoomSize
        g = 0.5;  % Gain of allpass filter
        
        stereoseparation = 0;
        Mix = 0.5;
    end
    properties (Access = private)
        SamplesPerFrame
        FrameSize
        NumOfFrames
        
        DryBuffer
        WetBuffer
        
        combBuffer = zeros(128,1);
        AllpassBuffer = zeros(128,2);
        
        CombDelay
        Lowpass
        AllpassL1
        AllpassL2
        AllpassL3
        AllpassL4
        AllpassR1
        AllpassR2
        AllpassR3
        AllpassR4
    end
    properties(Constant, Access = private)
        % M values for Comb and allpass filters
        AllpassDelayLength = [556, 441, 341, 225];
        CombDelayLength = [1557, 1617, 1491, 1422, 1277, 1356, 1188, 1116];
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
            'VendorVersion', '5.0', ...
            'UniqueId', '1abg',...
            audioPluginParameter('f','DisplayName','RoomSize','Mapping',{'lin' 0 1}),...
            audioPluginParameter('stereoseparation','DisplayName','Stereoseparation','Mapping',{'lin' 0 1}),...
            audioPluginParameter('Mix','DisplayName','Mix','Mapping',{'lin' 0 1}));
    end
    methods
        function p = Freeverb
            % Comb filter implementation from dsp class. Inspired by audioexample.FreeverbReverberator
            p.Lowpass = dsp.IIRFilter('Numerator',p.bLow, 'Denominator', p.aLow);
            p.CombDelay = dsp.Delay([p.CombDelayLength, p.CombDelayLength + p.stereospread]);
            % Set up allpass section
            allpassFeedback = 0.5;
            
            APcoeffsL1 = [1, zeros(1, p.AllpassDelayLength(1)-1), -allpassFeedback];
            APcoeffsL2 = [1, zeros(1, p.AllpassDelayLength(2)-1), -allpassFeedback];
            APcoeffsL3 = [1, zeros(1, p.AllpassDelayLength(3)-1), -allpassFeedback];
            APcoeffsL4 = [1, zeros(1, p.AllpassDelayLength(4)-1), -allpassFeedback];
            APcoeffsR1 = [1, zeros(1, p.AllpassDelayLength(1)+p.stereospread-1), -allpassFeedback];
            APcoeffsR2 = [1, zeros(1, p.AllpassDelayLength(2)+p.stereospread-1), -allpassFeedback];
            APcoeffsR3 = [1, zeros(1, p.AllpassDelayLength(3)+p.stereospread-1), -allpassFeedback];
            APcoeffsR4 = [1, zeros(1, p.AllpassDelayLength(4)+p.stereospread-1), -allpassFeedback];
            
            p.AllpassL1 = dsp.IIRFilter('Numerator', fliplr(APcoeffsL1), ...
                'Denominator', APcoeffsL1);
            p.AllpassL2 = dsp.IIRFilter('Numerator', fliplr(APcoeffsL2), ...
                'Denominator', APcoeffsL2);
            p.AllpassL3 = dsp.IIRFilter('Numerator', fliplr(APcoeffsL3), ...
                'Denominator', APcoeffsL3);
            p.AllpassL4 = dsp.IIRFilter('Numerator', fliplr(APcoeffsL4), ...
                'Denominator', APcoeffsL4);
            p.AllpassR1 = dsp.IIRFilter('Numerator', fliplr(APcoeffsR1), ...
                'Denominator', APcoeffsR1);
            p.AllpassR2 = dsp.IIRFilter('Numerator', fliplr(APcoeffsR2), ...
                'Denominator', APcoeffsR2);
            p.AllpassR3 = dsp.IIRFilter('Numerator', fliplr(APcoeffsR3), ...
                'Denominator', APcoeffsR3);
            p.AllpassR4 = dsp.IIRFilter('Numerator', fliplr(APcoeffsR4), ...
                'Denominator', APcoeffsR4);
            
            % Variables and buffers to keep track of signal framesize
            p.DryBuffer = zeros(9000, 2);
            p.WetBuffer = p.DryBuffer;
            p.SamplesPerFrame = 1024;
            p.FrameSize = 128;
            p.NumOfFrames = ceil(p.SamplesPerFrame/p.FrameSize);
        end
        function reset(p)
            % Emptry buffer
            % p.APBufferL = zeros(max(p.APLengthL),length(p.APValues));
            % p.APBufferR = zeros(max(p.APLengthR),length(p.APValues));
            p.combBuffer = zeros(128, 1);
            p.AllpassBuffer = zeros(128, 2);
            
            reset(p.CombDelay);
            reset(p.Lowpass);
            
            reset(p.AllpassL1);
            reset(p.AllpassL2);
            reset(p.AllpassL3);
            reset(p.AllpassL4);
            reset(p.AllpassR1);
            reset(p.AllpassR2);
            reset(p.AllpassR3);
            reset(p.AllpassR4);
        end
        function out = parallelComb(p, x) % function from audioexample.FreeverbReverberator, needed for efficiency
            l = size(x,1); % if the size of x is lower than 128 samples
            p.combBuffer(1:l) = sum(x,2); % sum left and right and add them to the buffer
            t = repmat(0.015*p.combBuffer, 1,16); % scale down the amplitude of the signal and make 16 copies
            scaling = log2(7*p.f+1)/log2(8); % mapping of the feedback coefficient, needs to be less than one for stability
            o = output(p.CombDelay, t); % Delay the input and create delay variable o
            update(p.CombDelay, t + scaling*p.Lowpass(o)); % Lowpass filter the delay, scale it by mapped f and add the dry input
            out = [ sum(o(:,1:8),2) sum(o(:,9:16),2) ]; % sum the columns together - 1:8 for left and 9:16 for right
        end
        function out = seriesAllPass(p, x)
            l = size(x,1); % if the size of x is lower than 128 samples
            p.AllpassBuffer(1:l,:) = x;
            out = zeros(size(p.AllpassBuffer));
            out(:,1) = p.AllpassL4(p.AllpassL3(...
                p.AllpassL2(p.AllpassL1(p.AllpassBuffer(:,1)))));
            out(:,2) = p.AllpassR4(p.AllpassR3(...
                p.AllpassR2(p.AllpassR1(p.AllpassBuffer(:,2)))));
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
                p.WetBuffer(1:p.FrameSize,:) = seriesAllPass(p, p.WetBuffer(1:p.FrameSize,:));
            else
                p.DryBuffer(1:p.SamplesPerFrame, :) = x; % Else add the signal into the DryBuffer,
                for i = 0:p.NumOfFrames-1                % and dividede the signal into 128 samples and run it through the comb filter
                    p.WetBuffer(i*p.FrameSize + 1 : (i+1)*p.FrameSize,:) = parallelComb(p, p.DryBuffer(i*p.FrameSize + 1 : (i+1)*p.FrameSize,:));
                    p.WetBuffer(i*p.FrameSize + 1 : (i+1)*p.FrameSize,:) = seriesAllPass(p, p.WetBuffer(i*p.FrameSize + 1 : (i+1)*p.FrameSize,:));
                end
            end
            % Cut of buffers to obtain original length again.
            left = p.WetBuffer(1:p.SamplesPerFrame,1); right = p.WetBuffer(1:p.SamplesPerFrame,2);
            
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
        function out = process(plugin, x)
            out = rev(plugin, x);
        end
    end
end
