PSFsegmentsDir = fullfile('stitchImgs');
calibrationScene = imageDatastore(PSFsegmentsDir);
sortFiles(calibrationScene);

I = readimage(calibrationScene, 1);