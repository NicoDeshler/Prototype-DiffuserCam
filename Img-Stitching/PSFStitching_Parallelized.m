%% STITCH SEGMENTED PSF IMAGES
% Author: Nico Deshler
%  
% RECOMMENDATIONS:
% 1) Ensure there is ~30-50% overlap between adjacent images
%
% 2) The image filenames should be numbered in the sequence that you wish
%    to compute the tranformation between adjacent images. Since the 
%    caustics tend to blur in the peripheral images due to high 
%    angles-of-illumination, it is recommended that the images be numbered 
%    as corresponding to spiraled indices (see example)
%
%                   25|24|23|22|21
%                   10|09|08|07|20
%                   11|02|01|06|19
%                   12|03|04|05|18
%                   13|14|15|16|17
%

% Write/Read Image File Paths
PSFsegmentsDir = fullfile('cam_imgs');
% PSFsavePath = fullfile('Stitched PSF - 5x5cm Diffuser','PSFs', 'recon_PSF.tif');

% Instantiate image data store.
calibrationScene = imageDatastore(PSFsegmentsDir);
sortFiles(calibrationScene);
num_imgs = numel(calibrationScene.Files);

% Compress images if need be (overwrites existing images)
scale = 0;
if scale 
    for i = 1:num_imgs
        im = readimage(calibrationScene,i);
        fname = calibrationScene.Files{i};
        im = imresize(im, scale);
        imwrite(im, fname)
    end
end

% Image type states
imgType = readimage(calibrationScene, 1);
imgSize = size(imgType);
isRGB = size(imgType,3) == 3;


%{
% Make signal suppression pyramid to remove background in
cross-correlation
[X,Y] = meshgrid(1:imgSize(2), 1:imgSize(1));
quarter_pyramid = X.*Y;
pyramid = [[quarter_pyramid fliplr(quarter_pyramid(:,1:end-1))] ;...
          flipud([quarter_pyramid(1:end-1, :) fliplr(quarter_pyramid(1:end-1,1:end-1))])];
pyramid_peak = max(max(pyramid));
%}

% Create array image transformations initialized to the identity matrix
tforms(num_imgs) = affine2d(eye(3));

for n = 2:num_imgs
    % Set adjacent images to variables
    if isRGB
        imgA = rgb2gray(readimage(calibrationScene,n-1));
        imgB = rgb2gray(readimage(calibrationScene,n));
    else
        imgA = mat2gray(readimage(calibrationScene,n-1));
        imgB = mat2gray(readimage(calibrationScene,n));
    end
    
    % Threshold the image to remove DC Term that causes peak.
    imgA = imgA/max(imgA(:));
    imgB = imgB/max(imgB(:));
    threshold = .3;
    imgA = imgA > threshold;  % changes imgA to binary values, based on comparison
    imgB = imgB > threshold;
       
    % Determine the image transformation by locating peak in cross
    % correlation
    midpt = imgSize(:,:,1);
    xCorr = xcorr2_fft(imgA, imgB);
    maximum = max(max(xCorr));
    [delY, delX] = find(xCorr == maximum,1);
    tforms(n).T = [1, 0, 0; 0, 1, 0; delX-midpt(2), delY-midpt(1), 1];  % TODO should midpt(1) and midpt(2) be flipped??
    % well, rn doesnt matter bc height == width.
    x = delX-midpt(2);
    y = delY-midpt(1);
    %{
    xi_1 = [abs(x) imgSize(1)];
    xi_2 = [1 imgSize(1)-abs(x)];
    xi_3 = [1 imgSize(1)];
    yi_1 = [abs(y) imgSize(2)];
    yi_2 = [1 imgSize(2)-abs(y)];
    yi_3 = [1 imgSize(2)];
    
    if x < 0
        xi_a = xi_2;
        xi_b = xi_1;
    elseif x > 0
        xi_a = xi_1;
        xi_b = xi_2;
    else 
        xi_a = xi_3;
        xi_b = xi_3;
    end    
    
    if y < 0
        yi_a = yi_1;
        yi_b = yi_2;
    elseif y > 0
        yi_a = yi_2;
        yi_b = yi_1;
    else
        yi_a = yi_3;
        yi_b = yi_3;
    end
    
    color_imgA = readimage(calibrationScene,n-1);
    color_imgB = readimage(calibrationScene,n);
    overlapA = color_imgA(yi_a(1):yi_a(2), xi_a(1):xi_a(2), :);
    overlapB = color_imgB(yi_b(1):yi_b(2), xi_b(1):xi_b(2), :);    
    %imshow(imgB(yi_b(1):yi_b(2), xi_b(1):xi_b(2)));
    alpha = mean2(overlapA) / mean2(overlapB);
    imwrite(alpha * color_imgB, calibrationScene.Files{n});
    %}
end

% Make transforms sequential.
for n = 2:numel(tforms)
    tforms(n).T = tforms(n-1).T * tforms(n).T;
end

% Identify the limits of the image transformations.
for n = 1:numel(tforms)
    [xlim(n,:), ylim(n,:)] = outputLimits(tforms(n), [1 imgSize(2)], [1 imgSize(1)]);
end

% Find the minimum and maximum output limits.
xMin = min([1; xlim(:)]);
xMax = max([imgSize(2); xlim(:)]);

yMin = min([1; ylim(:)]);
yMax = max([imgSize(1); ylim(:)]);

% Width and height of panorama.
width  = round(xMax - xMin);
height = round(yMax - yMin);

% Initialize the "empty" panorama.
if isRGB
    panorama = zeros([height width 3], 'like', imgType);
else
    panorama = zeros([height width], 'like', imgType);
end

% Initialize blending operator.
blender = vision.AlphaBlender('Operation', 'Binary mask', 'MaskSource', 'Input port');

% Create a 2-D spatial reference object defining the size of the panorama.
xLimits = [xMin xMax];
yLimits = [yMin yMax];
panoramaView = imref2d([height width], xLimits, yLimits);

% Create the panorama.
for n = 1:num_imgs
    
    I = readimage(calibrationScene, n);

    % Transform I into the panorama.
    warpedImage = imwarp(I, tforms(n), 'OutputView', panoramaView);

    % Generate a binary mask.
    mask = imwarp(true(size(I,1),size(I,2)), tforms(n), 'OutputView', panoramaView);
    
    % Overlay the warpedImage onto the panorama.
    panorama = step(blender, panorama, warpedImage, mask);
    
end
imwrite(panorama, 'panorama.png');
% figure; imshow(panorama)

function sortFiles(imdatastore)
    %Sorts the images in the data store based on their linear index.
    fileNames = imdatastore.Files;

    str_suffix = regexp(fileNames,'\d*','match');
    dub_suffix = str2double(cat(1,str_suffix{:}));

    [~,ii] = sortrows(dub_suffix, size(dub_suffix, 2));
    sortedFiles = fileNames(ii);
    imdatastore.Files = sortedFiles;

end
