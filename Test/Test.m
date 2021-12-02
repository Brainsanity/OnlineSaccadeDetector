% load('20210605_04.mat');
load('20211129-02-MR');

hysterisis = 0;5;15;		% hysterisis for marking the end of a saccade (ms)
minDur = 15;				% minimal duration of a saccade (ms)
minInterval = 30;15;		% minimal duration of a saccade, any event happens less than this after a detected saccade will be ignored (ms)
devThresh = 8;10;5;			% threshold for deviation (arcmin)
devOffThresh = 32;16;20;10;	% offset threshold for deviation (arcmin)
refWindow = 10;20;30;		% reference window for saccade detection (ms)
refInterval = 3;1;

[isSacOn, isBlinking, isNoTracking, isMistracking, deviation] = main(...
														double(eis_data.eye_data.eye_1.calibrated_x),...
														double(eis_data.eye_data.eye_1.calibrated_y),...
														logical(eis_data.eye_data.eye_1.blinking),...
														logical(eis_data.eye_data.eye_1.tracking),...
														int32(eis_data.eye_data.timing.spd),...
														single(hysterisis),...
														single(minDur),...
														single(minInterval),...
														single(devThresh),...
														single(devOffThresh),...
														single(refWindow),...
														single(refInterval)...
												);

figure; hold on; h = [];
h(1) = plot(eis_data.eye_data.timing.elapsed * 1000, eis_data.eye_data.eye_1.calibrated_x, 'b', 'DisplayName', 'x');
h(end+1) = plot(eis_data.eye_data.timing.elapsed * 1000, eis_data.eye_data.eye_1.calibrated_y, 'r', 'DisplayName', 'y');

idx = cumsum(eis_data.eye_data.timing.spd);
x = eis_data.eye_data.eye_1.calibrated_x(idx);
y = eis_data.eye_data.eye_1.calibrated_y(idx);

if(any(isSacOn))
	h(end+1) = 	plot(eis_data.eye_data.timing.elapsed(idx(isSacOn & ~isMistracking & ~isNoTracking & ~isBlinking)) * 1000, x(isSacOn & ~isMistracking & ~isNoTracking & ~isBlinking), 'k.', 'MarkerSize', 10, 'DisplayName', 'saccade');
				plot(eis_data.eye_data.timing.elapsed(idx(isSacOn & ~isMistracking & ~isNoTracking & ~isBlinking)) * 1000, y(isSacOn & ~isMistracking & ~isNoTracking & ~isBlinking), 'k.', 'MarkerSize', 10);
end

if(any(isMistracking))
	h(end+1) = 	plot(eis_data.eye_data.timing.elapsed(idx(isMistracking)) * 1000, x(isMistracking), 'yo', 'MarkerSize', 6, 'DisplayName', 'mistrack');
				plot(eis_data.eye_data.timing.elapsed(idx(isMistracking)) * 1000, y(isMistracking), 'yo', 'MarkerSize', 6);
end

if(any(isNoTracking))
	h(end+1) = 	plot(eis_data.eye_data.timing.elapsed(idx(isNoTracking)) * 1000, x(isNoTracking), 'mo', 'MarkerSize', 10, 'DisplayName', 'notrack');
				plot(eis_data.eye_data.timing.elapsed(idx(isNoTracking)) * 1000, y(isNoTracking), 'mo', 'MarkerSize', 10);
end

if(any(isBlinking))
	h(end+1) = 	plot(eis_data.eye_data.timing.elapsed(idx(isBlinking)) * 1000, x(isBlinking), 'ko', 'MarkerSize', 14, 'DisplayName', 'blink');
				plot(eis_data.eye_data.timing.elapsed(idx(isBlinking)) * 1000, y(isBlinking), 'ko', 'MarkerSize', 14);
end

h(end+1) =	plot(eis_data.eye_data.timing.elapsed(idx) * 1000, deviation*100, 'g', 'DisplayName', 'deviation*100');
h(end+1) =	plot(eis_data.eye_data.timing.elapsed([1 end]) * 1000, [100 100]*devThresh, 'g--', 'DisplayName', 'on threshold');
h(end+1) =	plot(eis_data.eye_data.timing.elapsed([1 end]) * 1000, [100 100]*devOffThresh, 'g--', 'DisplayName', 'off threshold');

legend(h);
xlabel('Time (ms)');
ylabel('Position (arcmin');