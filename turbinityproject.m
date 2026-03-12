%% turbinity data, dates and imagines 

clear; close all; clc

% Load and combine .txt files

folderPath = '/Users/rachelelavagno/Downloads/turbinitydata';

fileList = dir('*.txt');
allText = [];

for k = 1:length(fileList)
    % Read each file
    fileContent = readtable(fileList(k).name, 'ReadVariableNames', true);
    % Append all data
    allText = [allText; fileContent];
end

% Sort by time
allText = sortrows(allText, "date", "ascend");

%% 
function data = myCustomRead(filename)
    % Directly read the file
    raw_data = imread(filename);

    % Ensure it is in the format you want (uint16)
    data = single(uint16(raw_data));
end
%% trial4 
% function data = myCustomRead(filename)
%     raw_data = single(imread(filename)) / 65535;
% 
%     % Assuming Channel 3 is Green and Channel 4 is Red (adjust for your sensor)
%     % NDTI = (Red - Green) / (Red + Green)
%     green = raw_data(:,:,3);
%     red = raw_data(:,:,4);
%     ndti = (red - green) ./ (red + green + 1e-6); % 1e-6 prevents divide by zero
% 
%     % Add NDTI as the 12th channel
%     data = cat(3, raw_data, ndti);
% end
%% trial2
% function data = myCustomRead(filename)
%     raw_data = imread(filename);
%     % Scaling is the most effective way to lower RMSE in satellite CNNs
%     data = single(raw_data) / 65535; 
% end
%% trial3 was to add 12th layer 

%%
imds = imageDatastore("/Users/rachelelavagno/Downloads/Turbidity_Images/",'FileExtensions',{'.tif'}, ...
'IncludeSubfolders',true, ...
'ReadFcn',@myCustomRead); 

%% testing 
img = read(imds);

%% matched date of imagine in datastore
% Get all file paths from the datastore
filePaths = imds.Files;

% Create a table of images with a 'Key' column (e.g., the date or ID)

imageInfo = table(filePaths, 'VariableNames', {'FullFilePath'});

% Example: Extracting a date string from the filename
% Adjust the regex based on your actual naming convention
imageInfo.DateKey = regexp(imageInfo.FullFilePath, '\d{4}-\d{2}-\d{2}', 'match', 'once');


%% 
% Convert both key columns to the standard 'string' type
imageInfo.DateKey = string(imageInfo.DateKey);
allText.date = string(allText.date);

% Now the innerjoin will work perfectly
matchedTurbidity = innerjoin(imageInfo, allText,'LeftKeys', 'DateKey', 'RightKeys','date');
% 
% % Remove any potential duplicates if the same date appeared in multiple files
matchedTurbidity = unique(matchedTurbidity, 'rows');

% Find the rows where 'turbidity' is NaN
nanRows = isnan(matchedTurbidity.turbidity);
 
% Deletes those rows from the table entirely
matchedTurbidity(nanRows, :) = []; 

%% I have a datatable with turbinity and images 
% I start to train CNN 
% Create the filtered image datastore
imdsMatched = imageDatastore(matchedTurbidity.FullFilePath, ...
    'ReadFcn', @myCustomRead);

%% 
% Ensure turbidity is a column vector of type double
%matchedTurbidity.turbidity(matchedTurbidity.turbidity < 0) = 0;
turbidityValues = single(matchedTurbidity.turbidity);

% Create labels datastore
labelsDS = arrayDatastore(turbidityValues);
%% 
cds = combine(imdsMatched, labelsDS);
%  Combine the images and the labels
%% Test the combined datastore
data = read(cds);
img = data{1};
lbl = data{2};

fprintf('Image size: %d x %d x %d\n', size(img,1), size(img,2), size(img,3));
fprintf('Turbidity value: %.2f\n', lbl);

%% define CNN architecture 
layers = [
    imageInputLayer([29 35 11], 'Normalization', 'none')

    convolution2dLayer(3, 16, 'Padding', 'same')
    batchNormalizationLayer
    reluLayer

    maxPooling2dLayer(2, 'Stride', 2) 

    convolution2dLayer(3, 32, 'Padding', 'same')
    batchNormalizationLayer
    reluLayer

    fullyConnectedLayer(64)
    reluLayer

    fullyConnectedLayer(1) 
    % Note: No regressionLayer here when using trainnet with "mse"
];

%% Training Options (updated for trainnet)
% We remove 'Metrics' because it's handled differently in the new version
options = trainingOptions('adam', ...
    'MaxEpochs', 50, ...
    'MiniBatchSize', 16, ...
    'InitialLearnRate', 1e-3, ...
    'Plots', 'training-progress', ...
    'Shuffle', 'every-epoch', ...
    'Verbose', false);

%% Start Training (Using trainnet) 
% Note: for regression, we specify 'mse' (Mean Squared Error) as the loss
net = trainnet(cds, layers, "mse", options);

%% run to save 
% Save the trained network to a file
save('OlifantsTurbidityModel.mat', 'net');

%%
% Use minibatchpredict instead of predict for datastores
predictedTurbidity = minibatchpredict(net, imdsMatched);

% Ensure actual values are in the same format for plotting
actualTurbidity = single(matchedTurbidity.turbidity);

%%
figure;
scatter(actualTurbidity, predictedTurbidity, 'filled', 'MarkerFaceAlpha', 0.6);
hold on;
plot([min(actualTurbidity) max(actualTurbidity)], [min(actualTurbidity) max(actualTurbidity)], 'r--', 'LineWidth', 2);
xlabel('Measured Turbidity (NTU)');
ylabel('CNN Predicted Turbidity (NTU)');
title('Olifants River Turbidity Prediction Performance');
grid on;

%% Calculate RMSE to see the average error
rmseVal = sqrt(mean((actualTurbidity - predictedTurbidity).^2));
fprintf('The average error (RMSE) is: %.2f NTU\n', rmseVal);

%% is it a good cnn ?
% The Verdict: It is Good (B grade).
%  An error of ~21 NTU means the model can definitely
%  distinguish between "Clear," "Moderate," and "Highly Turbid" water.
% 
% The Challenge: If you are trying to tell the difference
%  between 5 NTU and 15 NTU (which is critical for drinking
%  water standards), an error of 21 is too high.
%  If you are just mapping general sediment plumes in
%  the Olifants River, this is already very useful.