#include <stdio.h>
#include <stdlib.h>
#include <conio.h>
#include <string.h>
#include <time.h>
#include <dos.h>
#include <math.h>

#include "c:\tdt\S232\VC\S232.h"
#include "c:\matlab6p5\extern\include\mex.h"

#define BUF_A1		4
#define BUF_B1		5

#define BUF_LEAD	10
#define BUF_LAG		11

#define SRATE		20.48 /* Fs = 48828 */

#define MAX_FILENAME_LEN	128

#define AD_PTS		50000

#define NPTS 32768*10 /* 6.71 second buffers */

/****************************************************************************************************************** 
load_sounds: loads the lead and lag sounds onto AP2 card (for calibrating Alex's LDS exp't)
 ******************************************************************************************************************/

double_buffer( CalibStruct *calibInfo, float *leadSnd, float *lagSnd, long *bufpts )
{

/* prepare TDT in Matlab */
/* PD1 setup in MATLAB */
/* this function just loads the lead and lag sounds into AP2 card memory */

if ( bufpts != NPTS ) {
	mexErrMsgTxt("Incorrect number of points in sound buffers");
}

// set up buffers
dropall();
allot16( BUF_A1, NPTS );
allot16( BUF_B1, NPTS );
allotf( BUF_LEAD, NPTS );
allotf( BUF_LAG, NPTS );

// put sounds on the AP2 card!
pushf( leadSnd, NPTS );
popf( BUF_LEAD );
pushf( lagSnd, NPTS );
popf( BUF_LAG );

void mexFunction( int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[] )    
{ 
    int			ifield, jstruct, *classIDflags;
    int			NStructElems, nfields, ndim, nsignal;
	const char  *field_name, *str;
	const		mxArray *field_array_ptr;
	double		dbl;
	float		*leadSnd, *lagSnd;
	long		*bufpts;

	div_t div_result;

    /* Check for proper number of arguments */    
    if (nrhs != 3) 
		mexErrMsgTxt("only 3 input arguments required).");

	// leadSnd is the LEAD signal (1 x bufpts)
	if ( mxGetM(prhs[0])!=1 || mxGetN(prhs[0])!= bufpts)
		mexErrMsgTxt("leadSnd must be a 1xbufpts, row vector.");
	leadSnd = (float*) mxGetPr(prhs[0]);

	// lagSnd is the LAG - same size as LEAD (1 x bufpts)
	if ( mxGetM(prhs[1])!=1 || mxGetN(prhs[1])!= bufpts)
		mexErrMsgTxt("lagSnd must be a 1 x bufpts, row vector.");
	lagSnd = (float*) mxGetPr(prhs[1]);

	// bufpts should equal NPTS above
	bufpts = (long*) mxGetPr(prhs[2]);

    /* The double_buffer subroutine */
	load_sounds( leadSnd, lagSnd, bufpts);

	return;   
}