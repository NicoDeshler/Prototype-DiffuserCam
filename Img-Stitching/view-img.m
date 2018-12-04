PSFsegmentsDir = fullfile('stitchImgs');
calibrationScene = imageDatastore(PSFsegmentsDir);
sortFiles(calibrationScene);

readimage(calibrationScene, 1);