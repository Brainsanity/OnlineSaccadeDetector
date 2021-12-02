#pragma once
// #include <eye/protocol.hpp>
// #include <eye/signal.hpp>
#include <vector>

class EyeData{
public:
	std::vector<float> x;
	std::vector<float> y;
	std::vector<bool> blinking1;
	std::vector<bool> tracking1;
};

class SaccadeDetector{

public:
	SaccadeDetector(		
		EyeData* pData = nullptr,
		int rfRate = 200,				// monitor refresh rate
		float sRate = 1016.185,			// sampling rate of the eye trace
		float hysterisis = 15,			// hysterisis for marking the end of a saccade (ms)
		float minDur = 15,				// minimal duration of a saccade (ms)
		float minInterval = 15,			// minimal duration of a saccade, any event happens less than this after a detected saccade will be ignored (ms)
		float devThresh = 5,			// threshold for deviation (arcmin)
		float devOffThresh = 10,		// offset threshold for deviation (arcmin)
		float refWindow = 30,			// reference window for saccade detection (ms)
		float refInterval = 3,			// interval between refWindow and the sample in observation (ms)
		float mtHysterisis = 15,		// hysterisis for marking the end of a mistrack (ms)
		float mtDevThresh = 100			// threshold for deviation to detect mistrack (arcmin)
		);
	~SaccadeDetector();

	void Initialize(EyeData* pData);
	float Update(EyeData* pData);
	bool IsSaccadeOn();
	bool IsBlinking();
	bool IsNoTracking();
	bool IsMistracking();


private:
	int _rfRate;
	float _sRate;
	float _hysterisis;
	float _minDur;
	float _minInterval;
	float _devThresh;
	float _devOffThresh;
	float _refWindow;
	float _refInterval;
	bool _isSaccadeOn;
	float _curHysterisis;
	float _curDur;
	float _curInterval;
	std::vector<float> _xBuf;
	std::vector<float> _yBuf;

	// parameters for mistrack detection
	float _maxEyeVelocity;		// max eye velocity; according to the literature, peak velocity of a 90 deg saccade is less than 720 deg/s (arcmin/sample)
	float _mtHysterisis;
	float _mtDevThresh;
	bool _isMistrack;
	float _mtCurHysterisis;

	bool _isBlinking;
	bool _isNoTrack;
};