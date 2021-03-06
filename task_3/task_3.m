%% Initialisation
clear; close all;
% name indexes
surIndex = 26;
foreIndex = 25;
% convention
zPixel = 3;
bitInt = 8;
% maximum size of picture
widthMax = 160;
heightMax = 112;
bitsMax = widthMax * heightMax * zPixel * bitInt;
% number of signals
nSignals = 3;
% desired signal index
desiredIndex = 1;
% coefficients of the primitive polynomials
coeffs = [1 0 0 1 1; 1 1 0 0 1];
% phase shift of QPSK
phi = (surIndex + 2 * foreIndex) * pi / 180;
% directions of signals
directions = [30 0; 90 0; 150 0];
% number of paths per signal
nPaths = [1; 1; 1];
% path fading coefficients
fadingCoefs = [0.4; 0.7; 0.2];
% path delays
delays = [5; 7; 12];
% number of receiver antennas
nAnts = 5;
% initial phase of antenna positions
initPhase = 30 / 180 * pi;
% receiver antenna array positions normalised to half wavelengths
array = zeros(nAnts, 3);
for iAnt = 1: nAnts
    % array positions
    array(iAnt, :) = [cos(initPhase + (iAnt - 1) * 2 * pi / 5), sin(initPhase + (iAnt - 1) * 2 * pi / 5), 0];
end
% signal-to-noise ratio at the receiver end
snrDb = [0 40];
snr = 10 .^ (snrDb / 10);
nSnr = length(snrDb);
% minimum shift for gold sequences
shiftMin = ceil(1 + mod(surIndex + foreIndex, 12));
% maximum possible relative delay
nDelay = 2 ^ (length(coeffs) - 1) - 1;
% chip length
nChips = 2 ^ (length(coeffs) - 1) - 1;
% declaration
xPixel = zeros(nSignals, 1); yPixel = zeros(nSignals, 1); imageBits = zeros(nSignals, 1);
bitsIn = zeros(bitsMax, nSignals);
symbolsIn = zeros((2 ^ (length(coeffs) - 1) - 1) * bitsMax / 2, nSignals);
ber = zeros(nSnr, 1);
goldSeq = zeros(2 ^ (length(coeffs) - 1) - 1, nSignals);
disp(['Delays = ' num2str(delays')]);
disp(['DOAs = ' num2str(reshape(directions', 1, numel(directions)))]);
%% Balanced gold sequence mining
% generate M-sequences
[mSeq1] = fMSeqGen(coeffs(1, :));
[mSeq2] = fMSeqGen(coeffs(2, :));
% calculate the minimum shift for balanced gold sequence
[shift] = miner(mSeq1, mSeq2, shiftMin);
%% Transmitter, channel and receiver
for iSignal = 1: nSignals
    % generate gold sequences
    goldSeq(:, iSignal) = fGoldSeq(mSeq1, mSeq2, shift + iSignal - 1);
    % declare file names
    fileName = ['pic_', num2str(iSignal), '.png'];
    % obtain the bit stream into the modulator
    [bitsIn(:, iSignal), xPixel(iSignal), yPixel(iSignal)] = fImageSource(fileName, bitsMax);
    % calculate the image size in bits
    imageBits(iSignal) = xPixel(iSignal) * yPixel(iSignal) * zPixel * bitInt;
    % modulate the signal and encode with gold sequence
    symbolsIn(:, iSignal) = fDSQPSKModulator(bitsIn(:, iSignal), goldSeq(:, iSignal), phi);
end
% show the original picture
fImageSink(bitsIn, imageBits, xPixel, yPixel);
for iSnr = 1: nSnr
    % model the channel effects in the system
    [symbolsOut, desiredNoisePower] = fChannel(nPaths, symbolsIn, delays, fadingCoefs, directions, snr(iSnr), array, nDelay, desiredIndex);
    % estimate the delay and DOA of paths of signals
    [doaEst, delayEst] = fChannelEstimation(array, symbolsOut{desiredIndex}, goldSeq, nPaths, desiredNoisePower);
    % derive the weight of the superresolution beamformer
    [weightSr] = super_resolution(array, doaEst(desiredIndex, :), doaEst);
    % demodulate the received patterns
    [bitsOut] = fDSQPSKDemodulator(symbolsOut{desiredIndex}, weightSr, goldSeq, phi, delayEst, nPaths, fadingCoefs);
    % display the recovered pictures
    fImageSink(bitsOut, imageBits, xPixel, yPixel, snrDb(iSnr));
    % calculate bit error rate of the desired signal
    ber(iSnr) = sum(xor(bitsOut(:, desiredIndex), bitsIn(:, desiredIndex))) / length(bitsOut);
    disp(['----------   SNR = ' num2str(snrDb(iSnr)) ' dB ----------']);
    disp(['Estimated delays = ' num2str(delayEst')]);
    disp(['Estimated DOAs = ' num2str(reshape(doaEst', 1, numel(doaEst)))]);
    disp(['Bit error rate (Source ' num2str(desiredIndex) ') = ' num2str(ber(iSnr))]);
end
% rearrange the positions of the figures
tilefigs([0 0.5 0.8 0.5]);
