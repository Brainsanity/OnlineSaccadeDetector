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
		float refWindow = 30,			// reference window for saccade detection (ms)
		float refInterval = 3			// interval between refWindow and the sample in observation (ms)
		);
	~SaccadeDetector();

	void Initialize(EyeData* pData);
	float Update(EyeData* pData);
	bool IsSaccadeOn();
	bool IsBlinking();
	bool IsNoTracking();


private:
	int _rfRate;
	float _sRate;
	float _hysterisis;
	float _minDur;
	float _minInterval;
	float _devThresh;
	float _refWindow;
	float _refInterval;
	bool _isSaccadeOn;
	float _curHysterisis;
	float _curDur;
	float _curInterval;
	std::vector<float> _xBuf;
	std::vector<float> _yBuf;

	bool _isBlinking;
	bool _isNoTrack;
};