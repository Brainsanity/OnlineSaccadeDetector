#include "SaccadeDetector.h"
#include <math.h>

SaccadeDetector::SaccadeDetector(
		const eye::signal::DataSliceEyeBlock::ptr_t &pData,
		int rfRate,				// monitor refresh rate
		float sRate,			// sampling rate of the eye trace
		float hysterisis,			// hysterisis for marking the end of a saccade (ms)
		float minDur,				// minimal duration of a saccade (ms)
		float devThresh,			// threshold for deviation (arcmin)
		float refWindow,			// reference window for saccade detection (ms)
		float refInterval			// interval between refWindow and the sample in observation (ms)
		):
    _rfRate(rfRate),
    _sRate(sRate),
    _hysterisis(hysterisis),
    _minDur(minDur),
    _devThresh(devThresh),
    _refWindow(refWindow),
    _refInterval(refInterval)
{
	_hysterisis = _hysterisis / (1000.0 / _rfRate);
	_minDur = _minDur / (1000.0 / _rfRate);
	_refWindow = (int) (_refWindow / 1000 * _sRate + 0.5);
	_refInterval = (int) (_refInterval / 1000 * _sRate + 0.5);

	Initialize(pData);
}

SaccadeDetector::~SaccadeDetector(){}

void SaccadeDetector::Initialize(const eye::signal::DataSliceEyeBlock::ptr_t &pData)
{
	_xBuf.clear();
	_yBuf.clear();

	float x, y;
	if(pData){
		x = pData->getFirst()->calibrated1.x();
		y = pData->getFirst()->calibrated1.y();
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

	_isBlinking = false;
	_isNoTrack = false;
}

void SaccadeDetector::Update(const eye::signal::DataSliceEyeBlock::ptr_t &pData)
{
	for(int i = 0; i < pData->size(); i++){
		auto pSlice = pData->get(i);
		_xBuf.erase(_xBuf.begin());
		_yBuf.erase(_yBuf.begin());
		_xBuf.push_back(pSlice->calibrated1.x());
		_yBuf.push_back(pSlice->calibrated1.y());
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

	if(!_isSaccadeOn && deviation > _devThresh){
		_isSaccadeOn = true;
        _curDur = 0;
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

	_isBlinking = pData->getLatest()->blinking1;
	_isNoTrack = !(pData->getLatest()->tracking1);
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