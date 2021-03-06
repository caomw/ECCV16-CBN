% Codes for ECCV-16 work `Deep Cascaded Bi-Network for Face Hallucination'
% Any question please contact Shizhan Zhu: zhshzhutah2@gmail.com
% Released on August 19, 2016

function genXPrototype(GPU_ID)
% By-product: calculated network feature map size
% Printed onto the screen

% Important variable:
% p: project name
% s: structure name of one perticular design (aka name of the folder)
% a: training data set
% b: test data set
% o: learning rate

% Solver characters:
% Oa: Standard training of full training set with base lr = 0.0001
% Na/Pa: 10 times larger/smaller base lr solver
% Ob: Training on small training set b. (Force error reduction)
% Nb/Pb: Similar
% Oc: Training exluding val set or other special training set.
% Nc/Pc: Similar

assert(logical(exist('GPU_ID','var')));
delete('./*.prototxt');
% 1. Basic info getting and model storing folder setting up
directory = pwd;
directory(directory=='\') = '/';
d_split = strsplit(directory,'/');
S = d_split{end};
D = d_split{end-1};
P = d_split{end-2};

% 2. Get traintest and deploy prototxt (network structure)
% Print layer map size info
fid = fopen('xset.txt','r');
fn_traintest = ['network-' P '-' D '-' S '.prototxt'];
fn_deploy = ['network-' P '-' D '-' S '-deploy.prototxt'];
fid_traintest = fopen(fn_traintest,'w');
fid_deploy = fopen(fn_deploy,'w');
test_blob_tot = str2double(fgetl(fid));
test_blob = cell(test_blob_tot, 1);
for i = 1:test_blob_tot, test_blob{i} = str2num(fgetl(fid)); end;
fprintf(fid_traintest, ['name: "' P '-' D '-' S  '"\n']);
fprintf(fid_deploy, ['name: "' P '-' D '-' S '"\n']);

line = fgetl(fid);
while (length(line) ~= 1 || line(1) ~= '.')
    writeLayer(fid_traintest,line,0,P,D,S,GPU_ID);
    writeLayer(fid_deploy,line,1,P,D,S,GPU_ID,test_blob);
    line = fgetl(fid);
end;

fclose(fid_traintest);
fclose(fid_deploy);

% 3. Gen solver prototxt
series = GF(fid);
lrO = GF(fid);
test_iter = GF(fid);
test_interval = GF(fid);
momentum = GF(fid);
weight_decay = GF(fid);
display = GF(fid);
max_iter = GF(fid);
snapshot = GF(fid);
iter_size = GF(fid);
for ch = series
    fid_solver = fopen(['solver-' P '-' D '-' S '-' ch '.prototxt'],'w');
    PI(fid_solver, ['net: "examples/' P '/' D '/' S '/network-' P '-' D '-' S '.prototxt"']);
    PI(fid_solver, ['test_iter: ' num2str(test_iter)]);
    PI(fid_solver, ['test_interval: ' num2str(test_interval)]);
    PI(fid_solver, ['base_lr: ' num2str((10 ^ ('O' - ch)) * lrO)]);
    PI(fid_solver, ['momentum: ' num2str(momentum)]);
    PI(fid_solver, ['weight_decay: ' num2str(weight_decay)]);
    PI(fid_solver, ['lr_policy: "fixed"']); %#ok<NBRAK>
    PI(fid_solver, ['display: ' num2str(display)]);
    PI(fid_solver, ['max_iter: ' num2str(max_iter)]);
    PI(fid_solver, ['snapshot: ' num2str(snapshot)]);
    PI(fid_solver, ['snapshot_prefix: "examples/' P '/Model/m-' P '-' D '-' S '/' P '-' D '-' S '"']);
    PI(fid_solver, ['iter_size: 1']);
    fprintf(fid_solver, 'device_id : [%d', GPU_ID(1));
    for j = 2:length(GPU_ID), fprintf(fid_solver, ',%d', GPU_ID(j));end;
    fprintf(fid_solver, ']\n');
    fclose(fid_solver);
end;

% 4. Generate sample shell
fid_sh = fopen(['new_xtrain.sh'],'w');
PI(fid_sh, '#!/usr/bin/env sh');
PI(fid_sh, '');
PI(fid_sh, ['GOOGLE_LOG_DIR=examples/' P '/' D '/' S '/log \']);
PI(fid_sh, ['mpirun -np ' num2str(length(GPU_ID)) ' \'], 4);
fprintf(fid_sh, ['    ./build/install/bin/caffe train --solver=examples/' P '/' D '/' S '/solver-' P '-' D '-' S '-' series(1) '.prototxt']);
%PI(fid_sh, ['#-snapshot=examples/' P '/Model/m-' P '-' D '-' S '/' P '-' D '-' S '_iter_110000.solverstate'], 4);

% resuming or finetuning
st = fgetl(fid);
while (st(1) == '#'), st = fgetl(fid); end;
id = find(st=='#',1,'first'); if ~isempty(id), st = st(1:id-1);end;
st = strsplit(st, ' ');
rf_flag = st{1};
disp({P,D,S});
disp(st);
if ~(length(rf_flag) == 1 || rf_flag(1) == '.' || strcmp(rf_flag, 'NONE'))
    switch rf_flag
        case 'RESUME'
            assert(length(st) == 2);
            resume_iter = str2double(st{2});
            assert(~isnan(resume_iter));
            fprintf(fid_sh, [' \\\n    -snapshot=examples/' P '/Model/m-' P '-' D '-' S '/' P '-' D '-' S '_iter_' num2str(resume_iter) '.solverstate']);
        case 'FINETUNE'
            finetune_tot = GF(fid);
            finetune = cell(finetune_tot, 4);
            for i = 1:finetune_tot
                st = fgetl(fid);
                id = find(st == '#', 1, 'first');
                if ~isempty(id), st = st(1:id-1); end;
                st = strsplit(st, ' ');
                assert(length(st) == 4); assert(~isnan(str2double(st{4})));
                for j = 1:4, finetune{i,j} = st{j}; end;
            end;
            disp(finetune);
            fprintf(fid_sh, [' \\\n    -weights=']);
            for i = 1:finetune_tot
                if i > 1, fprintf(fid_sh, ','); end;
                fprintf(fid_sh, ['examples/' finetune{i,1} '/Model/m-' finetune{i,1} '-' finetune{i,2} '-' finetune{i,3} '/' finetune{i,1} '-' finetune{i,2} '-' finetune{i,3} '_iter_' finetune{i,4} '.caffemodel']);
            end;
        otherwise
            error('The rf_flag can only be one of: 1) NONE; 2) RESUME; 3) FINETUNE');
    end;
end;
fclose(fid_sh);

fclose(fid);
warning off all;
mkdir('log');
mkdir('../../Model/',['m-' P '-' D '-' S]);
warning on all;

end


% ========================= Layer Writing =========================== %
function writeLayer(fid, line, flag, P, D, S, GPU_ID, test_blob)
% fid refers to fid_traintest or fid_deploy globally.
% layer_name CONVOLUTION | bottom top xxx
% flag == 0: writes on traintest, flag == 1: writes on deploy

if line(1) == '#', return; end;
e = strsplit(line);
tot = length(e);
while isempty(e{tot}), tot = tot - 1; end;
e = e(1:tot);
if strcmp(e{1},'`') && flag == 1, return; end;
if strcmp(e{1},'`') && flag == 0, e = e(2:end); end;
switch e{2}
    case 'HDF5DATA'
        % name TYPE | PHASE setName batchSize inputTot top1 top2 ...
        if flag == 0 % only effective for traintest prototxt
            PI(fid, 'layer {');
            PI(fid, ['name: "' e{1} '"'],2);
            PI(fid, ['type: "HDF5Data"'],2);
            for i = 7:tot, PI(fid, ['top: "' e{i} '"'],2);end;
            PI(fid, ['include: { phase: ' e{3} ' }'],2);
            PI(fid, 'hdf5_data_param {',2);
            PI(fid, ['source: "examples/' P '/Data/d-' D '/' P '-' D '-' e{4} '.txt"'],4);
            bs = 2^(ceil(log2(str2double(e{5}) / length(GPU_ID)))); % Cauculate the batchsize
            if bs < 1, bs = 1; end;
            PI(fid, ['batch_size: ' num2str(bs)],4);
            PI(fid, '}', 2);
            PI(fid, '}');
        elseif flag == 1 && strcmp(e{3},'TEST') % only effective for deploy prototxt
            inputTot = str2double(e{6});
            assert(inputTot == length(test_blob));
            for i = 7:6+inputTot
                PI(fid, ['input: "' e{i} '"']);
                PI(fid, ['input_dim: ' num2str(test_blob{i-6}(1))]);
                PI(fid, ['input_dim: ' num2str(test_blob{i-6}(2))]);
                PI(fid, ['input_dim: ' num2str(test_blob{i-6}(3))]);
                PI(fid, ['input_dim: ' num2str(test_blob{i-6}(4))]);
            end;
            PI(fid, 'force_backward: true');
        end;
    case 'CONVRELUS'
        % name TYPE | bot top kernel_size stride pad output w_lr b_lr num_of_conv
        assert(length(e) == 11);
        assert(str2double(e{11}) <= 1e6);
        for i = 1:str2double(e{11})
            layer_append = sprintf('_%06d', i);
            layer_append_prev = sprintf('_%06d', i-1);
            PI(fid, 'layer {');
            PI(fid, ['name: "' e{1} '_conv' layer_append '"'], 2);
            PI(fid, 'type: "Convolution"', 2);
            if i == 1
                PI(fid, ['bottom: "' e{3} '"'], 2);
            else
                PI(fid, ['bottom: "' e{1} '_conv' layer_append_prev '"'], 2);
            end;
            if i == str2double(e{11})
                PI(fid, ['top: "' e{4} '"'], 2);
            else
                PI(fid, ['top: "' e{1} '_conv' layer_append '"'], 2);
            end;
            PI(fid, 'param {',2);
            PI(fid, ['lr_mult: ' num2str(e{9})], 4);
            PI(fid, 'decay_mult: 1', 4);
            PI(fid, '}', 2);
            PI(fid, 'param {',2);
            PI(fid, ['lr_mult: ' num2str(e{10})], 4);
            PI(fid, 'decay_mult: 0', 4);
            PI(fid, '}', 2);
            PI(fid, 'convolution_param {', 2);
            PI(fid, ['num_output: ' num2str(e{8})], 4);
            PI(fid, ['pad: ' num2str(e{7})], 4);
            PI(fid, ['kernel_size: ' num2str(e{5})], 4);
            PI(fid, ['stride: ' num2str(e{6})], 4);
            PI(fid, 'weight_filler {', 4);
            PI(fid, 'type: "xavier"', 6);
            PI(fid, '}', 4);
            PI(fid, 'bias_filler {', 4);
            PI(fid, 'type: "constant"', 6);
            PI(fid, 'value: 0', 6);
            PI(fid, '}', 4);
            PI(fid, '}', 2);
            PI(fid, '}');
            if i == str2double(e{11}), break; end;
            PI(fid, 'layer {');
            PI(fid, ['name: "' e{1} '_relu' layer_append '"'], 2);
            PI(fid, ['type: "ReLU"'], 2);
            PI(fid, ['bottom: "' e{1} '_conv' layer_append '"'], 2);
            PI(fid, ['top: "' e{1} '_conv' layer_append '"'], 2);
            PI(fid, '}');
        end;
    case 'CONVOLUTION'
        % name TYPE | bot top kernel_size stride pad output w_lr b_lr
        assert(length(e) == 10);
        PI(fid, 'layer {');
        PI(fid, ['name: "' e{1} '"'], 2);
        PI(fid, 'type: "Convolution"', 2);
        PI(fid, ['bottom: "' e{3} '"'], 2);
        PI(fid, ['top: "' e{4} '"'], 2);
        PI(fid, 'param {',2);
        PI(fid, ['lr_mult: ' num2str(e{9})], 4);
        PI(fid, 'decay_mult: 1', 4);
        PI(fid, '}', 2);
        PI(fid, 'param {',2);
        PI(fid, ['lr_mult: ' num2str(e{10})], 4);
        PI(fid, 'decay_mult: 0', 4);
        PI(fid, '}', 2);
        PI(fid, 'convolution_param {', 2);
        PI(fid, ['num_output: ' num2str(e{8})], 4);
        PI(fid, ['pad: ' num2str(e{7})], 4);
        PI(fid, ['kernel_size: ' num2str(e{5})], 4);
        PI(fid, ['stride: ' num2str(e{6})], 4);
        PI(fid, 'weight_filler {', 4);
        PI(fid, 'type: "xavier"', 6);
        PI(fid, '}', 4);
        PI(fid, 'bias_filler {', 4);
        PI(fid, 'type: "constant"', 6);
        PI(fid, 'value: 0', 6);
        PI(fid, '}', 4);
        PI(fid, '}', 2);
        PI(fid, '}');
    case 'POOLING'
        % name TYPE | bot top POOLING_METHOD kernel_size stride
        % No learning params
        assert(length(e) == 7);
        PI(fid, 'layer {');
        PI(fid, ['name: "' e{1} '"'], 2);
        PI(fid, 'type: "Pooling"', 2);
        PI(fid, ['bottom: "' e{3} '"'], 2);
        PI(fid, ['top: "' e{4} '"'], 2);
        PI(fid, 'pooling_param {', 2);
        PI(fid, ['pool: ' e{5}], 4);
        PI(fid, ['kernel_size: ' num2str(e{6})], 4);
        PI(fid, ['stride: ' num2str(e{7})], 4);
        PI(fid, '}', 2);
        PI(fid, '}');
    case 'INNER_PRODUCT'
        % name TYPE | bot top output w_lr b_lr
        assert(length(e) == 7);
        PI(fid, 'layer {');
        PI(fid, ['name: "' e{1} '"'], 2);
        PI(fid, 'type: "InnerProduct"', 2);
        PI(fid, ['bottom: "' e{3} '"'], 2);
        PI(fid, ['top: "' e{4} '"'], 2);
        PI(fid, 'param {', 2);
        PI(fid, ['lr_mult: ' num2str(e{6})], 4);
        PI(fid, 'decay_mult: 1', 4);
        PI(fid, '}', 2);
        PI(fid, 'param {', 2);
        PI(fid, ['lr_mult: ' num2str(e{7})], 4);
        PI(fid, 'decay_mult: 0', 4);
        PI(fid, '}', 2);
        PI(fid, 'inner_product_param {', 2);
        PI(fid, ['num_output: ' num2str(e{5})], 4);
        PI(fid, 'weight_filler {', 4);
        PI(fid, 'type: "xavier"', 6);
        PI(fid, '}', 4);
        PI(fid, '}', 2);
        PI(fid, '}');
    case 'BN' % ONLY VALID FOR XIONGSHEN AND TONGSHEN'S CAFFE
        % name TYPE | bot top lr_w lr_b
        assert(length(e) == 6);
        PI(fid, 'layer {');
        PI(fid, ['name: "' e{1} '"'], 2);
        PI(fid, ['type: "BN"'], 2);
        PI(fid, ['bottom: "' e{3} '"'], 2);
        PI(fid, ['top: "' e{4} '"'], 2);
        for j = 1:2
            PI(fid, 'param {', 2);
            PI(fid, ['lr_mult: ' e{4+j}], 4);
            PI(fid, 'decay_mult: 0', 4);
            PI(fid, '}', 2);
        end;
        PI(fid, 'bn_param {', 2);
        PI(fid, 'slope_filler {', 4);
        PI(fid, 'type: "constant"', 6);
        PI(fid, 'value: 1', 6);
        PI(fid, '}', 4);
        PI(fid, 'bias_filler {', 4);
        PI(fid, 'type: "constant"', 6);
        PI(fid, 'value: 0', 6);
        PI(fid, '}', 4);
        PI(fid, '}', 2);
        PI(fid, '}');
    case 'CONCAT'
        % name TYPE | bot1 bot2 ... top 0/1
        assert(length(e) >= 6);
        PI(fid, 'layer {');
        PI(fid, ['name: "' e{1} '"'], 2);
        PI(fid, ['type: "Concat"'], 2);
        for i = 3:length(e)-2
            PI(fid, ['bottom: "' e{i} '"'], 2);
        end;
        PI(fid, ['top: "' e{end-1} '"'], 2);
        PI(fid, ['concat_param {'], 2);
        assert(~isnan(str2double(e{end})));
        PI(fid, ['axis: ' e{end}], 4);
        PI(fid, '}', 2);
        PI(fid, '}');
    case 'ELTWISE'
        % name TYPE | bot1 bot2 top SUM/PROD/MAX
        assert(length(e) == 6);
        PI(fid, 'layer {');
        PI(fid, ['name: "' e{1} '"'], 2);
        PI(fid, ['type: "Eltwise"'], 2);
        PI(fid, ['bottom: "' e{3} '"'], 2);
        PI(fid, ['bottom: "' e{4} '"'], 2);
        PI(fid, ['top: "' e{5} '"'], 2);
        PI(fid, ['eltwise_param {'], 2);
        PI(fid, ['operation: ' e{6}], 4);
        PI(fid, '}', 2);
        PI(fid, '}');
    case 'TILE'
        % name TYPE | bot top axis tiles
        assert(length(e) == 6);
        PI(fid, 'layer {');
        PI(fid, ['name: "' e{1} '"'], 2);
        PI(fid, ['type: "Tile"'], 2);
        PI(fid, ['bottom: "' e{3} '"'], 2);
        PI(fid, ['top: "' e{4} '"'], 2);
        PI(fid, ['tile_param {'], 2);
        for i = 5:6, assert(~isnan(str2double(e{i}))); end;
        PI(fid, ['axis: ' e{5}], 4);
        PI(fid, ['tiles: ' e{6}], 4);
        PI(fid, '}', 2);
        PI(fid, '}');
    case 'POWER'
        % name TYPE | bot top power scaling shift
        assert(length(e) == 7);
        PI(fid, 'layer {');
        PI(fid, ['name: "' e{1} '"'], 2);
        PI(fid, ['type: "Power"'], 2);
        PI(fid, ['bottom: "' e{3} '"'], 2);
        PI(fid, ['top: "' e{4} '"'], 2);
        PI(fid, ['power_param {'], 2);
        for i = 5:7, assert(~isnan(str2double(e{i}))); end;
        PI(fid, ['power: ' e{5}], 4);
        PI(fid, ['scale: ' e{6}], 4);
        PI(fid, ['shift: ' e{7}], 4);
        PI(fid, '}', 2);
        PI(fid, '}');
    case 'RELU'
        % name TYPE | bot top
        assert(length(e) == 4);
        PI(fid, 'layer {');
        PI(fid, ['name: "' e{1} '"'], 2);
        PI(fid, ['type: "ReLU"'], 2);
        PI(fid, ['bottom: "' e{3} '"'], 2);
        PI(fid, ['top: "' e{4} '"'], 2);
        PI(fid, '}');
    case 'TANH'
        % name TYPE | bot top
        assert(length(e) == 4);
        PI(fid, 'layer {');
        PI(fid, ['name: "' e{1} '"'], 2);
        PI(fid, ['type: "TanH"'], 2);
        PI(fid, ['bottom: "' e{3} '"'], 2);
        PI(fid, ['top: "' e{4} '"'], 2);
        PI(fid, '}');
    case 'DROPOUT'
        assert(length(e) == 5);
        PI(fid, 'layer {');
        PI(fid, ['name: "' e{1} '"'], 2);
        PI(fid, 'type: "Dropout"', 2);
        PI(fid, ['bottom: "' e{3} '"'], 2);
        PI(fid, ['top: "' e{4} '"'], 2);
        PI(fid, 'dropout_param {', 2);
        PI(fid, ['dropout_ratio: ' num2str(e{5})], 4);
        PI(fid, '}', 2);
        PI(fid, '}');
    case 'EUCLIDEAN_LOSS'
        % name TYPE | bot1 bot2 top loss_weight
%        if flag == 0 % only when writing on training prototxt can do this
            assert(length(e) == 6);
            PI(fid, 'layer {');
            PI(fid, ['name: "' e{1} '"'], 2);
            PI(fid, 'type: "EuclideanLoss"', 2);
            for i = 3:4, PI(fid, ['bottom: "' e{i} '"'], 2);end;
            PI(fid, ['top: "' e{5} '"'], 2);
            PI(fid, ['loss_weight: ' num2str(e{6})], 2);
            PI(fid, '}');
%        end;
    case 'SMOOTHL1_LOSS' % PROVIDED BY JINWEI
        % name TYPE | bot1 bot2 top loss_weight threshold margin
%        if flag == 0 % only when writing on training prototxt can do this
            assert(legnth(e) == 8);
            PI(fid, 'layer {');
            PI(fid, ['name: "' e{1} '"'], 2);
            PI(fid, 'type: "SmoothL1Loss"', 2);
            for i = 3:4, PI(fid, ['bottom: "' e{i} '"'], 2);end;
            PI(fid, ['top: "' e{5} '"'], 2);
            PI(fid, ['loss_weight: ' num2str(e{6})], 2);
            PI(fid, 'smooth_l1_loss_param {', 2);
            PI(fid, ['threshold: ' num2str(e{7})], 4);
            PI(fid, ['margin: ' num2str(e{8})], 4);
            PI(fid, '}', 2);
            PI(fid, '}');
%        end;
    otherwise
        error('Haven'' t implementation such type of layer!');
end;

end
% =================================================================== %

% ============================== Utility ============================ %
% Print Indentation and return
function PI(fid, str, indent)

if nargin >= 3
    for i = 1:indent, fprintf(fid, ' '); end;
end;
fprintf(fid, '%s\n', str);

end

% Get first element from the line of reading file
function ele = GF(fid)

str = fgetl(fid);
e = strsplit(str, ' ');
if ~isnan(str2double(e{1}))
    ele = str2double(e{1});
else
    ele = e{1};
end;

end
% =================================================================== %
