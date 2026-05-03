function license_plate_reader_app
% LICENSE_PLATE_READER_APP
% Full GUI that uses your existing detection, preprocessing, OCR, and state mapping

%% ===== Figure & Layout =====
fig = uifigure('Name','License Plate Reader','Position',[100 100 1100 650]);
g = uigridlayout(fig,[6 6]);
g.RowHeight   = {40, '1x', '1x', 40, '1x', 40};
g.ColumnWidth = {180, '1x', '1x', '1x', 220, 180};

% Controls
btnOpen   = uibutton(g,'Text','Open Image','ButtonPushedFcn',@onOpen);
btnRun    = uibutton(g,'Text','Run Detection','ButtonPushedFcn',@onRun);
btnBatch  = uibutton(g,'Text','Batch Folder','ButtonPushedFcn',@onBatch);
btnExport = uibutton(g,'Text','Export CSV','ButtonPushedFcn',@onExport);
btnOpen.Layout.Row = 1; btnOpen.Layout.Column = 1;
btnRun.Layout.Row  = 1; btnRun.Layout.Column  = 2;
btnBatch.Layout.Row= 1; btnBatch.Layout.Column= 3;
btnExport.Layout.Row=1; btnExport.Layout.Column=4;

% Image panels
axOriginal = uiaxes(g); title(axOriginal,'Original'); axis(axOriginal,'off');
axOriginal.Layout.Row = 2; axOriginal.Layout.Column = [1 3];
axCropped = uiaxes(g);  title(axCropped,'Cropped Plate'); axis(axCropped,'off');
axCropped.Layout.Row = 2; axCropped.Layout.Column = [4 6];
axEnhanced = uiaxes(g); title(axEnhanced,'Enhanced'); axis(axEnhanced,'off');
axEnhanced.Layout.Row = 3; axEnhanced.Layout.Column = [1 6];

% Result labels
lblPlate = uilabel(g,'Text','Plate: -','FontWeight','bold');
lblState = uilabel(g,'Text','State: -','FontWeight','bold');
lblPlate.Layout.Row=4; lblPlate.Layout.Column=[1 3];
lblState.Layout.Row=4; lblState.Layout.Column=[4 6];

% Results table
tbl = uitable(g,'ColumnName',{'File','Plate','State','Time_s','OK'});
tbl.Layout.Row=5; tbl.Layout.Column=[1 6];

% Status
lblStatus = uilabel(g,'Text','Ready.');
lblStatus.Layout.Row=6; lblStatus.Layout.Column=[1 6];

% App state
state.img = [];
state.imgPath = '';
setappdata(fig,'state',state);

%% ===== Callbacks =====
    function onOpen(~,~)
        state = getappdata(fig,'state');
        [f,p] = uigetfile({'*.jpg;*.jpeg;*.png','Images'});
        if isequal(f,0), return; end
        state.imgPath = fullfile(p,f);
        state.img = imread(state.imgPath);
        cla(axOriginal); imshow(state.img,'Parent',axOriginal);
        title(axOriginal,f,'Interpreter','none');
        cla(axCropped); cla(axEnhanced);
        lblPlate.Text="Plate: -"; lblState.Text="State: -";
        lblStatus.Text="Image loaded.";
        setappdata(fig,'state',state);
    end

    function onRun(~,~)
        state = getappdata(fig,'state');
        if isempty(state.img), uialert(fig,'Open an image first.','Error'); return; end
        t0 = tic;
        [bbox, plateText] = detect_license_plate(state.img);

        if isempty(bbox)
            roi = detect_plate_roi(state.img);
            if isempty(roi)
                lblStatus.Text="No plate detected."; return;
            end
            plateRegion = imcrop(state.img,roi);
        else
            plateRegion = imcrop(state.img,bbox);
        end
        imshow(plateRegion,'Parent',axCropped);

        enhanced = preprocess_image(plateRegion);
        imshow(enhanced,'Parent',axEnhanced);

        if isempty(plateText)
            [~, plateText] = detect_license_plate(enhanced);
        end
        if isempty(plateText)
            plateText = segment_characters(enhanced);
        end

        plateText = regexprep(upper(strtrim(plateText)),'\s+','');
        st = map_state_from_prefix(plateText);

        lblPlate.Text="Plate: "+plateText;
        lblState.Text="State: "+st;
        lblStatus.Text=sprintf('Done in %.2fs',toc(t0));

        % Add row
        row = {string(basename(state.imgPath)), string(plateText), string(st), toc(t0), ~isempty(plateText)};
        if isempty(tbl.Data)
            tbl.Data = cell2table(row,'VariableNames',tbl.ColumnName);
        else
            tbl.Data = [tbl.Data; cell2table(row,'VariableNames',tbl.ColumnName)];
        end
    end

    function onBatch(~,~)
        d = uigetdir(pwd,'Select folder with images');
        if isequal(d,0), return; end
        imgs = [dir(fullfile(d,'*.jpg')); dir(fullfile(d,'*.png')); dir(fullfile(d,'*.jpeg'))];
        for i=1:numel(imgs)
            I = imread(fullfile(imgs(i).folder,imgs(i).name));
            t0 = tic; [bbox, plateText] = detect_license_plate(I);
            if isempty(bbox)
                roi = detect_plate_roi(I);
                if ~isempty(roi)
                    PR = imcrop(I,roi);
                    EN = preprocess_image(PR);
                    [~, plateText] = detect_license_plate(EN);
                    if isempty(plateText), plateText = segment_characters(EN); end
                end
            else
                PR = imcrop(I,bbox);
                EN = preprocess_image(PR);
                if isempty(plateText)
                    [~, plateText] = detect_license_plate(EN);
                end
            end
            plateText = regexprep(upper(strtrim(plateText)),'\s+','');
            st = map_state_from_prefix(plateText);
            row = {string(imgs(i).name), string(plateText), string(st), toc(t0), ~isempty(plateText)};
            if isempty(tbl.Data)
                tbl.Data = cell2table(row,'VariableNames',tbl.ColumnName);
            else
                tbl.Data = [tbl.Data; cell2table(row,'VariableNames',tbl.ColumnName)];
            end
        end
        lblStatus.Text="Batch complete.";
    end

    function onExport(~,~)
        if isempty(tbl.Data), uialert(fig,'No data to export.','Error'); return; end
        [f,p] = uiputfile('results.csv','Save results as');
        if isequal(f,0), return; end
        writetable(tbl.Data, fullfile(p,f));
        lblStatus.Text="Results exported.";
    end
end

function s = basename(p)
[~,s,ext] = fileparts(p);
s=[s ext];
end


% ================================
% Image Preprocessing Function
% ================================
function enhancedImg = preprocess_image(img)
    % Convert to grayscale
    gray = rgb2gray(img);

    % Enhance contrast using adaptive histogram equalization
    enhancedImg = adapthisteq(gray, 'ClipLimit',0.02,'NumTiles',[8 8]);

    % Sharpen the image using a more aggressive kernel
    enhancedImg = imsharpen(enhancedImg, 'Radius', 2, 'Amount', 2);

    % Optional: Apply median filtering for noise reduction
    enhancedImg = medfilt2(enhancedImg, [3, 3]);
end

% ========================================
% EasyOCR License Plate Detection Function
% ========================================
function [bbox, plateText] = detect_license_plate(imgPathOrArray)
    try
        py.importlib.import_module('easyocr');
        reader = py.easyocr.Reader({'en'});

        if isnumeric(imgPathOrArray)
            if size(imgPathOrArray,3) == 1
                imgPathOrArray = repmat(imgPathOrArray, [1 1 3]);
            end
            np = py.importlib.import_module('numpy');
            img_np = np.array(uint8(imgPathOrArray));
            results = reader.readtext(img_np);
        else
            results = reader.readtext(char(imgPathOrArray));
        end

        if py.len(results) == 0
            bbox = [];
            plateText = '';
            return;
        end

        bestBox = [];
        bestText = '';
        bestScore = 0;

        for r = 0:py.len(results)-1
            res = results{r+1};
            coords_py = res{1};
            txt = char(res{2});
            conf = double(res{3}); % confidence score

            % Convert coordinates to rectangle
            coords = zeros(4,2);
            for i = 1:4
                coords(i,1) = double(py.float(coords_py{i}{1}));
                coords(i,2) = double(py.float(coords_py{i}{2}));
            end

            x_min = min(coords(:,1));
            y_min = min(coords(:,2));
            width = max(coords(:,1)) - x_min;
            height = max(coords(:,2)) - y_min;
            aspectRatio = width / height;

            % Plate-like filter
            if aspectRatio > 2 && aspectRatio < 6 && conf > bestScore
                bestBox = [x_min, y_min, width, height];
                bestText = txt;
                bestScore = conf;
            end
        end

        if isempty(bestBox)
            bbox = [];
            plateText = '';
        else
            bbox = bestBox;
            plateText = bestText;
        end

    catch exception
        disp('Error in detect_license_plate function:');
        disp(exception.message);
        bbox = [];
        plateText = '';
    end
end

% ========================================
% Backup Plate ROI Detection Method
% ========================================
function roi = detect_plate_roi(img)
    gray = rgb2gray(img);
    bw = imbinarize(gray);
    bw = bwareaopen(bw, 500); % remove small objects

    stats = regionprops(bw, 'BoundingBox');
    roi = [];

    for k = 1:length(stats)
        box = stats(k).BoundingBox;
        aspectRatio = box(3) / box(4); % width/height
        if aspectRatio > 2 && aspectRatio < 6 % looks like plate
            roi = box;
            break;
        end
    end
end
function state = map_state_from_prefix(plateText)
    % =========================
    % Define Prefixes (State / Vehicle Type)
    % =========================
    keys = { 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K', 'L', 'M', 'N', 'P', 'Q', 'R', 'S', 'T', 'V', 'W', 'Z', ...
             'JA', 'JB', 'JC', 'JD', 'JE', 'JF', 'JG', 'JH', 'JI', 'JS', ...
             'ZA', 'ZB', 'ZC', 'ZD', 'FA', 'FB', 'FC', 'FD', 'HA', 'HB', 'HC', 'HD', 'HE', 'HJ', 'HK', 'HL', 'HM', 'HN' };

    values = { 'Perak', 'Selangor', 'Pahang', 'Kelantan', 'Putrajaya', 'Perak', 'Selangor', 'Penang', 'Johor', 'Kedah', ...
               'Labuan', 'Melaka', 'Negeri Sembilan', 'Penang', 'Sarawak', 'Perlis', 'Sabah', 'Terengganu', 'Kuala Lumpur', ...
               'Putrajaya', 'Sarawak', 'Kedah', 'Negeri Sembilan', 'Pahang', 'Melaka', 'Labuan', 'Sarawak', 'Sabah', ...
               'Army Vehicle', 'Army Vehicle', 'Army Vehicle', 'KLIA Limousine Taxis', ...
               'Army Vehicles', 'Army Vehicles', 'Air Force Vehicles','Military', ...
               'Perak', 'Selangor', 'Pahang', 'Kelantan', 'Sabah', ...
               'Johor', 'Kedah', 'Negeri Sembilan', 'Labuan', 'Sabah', ...
               'Kuala Lumpur', 'Sabah', 'Terengganu' };

    % Ensure mapping is valid
    if numel(keys) ~= numel(values)
        error('The number of keys and values in stateMap do not match!');
    end
    stateMap = containers.Map(keys, values);

    % =========================
    % Default
    % =========================
    state = 'Unknown State';
    prefixFound = false;

    % =========================
    % Step 1: Check Diplomatic (suffix = DC)
    % =========================
    if length(plateText) >= 2 && strcmpi(plateText(end-1:end), 'DC')
        state = 'Diplomatic Corps';
        return; % Done, no need to check prefixes
    end

    % =========================
    % Step 2: Special case for H prefix (Taxi)
    % =========================
    if plateText(1) == 'H' || plateText(1) == 'h'
        state = 'TAXI';
        return;
    end

    % =========================
    % Step 3: Normal Prefix Matching
    % =========================
    if length(plateText) >= 4 && isKey(stateMap, plateText(1:4))
        state = stateMap(plateText(1:4));
        return;
    elseif length(plateText) >= 2 && isKey(stateMap, plateText(1:2))
        state = stateMap(plateText(1:2));
        return;
    elseif isKey(stateMap, plateText(1))
        state = stateMap(plateText(1));
        return;
    end
end




% ===============================
% Character Segmentation Function
% ===============================
function fullText = segment_characters(bw)
    % Step 1: Ensure the input is binary (if not, convert to binary)
    if ~islogical(bw)
        bw = imbinarize(bw); % Convert to binary if it's not already
    end
    
    % Step 2: Apply edge detection using the Canny method
    edges = edge(bw, 'Canny', 0.3); % Canny edge detection with adjusted threshold
    
    % Step 3: Label connected components
    [labeled, num] = bwlabel(edges);
    stats = regionprops(labeled, 'BoundingBox', 'Area', 'Eccentricity');

    % Step 4: Visualize the segmented characters
    figure; imshow(bw); title('Segmented Characters'); hold on;
    fullText = ""; % Initialize output string

    for k = 1:num
        if stats(k).Area > 30 && stats(k).Eccentricity < 0.9
            bb = stats(k).BoundingBox;
            rectangle('Position', bb, 'EdgeColor', 'r', 'LineWidth', 2);

            charImg = imcrop(bw, bb);
            charImg = imresize(charImg, [30, 30]);

            results = ocr(charImg, 'CharacterSet','ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789');
            txt = strtrim(results.Text);
            if ~isempty(txt)
                fullText = fullText + txt;
            end
        end
    end
    hold off;
end

