load('20210605_04.mat');

[isSacOn, isBlinking, isNoTracking, deviation] = main(...
														double(eis_data.eye_data.eye_1.calibrated_x),...
														double(eis_data.eye_data.eye_1.calibrated_y),...
														logical(eis_data.eye_data.eye_1.blinking),...
														logical(eis_data.eye_data.eye_1.tracking),...
														int32(eis_data.eye_data.timing.spd)...
												);

figure; hold on;
plot(eis_data.eye_data.eye_1.calibrated_x, 'b');
plot(eis_data.eye_data.eye_1.calibrated_y, 'r');

idx = cumsum(eis_data.eye_data.timing.spd);
x = eis_data.eye_data.eye_1.calibrated_x(idx);
y = eis_data.eye_data.eye_1.calibrated_y(idx);
plot(idx(isSacOn), x(isSacOn), 'k.');
plot(idx(isSacOn), y(isSacOn), 'k.');
plot(idx, deviation*100, 'k');
plot(xlim, [500 500], 'k--');