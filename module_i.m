clc; clear; close all;

% Load the video file
videoFile = 'empty_wagons.mp4'; % Replace with actual video file
vid = VideoReader(videoFile);

% Define the ROI where wagons pass
figure; imshow(readFrame(vid)); 
title('Draw a rectangle around the wagon passage area and double-click inside to confirm');

% Let the user define the wagon passage region
h = imrect;
position = wait(h); % Get the rectangle coordinates
x1 = round(position(1));
y1 = round(position(2));
width = round(position(3));
height = round(position(4));

% Initialize parameters
minDamageArea = 50; % Minimum area for valid damage
damageSensitivity = 0.85; % Higher sensitivity for white spots

wagonCounter = 0; % Wagon count
wagonPresent = false; % Tracks if a wagon is inside the region

% Loop through each frame
while hasFrame(vid)
    frame = readFrame(vid);
    
    % Crop only the selected region where wagons pass
    croppedFrame = imcrop(frame, [x1, y1, width, height]);
    grayFrame = rgb2gray(croppedFrame);
    
    % Step 1: Wagon Detection Using Color Segmentation (Detect Blue Wagons)
    hsvFrame = rgb2hsv(croppedFrame);
    blueMask = (hsvFrame(:,:,1) > 0.55 & hsvFrame(:,:,1) < 0.7) & (hsvFrame(:,:,2) > 0.3); 

    % Compute the percentage of blue pixels
    bluePixelPercentage = sum(blueMask(:)) / numel(blueMask);
    
    % Define threshold for detecting a wagon
    blueThreshold = 0.05; % Adjust based on real data
    
    % Determine if a wagon is present inside the region
    if bluePixelPercentage > blueThreshold
        currWagonPresent = true;
    else
        currWagonPresent = false;
    end

    % Increase count only when a wagon enters and then exits
    if wagonPresent && ~currWagonPresent
        wagonCounter = wagonCounter + 1;
        fprintf('Wagon Count: %d\n', wagonCounter);
    end

    wagonPresent = currWagonPresent; % Update the wagon state
    
    % Step 2: Damage Detection Inside Wagon (Same as Before)
    wagonMask = grayFrame < 100; % Thresholding to isolate the wagon
    
    % Morphological operations to refine the wagon region
    wagonMask = imclose(wagonMask, strel('rectangle', [10, 10]));
    wagonMask = imfill(wagonMask, 'holes');
    
    % Apply mask to focus on wagon interior only
    wagonInterior = grayFrame;
    wagonInterior(~wagonMask) = 0; % Zero out non-wagon areas
    
    % Detect edges (multi-scale)
    edges = edge(wagonInterior, 'Canny', [0.2, 0.5]);
    edges = imdilate(edges, strel('disk', 2)); % Enhance edges
    
    % Segment white spots (damage) using adaptive thresholding
    damageMask = imbinarize(wagonInterior, 'adaptive', 'Sensitivity', damageSensitivity);
    damageMask = damageMask & edges; % Combine edges with thresholding
    
    % Remove small noise
    damageMask = bwareaopen(damageMask, minDamageArea);
    
    % Step 3: Label and Highlight Damage
    [damageLabels, damageNum] = bwlabel(damageMask);
    damageStats = regionprops(damageLabels, 'BoundingBox', 'Area');
    
    % Display results
    imshow(frame);
    hold on;

    % Draw Bounding Box for Selected Wagon Region
    rectangle('Position', [x1, y1, width, height], 'EdgeColor', 'b', 'LineWidth', 3); 

    % Highlight detected damage areas
    for k = 1:length(damageStats)
        bbox = damageStats(k).BoundingBox;
        bbox(1) = bbox(1) + x1;
        bbox(2) = bbox(2) + y1;
        rectangle('Position', bbox, 'EdgeColor', 'r', 'LineWidth', 2);
    end
    
    % Display the current wagon count
    title(sprintf('Wagon Count: %d', wagonCounter));
    hold off;
    drawnow; % Refresh display
end

disp('Processing complete.');
