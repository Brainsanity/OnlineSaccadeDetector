% test online saccade detection algorithm
load('20210605_04.mat');

sRate = double(size(eis_data.eye_data.eye_1.calibrated_x,2) / diff(eis_data.eye_data.timing.elapsed([1 end])));		% 1016.185 Hz
rfRate = 200;	% monitor refresh rate (Hz)
targetSpeed = 4*60;	% arcmin
devThreshold = 5;	% arcmin
velThreshold = 180;	% arcmin/s
minInterval = 15;	% ms
minDur = 15;	% ms

refWin = 30;	% reference window for saccade detection (ms)
refInterval = 3;	% interval between the reference window and the sample in observation
N = round(refWin / 1000 * sRate);
D = round(refInterval / 1000 * sRate);

minInterval = round(minInterval / (1000/rfRate));	% in monitor frames
minDur = round(minDur / (1000/rfRate));	% in monitor frames

global pixPerArcmin sensitivityPix_2 B_IIR A_IIR bufRawX bufRawY bufFilteredX bufFilteredY xArcmin yArcmin xPix yPix dxPix dyPix dxArcmin dyArcmin


eyeFiltered.x = zeros(size(eis_data.eye_data.eye_1.calibrated_x));
eyeFiltered.y = zeros(size(eis_data.eye_data.eye_1.calibrated_y));
filteredSpeed = zeros(size(eis_data.eye_data.timing.spd));
rawSpeed = filteredSpeed;
deviates = rawSpeed;
deviates2std = deviates;

evnts = [eis_data.user_data.events.data{:}];
tFpOn = ([evnts.tFpOn] - eis_data.user_data.streams.frametime.data(1))/1000 + eis_data.eye_data.timing.elapsed(eis_data.eye_data.timing.spd(1));
tTargetOn = ([evnts.tTargetOn] - eis_data.user_data.streams.frametime.data(1))/1000 + eis_data.eye_data.timing.elapsed(eis_data.eye_data.timing.spd(1));
tRampOn = ([evnts.tRampOn] - eis_data.user_data.streams.frametime.data(1))/1000 + eis_data.eye_data.timing.elapsed(eis_data.eye_data.timing.spd(1));
tPlateauOn = ([evnts.tPlateauOn] - eis_data.user_data.streams.frametime.data(1))/1000 + eis_data.eye_data.timing.elapsed(eis_data.eye_data.timing.spd(1));
tMaskOn = ([evnts.tMaskOn] - eis_data.user_data.streams.frametime.data(1))/1000 + eis_data.eye_data.timing.elapsed(eis_data.eye_data.timing.spd(1));
for(k = size(evnts,2) : -1 : 1)
	[~, idxFpOn(k)] = min(abs(eis_data.eye_data.timing.elapsed - tFpOn(k)));
	[~, idxTargetOn(k)] = min(abs(eis_data.eye_data.timing.elapsed - tTargetOn(k)));
	[~, idxRampOn(k)] = min(abs(eis_data.eye_data.timing.elapsed - tRampOn(k)));
	[~, idxPlateuOn(k)] = min(abs(eis_data.eye_data.timing.elapsed - tPlateauOn(k)));
	[~, idxMaskOn(k)] = min(abs(eis_data.eye_data.timing.elapsed - tMaskOn(k)));
end


iSample = 1;
isSacOn = false;
iSacOn = -Inf;
iSacOff = -Inf;
curInverval = 0;
curDur = 0;
sacOnFlag = false(size(eis_data.eye_data.timing.spd));
onlineSacs = struct('latency', {}, 'duration', {}, 'iSacOn', {}, 'iSacOff', {});

for(iFrame = 1 : size(eis_data.eye_data.timing.spd, 2))
	eyeNew.x = eis_data.eye_data.eye_1.calibrated_x(iSample : iSample - 1 + eis_data.eye_data.timing.spd(iFrame));
	eyeNew.y = eis_data.eye_data.eye_1.calibrated_y(iSample : iSample - 1 + eis_data.eye_data.timing.spd(iFrame));
	eyeNew.blinking = eis_data.eye_data.eye_1.blinking(iSample : iSample - 1 + eis_data.eye_data.timing.spd(iFrame));
	eyeNew.tracking = eis_data.eye_data.eye_1.tracking(iSample : iSample - 1 + eis_data.eye_data.timing.spd(iFrame));

	% filter the eye trace
	if(iFrame == 1)
		Initialize(eyeNew);
	end
	eyeNewFiltered = Update(eyeNew);
	eyeFiltered.x(iSample : iSample - 1 + eis_data.eye_data.timing.spd(iFrame)) = eyeNewFiltered.xArcmin;
	eyeFiltered.y(iSample : iSample - 1 + eis_data.eye_data.timing.spd(iFrame)) = eyeNewFiltered.yArcmin;

	% filtered eye speed at end of each frame
	% dur = size(eyeNew.x,2) / sRate;
	% filteredSpeed(iFrame) = sqrt((dxArcmin/dur)^2 + (dyArcmin/dur)^2);	% filtered eye speed

	% use original eye trace
	% dxArcmin = eyeNew.x(end) - eis_data.eye_data.eye_1.calibrated_x(max(1,iSample-1));
	% dyArcmin = eyeNew.y(end) - eis_data.eye_data.eye_1.calibrated_y(max(1,iSample-1));
	% rawSpeed(iFrame) = sqrt((dxArcmin/dur)^2 + (dyArcmin/dur)^2);	% eye speed

	% detect saccade
	% if(any(idxRampOn <= iSample & iSample <= idxPlateuOn))	% during ramp
		% iTrial = find(idxRampOn <= iSample & iSample <= idxPlateuOn);
		% dur = size(eyeNew.x,2) / sRate;
		% speed = sqrt((dxArcmin/dur - evnts(iTrial).targetSpeed*60)^2 + (dyArcmin/dur)^2);	% eye speed relative to the target
		% filteredSpeed(iFrame) = speed;
		% rawSpeed(iFrame) = speed;

	if(any(idxFpOn <= iSample & iSample <= idxMaskOn))		% during trial
		
		% approximate linear fitting
		preSamples.x = eis_data.eye_data.eye_1.calibrated_x( iSample - 1 + double(eis_data.eye_data.timing.spd(iFrame)) - D + (-N+1:0) );
		preSamples.y = eis_data.eye_data.eye_1.calibrated_y( iSample - 1 + double(eis_data.eye_data.timing.spd(iFrame)) - D + (-N+1:0) );
		mSpeed.x = diff(preSamples.x([1 end])) / (N-1);
		mSpeed.y = diff(preSamples.y([1 end])) / (N-1);
		preSamples.x = preSamples.x - (0:N-1)*mSpeed.x;
		preSamples.y = preSamples.y - (0:N-1)*mSpeed.y;
		curSample.x = eyeNew.x(end) - (N-1+D)*mSpeed.x;
		curSample.y = eyeNew.y(end) - (N-1+D)*mSpeed.y;
		deviates(iFrame) = norm([curSample.x - mean(preSamples.x), curSample.y - mean(preSamples.y)]);
		deviates2std(iFrame) = deviates(iFrame) / sqrt(var(preSamples.x) + var(preSamples.y));

		% linear fitting
		% preSamples.x = eis_data.eye_data.eye_1.calibrated_x( iSample - 1 + double(eis_data.eye_data.timing.spd(iFrame)) - D + (-N+1:0) );
		% preSamples.y = eis_data.eye_data.eye_1.calibrated_y( iSample - 1 + double(eis_data.eye_data.timing.spd(iFrame)) - D + (-N+1:0) );
		% p.x = polyfit(1:N, preSamples.x, 1);
		% p.y = polyfit(1:N, preSamples.y, 1);
		% curSample.x = eyeNew.x(end);
		% curSample.y = eyeNew.y(end);
		% deviates(iFrame) = norm([curSample.x - polyval(p.x, N+D), curSample.y - polyval(p.y, N+D)]);
		% deviates2std(iFrame) = deviates(iFrame) / sqrt(var(preSamples.x - polyval(p.x, 1:N)) + var(preSamples.y - polyval(p.y, 1:N)));


		if(~isSacOn && iSample > 15 && deviates(iFrame) > devThreshold)
			isSacOn = true;
    		iSacOn = iSample - 1 + eis_data.eye_data.timing.spd(iFrame);
            curDur = 0;
            curInverval = 0;
		end
		if(isSacOn)
			curDur = curDur + 1;
			if(deviates(iFrame) < devThreshold)
		        curInverval = curInverval + 1;
				if(curInverval > minInterval & curDur > minDur)
					isSacOn = false;
		    		iSacOff = iSample - 1 + eis_data.eye_data.timing.spd(iFrame);
		    		onlineSacs(end+1).iSacOn = iSacOn;
		    		onlineSacs(end).iSacOff = iSacOff;
		    		onlineSacs(end).latency = eis_data.eye_data.timing.elapsed(iSacOn);
		    		onlineSacs(end).duration = diff(eis_data.eye_data.timing.elapsed([iSacOn, iSacOff]));
		        end
	        else
	        	curInverval = 0;
	        end
		end
		if(isSacOn)		% is saccade
			sacOnFlag(iFrame) = true;
		end
	end


	iSample = iSample + double(eis_data.eye_data.timing.spd(iFrame));
end

figure; hold on;
plot(eis_data.eye_data.eye_1.calibrated_x, 'b', 'displayname', 'x');
plot(eyeFiltered.x, 'c', 'displayname', 'filtered x');
plot(eis_data.eye_data.eye_1.calibrated_y, 'r', 'displayname', 'y');
plot(eyeFiltered.y, 'm', 'displayname', 'filtered y');
legend;

idx = cumsum(eis_data.eye_data.timing.spd);
t = eis_data.eye_data.timing.elapsed(idx);
x = eyeFiltered.x(idx);
y = eyeFiltered.y(idx);
filteredVel = sqrt((diff(x) ./ double(eis_data.eye_data.timing.spd(2:end))*1016 - 240).^2 + (diff(y) ./ double(eis_data.eye_data.timing.spd(2:end))*1016).^2);
x = eis_data.eye_data.eye_1.calibrated_x(idx);
y = eis_data.eye_data.eye_1.calibrated_y(idx);
vel = sqrt((diff(x) ./ double(eis_data.eye_data.timing.spd(2:end))*1016 - 240).^2 + (diff(y) ./ double(eis_data.eye_data.timing.spd(2:end))*1016).^2);
plot([1; 1; nan] * idxFpOn, [ylim'; nan] * ones(size(idxFpOn)), 'g', 'linewidth', 2);
plot([1; 1; nan] * idxMaskOn, [ylim'; nan] * ones(size(idxMaskOn)), 'r', 'linewidth', 2);
% plot(idx(2:end), vel, 'g', 'displayname', 'filtered velocity');
% plot(idx, rawSpeed, 'k', 'displayname', 'raw velocity');
% plot(idx(2:end), filteredVel, 'g', 'displayname', 'filtered velocity');
% plot(idx, filteredSpeed, 'k', 'displayname', 'filtered velocity');
plot(idx, deviates*100, 'k', 'displayname', 'deviates*100');
% plot(idx, deviates2std, 'r', 'displayname', 'deviates2std*100');
plot(xlim, [1 1]*velThreshold, 'k--', 'displayname', 'sac threshold');
plot(xlim, [1 1]*devThreshold, 'k--', 'displayname', 'dev threshold');
plot(idx(sacOnFlag), x(sacOnFlag), 'k.', 'markersize', 10, 'displayname', 'detected sac');



%% compare with offline detection
onlineSacs_ = onlineSacs;
flag = false(size(onlineSacs));
for(k = 1 : size(tTargetOn,2))
	flag(tTargetOn(k) <= [onlineSacs.latency] & [onlineSacs.latency] + [onlineSacs.duration] <= tMaskOn(k)) = true;
end
onlineSacs = onlineSacs(flag);

offlineSacs = SaccadeTool.GetSacs([eis_data.eye_data.eye_1.calibrated_x; eis_data.eye_data.eye_1.calibrated_y], sRate, false);
offlineSacs = [offlineSacs.saccades, offlineSacs.microsaccades];
flag = false(size(offlineSacs));
for(k = 1 : size(tTargetOn,2))
	flag(idxTargetOn(k) <= [offlineSacs.start] & [offlineSacs.start] + [offlineSacs.duration] - 1 <= idxMaskOn(k)) = true;
end
offlineSacs = offlineSacs(flag);

tEnd = 155.96;
[~, iEnd] = min(abs(eis_data.eye_data.timing.elapsed - tEnd));
offlineSacs([offlineSacs.start] > iEnd) = [];
onlineSacs([onlineSacs.latency] > tEnd) = [];

onHitFlag = zeros(size(onlineSacs));
offHitFlag = zeros(size(offlineSacs));
idx2Offline = nan(size(onlineSacs));
for(iOn = 1 : size(onlineSacs,2))
	for(iOff = 1 : size(offlineSacs,2))
		if(~(onlineSacs(iOn).iSacOn > offlineSacs(iOff).start + offlineSacs(iOff).duration - 1 || onlineSacs(iOn).iSacOff < offlineSacs(iOff).start))
			onHitFlag(iOn) = onHitFlag(iOn) + 1;
			offHitFlag(iOff) = offHitFlag(iOff) + 1;
			idx2Offline(iOn) = iOff;
            break;
        end
	end
end
nHits = sum(offHitFlag > 0);
nMiss = sum(~offHitFlag);
nFAs = sum(~onHitFlag);
hitRate = nHits / (nHits + nMiss);
faRate = nFAs / (size(onHitFlag,2));
fprintf('hit rate:         %3d/%3d = %.3f\n', nHits, nHits+nMiss, hitRate);
fprintf('false alarm rate: %3d/%3d = %.3f\n', nFAs, size(onHitFlag,2), faRate);

onsetDiff = [onlineSacs(~isnan(idx2Offline)).latency] - eis_data.eye_data.timing.elapsed(1) - [offlineSacs(idx2Offline(~isnan(idx2Offline))).start] / sRate;
offsetDiff = onsetDiff + [onlineSacs(~isnan(idx2Offline)).duration] - [offlineSacs(idx2Offline(~isnan(idx2Offline))).duration] / sRate;
onsetDiff = onsetDiff * 1000;
offsetDiff = offsetDiff * 1000;
fprintf('onset difference:  %.1f +- %.2f ms\n', mean(onsetDiff), std(onsetDiff));
fprintf('offset difference: %.1f +- %.2f ms\n', mean(offsetDiff), std(offsetDiff));

figure; hold on;
plot([eis_data.eye_data.eye_1.calibrated_x(eis_data.eye_data.timing.elapsed < tEnd); eis_data.eye_data.eye_1.calibrated_y(eis_data.eye_data.timing.elapsed < tEnd)]');
plot(eyeFiltered.x, 'c', 'displayname', 'filtered x');
plot(eyeFiltered.y, 'm', 'displayname', 'filtered y');
for(sac = offlineSacs)
	kk = sac.start : sac.start + sac.duration - 1;
	plot(kk, [eis_data.eye_data.eye_1.calibrated_x(kk); eis_data.eye_data.eye_1.calibrated_y(kk)]'+5, 'g', 'linewidth', 2);
end
for(sac = onlineSacs)
	kk = sac.iSacOn : sac.iSacOff;
	plot(kk, [eis_data.eye_data.eye_1.calibrated_x(kk); eis_data.eye_data.eye_1.calibrated_y(kk)]'-5, 'r', 'linewidth', 2);
end
plot([1; 1; nan] * idxTargetOn(tTargetOn < tEnd), [ylim'; nan] * ones(size(idxTargetOn(tTargetOn < tEnd))), 'g', 'linewidth', 2);
plot([1; 1; nan] * idxMaskOn(tMaskOn < tEnd), [ylim'; nan] * ones(size(idxMaskOn(tMaskOn < tEnd))), 'r', 'linewidth', 2);

figure;
subplot(1,2,1);
hist(onsetDiff, 20);
title('Difference in Sac On');
xlabel('Difference (ms)');
subplot(1,2,2);
hist(offsetDiff, 20);
title('Difference in Sac Off');
xlabel('Difference (ms)');


%%%%%%%%%%%%%%%%%%%%%%%%%%%%% stabilizer %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function Initialize(eyeNew)
	global pixPerArcmin sensitivityPix_2 B_IIR A_IIR bufRawX bufRawY bufFilteredX bufFilteredY xArcmin yArcmin xPix yPix dxPix dyPix dxArcmin dyArcmin

	pixPerArcmin = 1;
	sensitivityPix_2 = 0;

	% slow stabilization
	B_IIR = [ 0.0005212926;...
			   0.0020851702;...
			   0.0031277554;...
			   0.0020851702;...
			   0.0005212926 ];
	A_IIR = [0.8752161367; -1.8668754558];

	bufRawX = ones(size(B_IIR))' * eyeNew.x(1);
	bufRawY = ones(size(B_IIR))' * eyeNew.y(1);

	bufFilteredX = ones(size(A_IIR))' * eyeNew.x(1);
	bufFilteredY = ones(size(A_IIR))' * eyeNew.y(1);

	xArcmin = bufFilteredX(1);
	yArcmin = bufFilteredY(1);

	xPix = round(pixPerArcmin * xArcmin);
    yPix = round(pixPerArcmin * yArcmin);
end

function eyeNewFiltered = Update(eyeNew)
	global pixPerArcmin sensitivityPix_2 B_IIR A_IIR bufRawX bufRawY bufFilteredX bufFilteredY xArcmin yArcmin xPix yPix dxPix dyPix dxArcmin dyArcmin

	eyeNewFiltered.xArcmin = zeros(size(eyeNew.x));
	eyeNewFiltered.yArcmin = zeros(size(eyeNew.y));

	for(k = 1 : size(eyeNew.x, 2))

        if(eyeNew.tracking(k) && ~eyeNew.blinking(k))
            bufRawX = [bufRawX(2:end), eyeNew.x(k)];
            bufRawY = [bufRawY(2:end), eyeNew.y(k)];

            % Calculate the output of the filters
            xFilt = bufRawX * B_IIR - bufFilteredX * A_IIR;
            yFilt = bufRawY * B_IIR - bufFilteredY * A_IIR;

            bufFilteredX = [bufFilteredX(2:end), xFilt];
            bufFilteredY = [bufFilteredY(2:end), yFilt];

            eyeNewFiltered.xArcmin(k) = bufFilteredX(end);
            eyeNewFiltered.yArcmin(k) = bufFilteredY(end);
        end
    end

    % Convert the filtered eye positions from arcmins to pixels
    x = pixPerArcmin * bufFilteredX(1);
    y = pixPerArcmin * bufFilteredY(1);

    % Perform a rounding of the position to the closest pixel
    % only if the difference between the current and the previous position
    % is above the specified threshold
    if((x - xPix)^2 + (y - yPix)^2 > sensitivityPix_2)
    	dxPix = round(x - xPix);	% + 0.5 for rounding
    	dyPix = round(y - yPix);	% + 0.5 for rounding
        xPix = round(x);
        yPix = round(y);
        dxArcmin = bufFilteredX(2) - xArcmin;
        dyArcmin = bufFilteredY(2) - yArcmin;
        xArcmin = bufFilteredX(2);
        yArcmin = bufFilteredY(2);
    end
end