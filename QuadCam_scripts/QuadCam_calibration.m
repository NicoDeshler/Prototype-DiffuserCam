% Load images.
camPics = imageDatastore({'single_cam_centered_PSF.png','PSF.png'});

% Read the first image from the image set.
PSF = readimage(camPics, 1);

% Initialize features for I(1)
grayImage = rgb2gray(PSF);
PSF_points = detectSURFFeatures(grayImage);
[PSF_features, PSF_points] = extractFeatures(grayImage, PSF_points);

% Initialize all the transforms to the identity matrix. Note that the
% projective transform is used here because the calibration target is fairly
% close to the camera. Had the scene been captured from a further distance,
% an affine transform would suffice.
numImages = numel(camPics.Files);
tforms(numImages) = projective2d(eye(3));

% Initialize variable to hold image sizes.
imageSize = zeros(numImages,2);

% Iterate over remaining image pairs
for n = 2:numImages
    % Read I(n).
    I = readimage(camPics, n);

    % Convert image to grayscale.
    grayImage = rgb2gray(I);

    % Save image size.
    imageSize(n,:) = size(grayImage);

    % Detect and extract SURF features for I(n).
    points = detectSURFFeatures(grayImage);
    [features, points] = extractFeatures(grayImage, points);

    % Find correspondences between I(n) and I(n-1).
    indexPairs = matchFeatures(features, PSF_features, 'Unique', true);

    matchedPoints = points(indexPairs(:,1), :);
    matchedPointsPrev = PSF_points(indexPairs(:,2), :);

    % Estimate the transformation between I(n) and I(n-1).
    tforms(n) = estimateGeometricTransform(matchedPoints, matchedPointsPrev,...
        'projective', 'Confidence', 99.9, 'MaxNumTrials', 2000);
end


% Compute the output limits  for each transform
for i = 1:numel(tforms)
    [xlim(i,:), ylim(i,:)] = outputLimits(tforms(i), [1 imageSize(i,2)], [1 imageSize(i,1)]);
end

maxImageSize = max(imageSize);

% Find the minimum and maximum output limits
xMin = min([1; xlim(:)]);
xMax = max([maxImageSize(2); xlim(:)]);

yMin = min([1; ylim(:)]);
yMax = max([maxImageSize(1); ylim(:)]);

% Width and height of panorama.
width  = round(xMax - xMin);
height = round(yMax - yMin);

% Initialize the "empty" panorama.
panorama = zeros([height width 3], 'like', I);

blender = vision.AlphaBlender('Operation', 'Binary mask', ...
    'MaskSource', 'Input port');

% Create a 2-D spatial reference object defining the size of the panorama.
xLimits = [xMin xMax];
yLimits = [yMin yMax];
panoramaView = imref2d([height width], xLimits, yLimits);

% Create the panorama.
for i = 1:numImages

    I = readimage(camPics, i);

    % Add border to orientation image
    border_size = 8;
    M = max(max(max(I)));
    I(1: 1+border_size, :, 1:3) = M;
    I(size(I,1)-border_size: size(I,1), :, 1:3) = M;
    I(:, 1: 1+border_size, 1:3) = M;
    I(:, size(I,2)-border_size: size(I,2), 1:3) = M;
       
    
    % Transform I into the panorama.
    warpedImage = imwarp(I, tforms(i), 'OutputView', panoramaView);

    % Generate a binary mask.
    mask = imwarp(true(size(I,1),size(I,2)), tforms(i), 'OutputView', panoramaView);

    % Overlay the warpedImage onto the panorama.
    panorama = step(blender, panorama, warpedImage, mask);
end

% Save the transforms
tforms = tforms(2:numImages);
save('cam_orientation_Tforms.mat', 'tforms')

% Write and show the camera perspectives/orientations
imwrite(panorama, 'QuadCam_Orienations.png')
figure
imshow(panorama)