clc;
clear;
close all;

%% Simulation Setup
% Set the side length of the simulation area
squareLength = 400;

% Total number of antennas in all setups
nbrOfAntennas = 64;

% Set the AP location for the cellular Massive MIMO setup (center of the area)
APcellular = squareLength/2 + 1i*squareLength/2;

% Set the AP locations for the small-cell and cell-free setups (grid layout)
APperdim = sqrt(nbrOfAntennas);
APcellfree = linspace(squareLength/APperdim, squareLength, APperdim) - squareLength/APperdim/2;
APcellfree = repmat(APcellfree, [APperdim 1]) + 1i*repmat(APcellfree, [APperdim 1])';

% Number of realizations of the random UE locations
nbrOfSetups = 100000;

% Number of UEs in the simulation setup
K = 5;

% Generate the random UE locations for all setups
UElocations = (rand(nbrOfSetups, K) + 1i*rand(nbrOfSetups, K)) * squareLength;

% Define a function to compute the SNR as a function of the horizontal distance
% (the AP is 10 meter above the UE)
SNR = @(hor_dist) db2pow(10 + 96 - 30.5 - 36.7 * log10(sqrt(hor_dist.^2 + 10^2)));

% Prepare to store simulation results
SINR_cellular_mMIMO = zeros(nbrOfSetups, K);
SINR_cellular_small = zeros(nbrOfSetups, K);
SINR_cellfree = zeros(nbrOfSetups, K);

%% Main Simulation Loop
for n = 1:nbrOfSetups
    % Cellular Massive MIMO Setup: Generate channel matrix from AP (center) to UEs
    channelCellular = zeros(nbrOfAntennas, K);
    for k = 1:K
        distanceCellular = abs(APcellular - UElocations(n, k));
        channelCellular(:, k) = sqrt(SNR(distanceCellular)) * exp(1i * 2*pi*rand(nbrOfAntennas, 1));
    end
    % Compute the SINR using MMSE combining
    SINR_cellular_mMIMO(n, :) = computeSINRs_MMSE(channelCellular);
    
    % Cell-Free Setup: Generate channel matrix from grid of APs to UEs
    channelCellfree = zeros(nbrOfAntennas, K);
    for k = 1:K
        distanceCellfree = abs(APcellfree(:) - UElocations(n, k));
        channelCellfree(:, k) = sqrt(SNR(distanceCellfree)) .* exp(1i * 2*pi*rand(nbrOfAntennas, 1));
    end
    SINR_cellfree(n, :) = computeSINRs_MMSE(channelCellfree);
    
    % Small-Cell Setup: Each AP serves UEs individually.
    SINRs_smallcells = zeros(nbrOfAntennas, K);
    for m = 1:nbrOfAntennas
        SINRs_smallcells(m, :) = computeSINRs_MMSE(channelCellfree(m, :));
    end
    % Each UE connects to the AP providing the highest SINR.
    SINR_cellular_small(n, :) = max(SINRs_smallcells, [], 1);
end

%% Plot for Spatial Distribution of APs and UEs
% Visualize the AP positions (cell-free grid) and a sample UE realization.
figure;
% Choose one realization (the first) for visualization
sampleUEs = UElocations(1, :);
scatter(real(APcellfree(:)), imag(APcellfree(:)), 80, 'r', 'filled'); hold on;
scatter(real(sampleUEs), imag(sampleUEs), 100, 'b', 'filled');
xlabel('x [m]');
ylabel('y [m]');
legend({'AP positions (Cell-Free Grid)', 'UE positions (Sample)'}, 'Location', 'best');
title('Spatial Distribution of APs and UEs');
grid on;

%% CDF Plot of SINR
figure;
hold on; box on; grid on;
plot(pow2db(sort(real(SINR_cellfree(:)), 'ascend')), linspace(0, 1, nbrOfSetups*K), 'b--', 'LineWidth', 2);
plot(pow2db(sort(real(SINR_cellular_small(:)), 'ascend')), linspace(0, 1, nbrOfSetups*K), 'r-.', 'LineWidth', 2);
plot(pow2db(sort(real(SINR_cellular_mMIMO(:)), 'ascend')), linspace(0, 1, nbrOfSetups*K), 'k', 'LineWidth', 2);
xlabel('SINR [dB]', 'Interpreter', 'latex');
ylabel('CDF', 'Interpreter', 'latex');
legend({'Cell-free','Cellular: Small cells','Cellular: Massive MIMO'}, 'Location', 'SouthEast');
set(gca, 'fontsize', 16);
xlim([0 60]);

%% Function to compute SINRs with MMSE combining
function SINRs = computeSINRs_MMSE(channel)
    % Compute the SINR when using MMSE combining.
    % INPUT:
    %   channel: M x K channel matrix, where each column corresponds to a UE's channel.
    % OUTPUT:
    %   SINRs: K x 1 vector of SINRs for each UE.
    M = size(channel, 1); % Number of antennas
    K = size(channel, 2); % Number of UEs
    SINRs = zeros(K, 1);
    for k = 1:K
        desiredChannel = channel(:, k);
        % The MMSE expression yields a result that is theoretically real.
        % The real() wrapper removes any numerical imaginary parts.
        SINRs(k) = real(desiredChannel' * ((channel * channel' - desiredChannel * desiredChannel' + eye(M)) \ desiredChannel));
    end
end
