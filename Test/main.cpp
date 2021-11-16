#include "SaccadeDetector.h"
#include "mex.h"

void mexFunction(
    int nlhs,              // Number of left hand side (output) arguments
    mxArray *plhs[],       // Array of left hand side arguments: IsSaccadeOn, IsBlinking, IsNoTracking
    int nrhs,              // Number of right hand side (input) arguments
    const mxArray *prhs[]  // Array of right hand side arguments: x, y, blinking, tracking, sample per frame
){
	// extract input arguments
	if ( nrhs < 5 ) mexErrMsgTxt("Arguments error!");

	if( mxDOUBLE_CLASS != mxGetClassID(prhs[0]) ) mexErrMsgTxt("First argument should be eye x (double)!");
	if( mxDOUBLE_CLASS != mxGetClassID(prhs[1]) ) mexErrMsgTxt("Second argument should be eye y (double)!");
	if( !mxIsLogical(prhs[2]) ) mexErrMsgTxt("Third argument should be blinking flag (logical)!");
	if( !mxIsLogical(prhs[3]) ) mexErrMsgTxt("Four argument should be blinking flag (logical)!");
	if( !mxIsInt32(prhs[4]) ) mexErrMsgTxt("Fifth argument should be sample per frame (int32)!");

	double* pX = (double*)mxGetPr(prhs[0]);
	double* pY = (double*)mxGetPr(prhs[1]);
	bool* pBlinking = (bool*)mxGetPr(prhs[2]);
	bool* pTracking = (bool*)mxGetPr(prhs[3]);
	int* pSPF = (int*)mxGetPr(prhs[4]);
	int nSamples = mxGetNumberOfElements(prhs[0]);
	int nFrames = mxGetNumberOfElements(prhs[4]);

	float hysterisis = 15;			// hysterisis for marking the end of a saccade (ms)
	float minDur = 15;				// minimal duration of a saccade (ms)
	float devThresh = 5;			// threshold for deviation (arcmin)
	float refWindow = 30;			// reference window for saccade detection (ms)
	float refInterval = 3;			// interval between refWindow and the sample in observation (ms)
	if( nrhs >= 6 && mxIsSingle(prhs[5]) )	 hysterisis		= *(float*)mxGetPr(prhs[5]);
	if( nrhs >= 7 && mxIsSingle(prhs[6]) )	 minDur 		= *(float*)mxGetPr(prhs[6]);
	if( nrhs >= 8 && mxIsSingle(prhs[7]) )	 devThresh		= *(float*)mxGetPr(prhs[7]);
	if( nrhs >= 9 && mxIsSingle(prhs[8]) )	 refWindow		= *(float*)mxGetPr(prhs[8]);
	if( nrhs >= 10 && mxIsSingle(prhs[9]) )	 refInterval	= *(float*)mxGetPr(prhs[9]);
	mexPrintf("hysterisis class ID: %d, name: %s\n", mxGetClassID(prhs[5]), mxGetClassName(prhs[5]));

	// create output arguments
	plhs[0] = mxCreateLogicalMatrix(1, nFrames);	// IsSaccadeOn
	plhs[1] = mxCreateLogicalMatrix(1, nFrames);	// IsBlinking
	plhs[2] = mxCreateLogicalMatrix(1, nFrames);	// IsNoTracking
	plhs[3] = mxCreateDoubleMatrix(1, nFrames, mxREAL);		// deviation
	bool* pIsSaccadeOn = (bool*)mxGetPr(plhs[0]);
	bool* pIsBlinking = (bool*)mxGetPr(plhs[1]);
	bool* pIsNoTracking = (bool*)mxGetPr(plhs[2]);
	double* pDeviation = (double*)mxGetPr(plhs[3]);


	// perform saccade detection
	SaccadeDetector sacDetector(nullptr, 200, 1016.185, hysterisis, minDur, devThresh, refWindow, refInterval);
	
	EyeData eyeData;
	int iSample = 0;
	
	for(int i = 0; i < nFrames; i++){
		eyeData.x.clear();
		eyeData.y.clear();
		eyeData.blinking1.clear();
		eyeData.tracking1.clear();
	
		for(int j = 0; j < pSPF[i]; j++){
			eyeData.x.push_back(pX[iSample+j]);
			eyeData.y.push_back(pY[iSample+j]);
			eyeData.blinking1.push_back(pBlinking[iSample+j]);
			eyeData.tracking1.push_back(pTracking[iSample+j]);
		}
	
		iSample += pSPF[i];

		if(i == 0) sacDetector.Initialize(&eyeData);
		pDeviation[i] = sacDetector.Update(&eyeData);

		pIsSaccadeOn[i] = sacDetector.IsSaccadeOn();
		pIsBlinking[i] = sacDetector.IsBlinking();
		pIsNoTracking[i] = sacDetector.IsNoTracking();
	}
}