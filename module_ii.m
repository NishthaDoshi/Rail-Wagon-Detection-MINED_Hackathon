clc; clear; close all;

%% USER SETUP & CALIBRATION
% Load the video file
videoFile = 'filled_wagons.mp4'; % Replace with your actual video file
vid = VideoReader(videoFile);

% Let the user define the ROI where wagons pass
figure; imshow(readFrame(vid)); 
title('Draw a rectangle around the wagon passage area and double-click inside to confirm');
h = imrect;
position = wait(h); % Get the rectangle coordinates
x1 = round(position(1));
y1 = round(position(2));
width = round(position(3));
height = round(position(4));

% Known wagon capacity (in cubic meters) based on design specifications.
wagonCapacity = 10; % Adjust to your wagon’s maximum fill volume

% Noise threshold for segmentation (remove small regions)
minAreaNoise = 50;  

%% INITIALIZATION
wagonCounter = 0;   % Count of wagons passed
wagonPresent = false;  % Flag to track if a wagon is currently in the ROI

% This variable will accumulate the binary material segmentation mask over multiple frames.
accumulatedMask = [];  

figure;

%% PROCESS VIDEO FRAMES
while hasFrame(vid)
    frame = readFrame(vid);
    
    % Crop only the selected region where wagons pass
    croppedFrame = imcrop(frame, [x1, y1, width, height]);
    grayFrame = rgb2gray(croppedFrame);
    
    %% STEP 1: Wagon Detection (Using Color Segmentation)
    hsvFrame = rgb2hsv(croppedFrame);
    % Assume wagons are painted blue (adjust these thresholds as needed)
    blueMask = (hsvFrame(:,:,1) > 0.55 & hsvFrame(:,:,1) < 0.7) & (hsvFrame(:,:,2) > 0.3);
    bluePixelPercentage = sum(blueMask(:)) / numel(blueMask);
    
    blueThreshold = 0.05;  % Experiment with this threshold
    
    if bluePixelPercentage > blueThreshold
        currWagonPresent = true;
    else
        currWagonPresent = false;
    end
    
    %% STEP 2: Accumulate Material Segmentation Data Over Frames
    if currWagonPresent
        wagonPresent = true;
        
        % Segment material in the current frame.
        % Option 1: Use Otsu’s method for thresholding
        level = graythresh(grayFrame);
        materialMask = imbinarize(grayFrame, level);
        
        % Remove small noisy regions.
        materialMask = bwareaopen(materialMask, minAreaNoise);
        
        % (Optional: If your material appears darker than the background, you might need to invert the mask.)
        % materialMask = imcomplement(materialMask);
        
        % Accumulate the segmentation mask using logical OR
        if isempty(accumulatedMask)
            accumulatedMask = materialMask;
        else
            accumulatedMask = accumulatedMask | materialMask;
        end
    else
        % If the wagon was previously present but now is gone,
        % compute the volume using the accumulated mask.
        if wagonPresent
            wagonCounter = wagonCounter + 1;
            fprintf('Wagon Count: %d\n', wagonCounter);
            
            % Compute the fill ratio: fraction of the ROI area marked as filled.
            fillRatio = sum(accumulatedMask(:)) / numel(accumulatedMask);
            
            % Estimated volume is the fill ratio multiplied by the known wagon capacity.
            volume_m3 = fillRatio * wagonCapacity;
            fprintf('Estimated Volume for Wagon %d: %.2f cubic meters\n', wagonCounter, volume_m3);
            
            % Reset for the next wagon.
            accumulatedMask = [];
            wagonPresent = false;
        end
    end
    
    %% STEP 3: Visualization
    imshow(frame); hold on;
    rectangle('Position', [x1, y1, width, height], 'EdgeColor', 'b', 'LineWidth', 3);
    title(sprintf('Wagon Count: %d', wagonCounter));
    hold off;
    drawnow;
end

disp('Processing complete.');
