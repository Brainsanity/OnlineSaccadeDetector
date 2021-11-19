#include "SaccadeDetector.h"
#include <math.h>
#include "mex.h"

SaccadeDetector::SaccadeDetector(
		EyeData* pData,
		int rfRate,				// monitor refresh rate
		float sRate,			// sampling rate of the eye trace
		float hysterisis,			// hysterisis for marking the end of a saccade (ms)
		float minDur,				// minimal duration of a saccade (ms)
		float minInterval,			// minimal duration of a saccade, any event happens less than this after a detected saccade will be ignored (ms)
		float devThresh,			// threshold for deviation (arcmin)
		float refWindow,			// reference window for saccade detection (ms)
		float refInterval			// interval between refWindow and the sample in observation (ms)
		):
    _rfRate(rfRate),
    _sRate(sRate),
    _hysterisis(hysterisis),
    _minDur(minDur),
    _minInterval(minInterval),
    _devThresh(devThresh),
    _refWindow(refWindow),
    _refInterval(refInterval)
{
	mexPrintf("rfRate = %d Hz\n", rfRate);
	mexPrintf("sRate = %.3f Hz\n", sRate);
	mexPrintf("hysterisis = %.0f ms\n", hysterisis);
	mexPrintf("minDur = %.0f ms\n", minDur);
	mexPrintf("devThresh = %.2f arcmin\n", devThresh);
	mexPrintf("refWindow = %.0f ms\n", refWindow);
	mexPrintf("refInterval = %.0f ms\n\n", refInterval);

	_hysterisis = _hysterisis / (1000.0 / _rfRate);
	_minDur = _minDur / (1000.0 / _rfRate);
	_minInterval = _minInterval / (1000.0 / _rfRate);
	_refWindow = (int) (_refWindow / 1000 * _sRate + 0.5);
	_refInterval = (int) (_refInterval / 1000 * _sRate + 0.5);

	mexPrintf("_hysterisis = %.0f frames\n", _hysterisis);
	mexPrintf("_minDur = %.0f frames\n", _minDur);
	mexPrintf("_devThresh = %.2f arcmin\n", _devThresh);
	mexPrintf("_refWindow = %.0f frames\n", _refWindow);
	mexPrintf("_refInterval = %.0f frames\n", _refInterval);

	Initialize(pData);
}

SaccadeDetector::~SaccadeDetector(){}

void SaccadeDetector::Initialize(EyeData* pData)
{
	_xBuf.clear();
	_yBuf.clear();

	float x, y;
	if(pData){
		x = pData->x[0];
		y = pData->y[0];
	} else{
		x = 0;
		y = 0;
	}
	for(int i = 0; i < _refWindow + _refInterval; i++){
		_xBuf.push_back(x);
		_yBuf.push_back(y);
	}

	_isSaccadeOn = false;
	_curHysterisis = 0;
	_curDur = 0;
	_curInterval = _minInterval + 1;

	_isBlinking = false;
	_isNoTrack = false;
}

float SaccadeDetector::Update(EyeData* pData)
{
	for(int i = 0; i < pData->x.size(); i++){
		// auto pSlice = pData->get(i);
		_xBuf.erase(_xBuf.begin());
		_yBuf.erase(_yBuf.begin());
		_xBuf.push_back(pData->x[i]);
		_yBuf.push_back(pData->y[i]);
	}

	float xVel = (_xBuf[_xBuf.size()-1-_refInterval] - _xBuf[0]) / (_refWindow - 1);
	float yVel = (_yBuf[_yBuf.size()-1-_refInterval] - _yBuf[0]) / (_refWindow - 1);

	float xRefMean = 0, yRefMean = 0;
	for(int i = 0; i < _refWindow; i++){
		xRefMean += _xBuf[i] - i*xVel;
		yRefMean += _yBuf[i] - i*yVel;
	}
	xRefMean = xRefMean / _refWindow;
	yRefMean = yRefMean / _refWindow;

	float deviation = sqrt(pow(_xBuf[_xBuf.size()-1] - (_refWindow+_refInterval-1)*xVel - xRefMean, 2.0) + pow(_yBuf[_yBuf.size()-1] - (_refWindow+_refInterval-1)*yVel - yRefMean, 2.0));

	if(!_isSaccadeOn && deviation > _devThresh && _curInterval >= _minInterval){
		_isSaccadeOn = true;
        _curDur = 0;
        _curInterval = 0;
        _curHysterisis = 0;
    }

	if(_isSaccadeOn){
		_curDur++;
		if(deviation < _devThresh){
	        _curHysterisis++;
			if(_curHysterisis > _hysterisis && _curDur > _minDur) _isSaccadeOn = false;
	    }
	    else _curHysterisis = 0;
	}

	if(!_isSaccadeOn){
		_curInterval++;
		if(deviation > _devThresh) _curInterval = 0;
	}

	_isBlinking = pData->blinking1[pData->blinking1.size()-1];
	_isNoTrack = !(pData->tracking1[pData->tracking1.size()-1]);

	return deviation;
}

bool SaccadeDetector::IsSaccadeOn()
{
	return _isSaccadeOn;
}

bool SaccadeDetector::IsBlinking()
{
	return _isBlinking;
}

bool SaccadeDetector::IsNoTracking()
{
	return _isNoTrack;
}