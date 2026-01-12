clear all; close all; clc

% Load and combine .txt files
folderPath = 'C:\Users\miriamfreer\Desktop\Research\Fall 2025\KrugerSensors\Olifants River\Balule\Dissovled Oxygen\7450-894360 Balule DO Jan25';
%cd(folderPath) % Move to folder

fileList = dir('*.txt');
allText = [];

for k = 1:length(fileList)
    % Read each file
    fileContent = readtable(fileList(k).name, 'ReadVariableNames', true);
    % Append all data
    allText = [allText; fileContent];
end

% Sort by time
allText = sortrows(allText, "Time_sec_", "ascend");

% Convert from epoch seconds to datetime
t = table2array(allText(:,"Time_sec_"));
datetimeCol = datetime(1970,1,1,0,0,0) + seconds(t);
allText.DateTime = datetimeCol;

% Keep only rows where DO and DateTime are valid
validSensor = ~isnan(allText.DO_mg_l_) & ~isnat(allText.DateTime);
allText_clean = allText(validSensor, :);

% --- NEW SECTION: Daily average DO minus 3.8 and set negatives to zero ---

% Extract the date (no time) for grouping
allText_clean.DateOnly = dateshift(allText_clean.DateTime, 'start', 'day');

% Compute daily average DO
dailyDO = groupsummary(allText_clean, "DateOnly", "mean", "DO_mg_l_");

% Subtract 3.8 from the daily mean
dailyDO.mean_DO_mg_l_ = dailyDO.mean_DO_mg_l_ - 3.8;

% Replace any negative values with 0
dailyDO.mean_DO_mg_l_(dailyDO.mean_DO_mg_l_ < 0) = 0;

% Optional: merge back to allText_clean if you want each timestamp to have
% the adjusted daily value
allText_clean = outerjoin(allText_clean, dailyDO(:,["DateOnly","mean_DO_mg_l_"]), ...
    "Keys", "DateOnly", "MergeKeys", true);

% Rename for clarity
allText_clean.Properties.VariableNames{'mean_DO_mg_l_'} = 'DO_daily_adjusted';



bal_jacques = readtable("Copy of Balule quality data David.xlsx");

% Standardize variable names (removes hidden spaces, punctuation, etc.)
bal_jacques.Properties.VariableNames = matlab.lang.makeValidName( ...
    strtrim(bal_jacques.Properties.VariableNames));



% Ensure Time column is a string array
if iscell(bal_jacques.Time)
    timeStr = string(bal_jacques.Time);
elseif iscategorical(bal_jacques.Time)
    timeStr = string(bal_jacques.Time);
else
    timeStr = bal_jacques.Time; % already string
end

% Replace 'h' with ':' to make times MATLAB-friendly
timeStr = strrep(timeStr, 'h', ':');

% Combine Date + Time
dateStr = strcat(string(bal_jacques.Date), " ", timeStr);

% Convert to datetime using correct format
t_bal = datetime(dateStr, 'InputFormat', 'dd-MMM-yyyy HH:mm');

% Add to table
bal_jacques.DateTime = t_bal;

validRows = ~isnan(bal_jacques.DOMg_l) & ~isnat(bal_jacques.DateTime);
bal_jacques_clean = bal_jacques(validRows, :);


plot(allText_clean.DateTime, allText_clean.DO_daily_adjusted, 'b', 'DisplayName','Sensor DO');
hold on;
plot(bal_jacques_clean.DateTime, bal_jacques_clean.DOMg_l, 'r*', 'DisplayName','Manual DO');
legend('show');

% Axis formatting
title('Balule Dissolved Oxygen (25 Nov 2024 – 31 Jan 2025)');
xlabel('Date');
ylabel('Dissolved Oxygen (mg/L)');
ylim([0 8]);
yline(5, 'r', 'DisplayName', 'Minimum Accepted Value of DO')

% Define the date range
startDate = datetime(2024,11,25);
endDate = datetime(2025,1,13);


% Set x-axis limits
xlim([startDate endDate]);

% Create ticks every other day
xticks(startDate:2:endDate);

% Format tick labels
ax.XAxis.TickLabelFormat = 'MMM dd, yyyy';
ax.XTickLabelRotation = 45;
