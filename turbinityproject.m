%% turbinity data, dates and imagines 

clear all; close all; clc

% Load and combine .txt files

folderPath = '/Users/rachelelavagno/Downloads/turbinitydata'

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


%% data from sentinel 2 (2023)   
%u = readtable('/Users/rachelelavagno/Documents/git/Remote-Sensing-Water-Quality/sediment_data.23.txt')

%%  
% Initialize a new column in Table u to store the results
% We fill it with NaN (Not a Number) as a placeholder
%u.Matchedturbidity = NaN(height(u), 1);

% Loop through every row of Table A
% for i = 1:height(u)
% 
%     % Get the date from Var7 for the current row
%     currentDate = u.Var7(i);
% 
%     % Find the row index in u where the dates match
%     % This returns a logical array (0s and 1s)
%     matchIndex = allText.date == currentDate;
% 
%     % Check if a match was actually found
%     if any(matchIndex)
%         % Assign the turbidity value from Alltext to u
%         u.Matchedturbidity(i) = allText.turbidity(matchIndex);
%     end
% end


%% repeat for data turbinity z j (2024 and 2025) 
% z = readtable('/Users/rachelelavagno/Documents/git/Remote-Sensing-Water-Quality/sediment_data.24.txt')
% j = readtable('/Users/rachelelavagno/Documents/git/Remote-Sensing-Water-Quality/sediment_data.25.txt')

%%
% for 2024 z 
% z.Matchedturbidity = NaN(height(z), 1);
% 
% for i = 1:height(z)
% 
%     currentDate = z.Var7(i);
% 
%     matchIndex = allText.date == currentDate;
% 
%     if any(matchIndex)
% 
%         z.Matchedturbidity(i) = allText.turbidity(matchIndex);
%     end
% end

%%
% for 2025 j
% j.Matchedturbidity = NaN(height(j), 1);
% 
% for i = 1:height(j)
% 
%     currentDate = j.Var7(i);
% 
%     matchIndex = allText.date == currentDate;
% 
%     if any(matchIndex)
% 
%         j.Matchedturbidity(i) = allText.turbidity(matchIndex);
%     end
% end


%% Final Table date turbinity 
% % u
% T1 = u(:, {'Var7', 'Matchedturbidity'});
% T1.Properties.VariableNames = {'Date', 'Turbidity'};
% 
% % z 
% T2 = z(:, {'Var7', 'Matchedturbidity'}); 
% T2.Properties.VariableNames = {'Date', 'Turbidity'};
% 
% % j
% T3 = j(:, {'Var7', 'Matchedturbidity'});
% T3.Properties.VariableNames = {'Date', 'Turbidity'};
% 
% FinalTable = [T1; T2; T3]; 
% 
% FinalTable = sortrows(FinalTable, 'Date');
% 
% % find indices where Turbidity is NOT NaN
% rowsWithData = ~isnan(FinalTable.Turbidity); 
% % Keep only those rows
% FinalTable = FinalTable(rowsWithData, :);
% 
% % Display or Save the result
% disp(FinalTable); 

%% 
% (date format: "Balule_2025-01-01 00:00:00.tif" transform to
% "Balule_2023-03-09.tif")

%% collect in a table 

% FinalTable.FileName = repmat("", height(FinalTable), 1);
% st = string(FinalTable{:, 1});
% 
% % Use string arithmetic to create the whole column at once
% FinalTable.FileName = "Balule_" + st + ".tif";

%% name imagines 
% Set your base folder path
% folderPath = "/Users/rachelelavagno/Downloads/Turbidity_Images/";
% 
% % Extract the dates and convert to strings
% st = string(FinalTable{:, 1});
% 
% % Construct filenames
% % On Mac, if a file appears to have a ":" in Finder, 
% % MATLAB/UNIX usually sees it as a "/" so replace it
% fn = "Balule_" + st + ".tif";
% 
% 
% % Create the full paths
% FinalTable.FullFilePath = folderPath + fn;

%% Create the Datastore with imagines plus turbinity at every date 
% We use cellstr to ensure compatibility with older MATLAB versions
% = imageDatastore(cellstr(FinalTable.FullFilePath));
function data = myCustomRead(filename)
    % This reads all bands of a multi-layer TIFF
    info = imfinfo(filename);
    numberOfBands = numel(info);
    
    % Initialize a 3D array (Height x Width x Bands)
    data = zeros(info(1).Height, info(1).Width, numberOfBands, 'uint16'); 
    
    for k = 1:numberOfBands
        data(:,:,k) = imread(filename, k);
    end
end

imds = imageDatastore("/Users/rachelelavagno/Downloads/Turbidity_Images/",'FileExtensions',{'.tif'}, ...
'IncludeSubfolders',true, ...
'ReadFcn',@myCustomRead); 

%%

dataFolder = "/Users/rachelelavagno/Downloads/Turbidity_Images/"; 

imds = imageDatastore(dataFolder, ...
    'FileExtensions', {'.tif'}, ...
    'IncludeSubfolders', true, ...
    'ReadFcn', @myCustomRead); 
%%  
% 1. Create a datastore for the turbidity values (labels)
% We extract the turbidity values from your FinalTable
labelDatastore = arrayDatastore(FinalTable.Turbidity);

% 2. Combine the images and the labels
% This is essential so they stay synchronized during training
cds = combine(imds, labelDatastore);

%%

% Get the size of one image to set the input layer
sampleImg = read(imds);
[height, width, channels] = size(sampleImg);

layers = [
    imageInputLayer([height width channels], 'Name', 'input')
    
    imds
    convolution2dLayer(3, 16, 'Padding', 'same')
    batchNormalizationLayer
    reluLayer
    
    maxPooling2dLayer(2, 'Stride', 2)
    
    convolution2dLayer(3, 32, 'Padding', 'same')
    batchNormalizationLayer
    reluLayer
    
    fullyConnectedLayer(64)
    reluLayer
    
    % The most important part for Regression:
    fullyConnectedLayer(1) % One output (Turbidity value)
    regressionLayer        % Tells MATLAB to calculate Mean Squared Error
];