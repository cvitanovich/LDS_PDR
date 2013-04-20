#include <stdio.h>
#include <stdlib.h>
#include <conio.h>
#include <string.h>
#include <time.h>
#include <dos.h>
#include <math.h>

#include "c:\tdt\drivers\pd1sup\c\pd1_sup.h"
#include "c:\tdt\S232\VC\S232.h"
#include "c:\matlab6p5\extern\include\mex.h"
#include "e:\kip\code\include\mii.h"

#define PLAY_SPEC	1
#define CHA_SEQ		2
#define CHB_SEQ		3

#define BUF_A1		4
#define BUF_B1		5

#define BUF_A2		6
#define BUF_B2		7

#define BUF_SIGNAL	10
#define BUF_MASK	11

#define REC_SPEC	12
#define RECCHA_SEQ	13
#define RECCHB_SEQ	14

#define RECBUF_A1	15
#define RECBUF_B1	16

#define RECBUF_A2	17
#define RECBUF_B2	18

#define DECBUF_A	20
#define DECBUF_B	21

#define SRATE		33.3

#define MAX_FILENAME_LEN	128

//#define MAX_SIGNALCNT		300
//#define MAX_SIGNAL_JITTER	2

#define AD_PTS		50000

typedef struct
{
  char outFN1[MAX_FILENAME_LEN];
  char outFN2[MAX_FILENAME_LEN];
  float record;
  float latten;
  float ratten;
  float noiScale;
  unsigned int decimateFactor;
  long buf_pts;
  long nptsTotalPlay;   /* Total number of points to be played */
  unsigned int ISI;
} InfoStruct;


/*
compile in MATLAB as below
from within this program's home directory:
mex -g play2_record2D.c c:\tdt\S232\VC\S2drv32c.lib
now:
mex -g play2_record2D2.c e:\kip\code\play_record\m100.c e:\kip\code\play_record\m101.c e:\kip\code\play_record\play0.c   e:\kip\code\play_record\m202.c e:\kip\code\play_record\m210.c e:\kip\code\play_record\m214.c c:\tdt\S232\VC\S2drv32c.lib

    (needs to be compiled with e:\kip\code\play_record\play0.c 
		- this one gives quiet time by playing zeros)

	(also needs e:\kip\code\play_record\play0_record0.c 
		- this one takes care of a wierdness encountered immediately after
		running the S232z controller - that reverses the channel order for 
		one file write - plays and records zeros and then removes files)

based on double_buffer2.dll
channels are A (noise) and B (signal) and each have loops 1 and 2

Version to require HRTFs to be supplied separately for 
channels A (noise) and B (signal)

routing schedule:
LEAD:	IB(0) --> IREG(0) --> DSP(0) --> IREG(2) --> DAC(0)
LAG:	IB(1) --> IREG(1) --> DSP(1) --> IREG(3) --> DAC(1)

Version 'D2' requires flag_mask as element in structure
	flag_mask = 0	runs just as version 'D'
	flag_mask = 1	requires arg7 as mask to be played during signal buffer
					arg7 to be same size as arg5 (signal)
	and requires record_spikes as element of structure
	record_spikes = 0		does not use MII to record spike trace and allows <= 800 trials
	record_spikes = 1		uses MII to record spikes (<= 200 trials)

	and requires max_signal_jitter (>=0)
*/


double_buffer( InfoStruct *recInfo, float *arg1, float *arg2, int nSignal )
{
FILE	*fptr;
long	seekpos = 0;
float	preloadScale = .2;
int		i;
double	*RawData, *RawDataPtr;

char	OutFNA [MAX_FILENAME_LEN];
char	OutFNB [MAX_FILENAME_LEN];

float	temp;

unsigned int DEC_FACT = recInfo->decimateFactor;
unsigned int cnt = 1, SignalPlayFlag = 0;
unsigned int signalScale = 0, Signalcnt = 0, readflag = 0;

long	NPTS = recInfo->buf_pts;
long	NPTS_totalplay = recInfo->nptsTotalPlay;
long	templ;

int		src[3];
float	sf[3];

div_t	div_result;

srand( (unsigned)time( NULL ) );

// was commented out - put back in on Sep 14, 2009
if (record)
{
	play0_record0(recInfo->outFN1, recInfo->outFN2);
	remove(recInfo->outFN1);
	remove(recInfo->outFN2);
	remove(recInfo->AD_FN);
}
// end comment out

if(!S2init(0, INIT_SECONDARY, 20000))
	mexErrMsgTxt("S2init failed");

if(!APlock(200, 0))
{
	S2close();
	mexErrMsgTxt("APLock failed");
}

if(!XBlock(200, 0))
{
	APunlock(0);
	S2close();
	mexErrMsgTxt("XBlock failed");
}

trash();
dropall();

// set up buffers
allot16( PLAY_SPEC, 10);
allot16( CHA_SEQ, 10);
allot16( BUF_A1, NPTS);
allot16( BUF_A2, NPTS);
allot16( CHB_SEQ, 10);
allot16( BUF_B1, NPTS);
allot16( BUF_B2, NPTS);

// play specification list
dpush(10);
value(0);
make(0,CHA_SEQ);
make(1,CHB_SEQ);
make(2,0);
qpop16(PLAY_SPEC);

// playsequence for ChanA (Lead)
dpush(10);
value(0);
make(0,BUF_A1);
make(1,1);
make(2,BUF_A2);
make(3,1);
make(4,0);
qpop16(CHA_SEQ);
// playsequence for ChanB (Lag)
dpush(10);
value(0);
make(0,BUF_B1);
make(1,1);
make(2,BUF_B2);
make(3,1);
make(4,0);
qpop16(CHB_SEQ);


if (record)			// record eye signal
{
	// set up buffers
	allot16( REC_SPEC, 10);
	allot16( RECCHA_SEQ, 10);
	allot16( RECBUF_A1, NPTS);
	allot16( RECBUF_A2, NPTS);
	allot16( RECCHB_SEQ, 10);
	allot16( RECBUF_B1, NPTS);
	allot16( RECBUF_B2, NPTS);

	temp = ceil(NPTS / pow(2, DEC_FACT));
	allot16( DECBUF_A, temp);
	allot16( DECBUF_B, temp);

	// record specification list
	dpush(10);
	value(0);
	make(0,RECCHA_SEQ);
	make(1,RECCHB_SEQ);
	make(2,0);
	qpop16(REC_SPEC);

	// recordsequence for ChanA
	dpush(10);
	value(0);
	make(0,RECBUF_A1);
	make(1,1);
	make(2,RECBUF_A2);
	make(3,1);
	make(4,0);
	qpop16(RECCHA_SEQ);
	// recordsequence for ChanB
	dpush(10);
	value(0);
	make(0,RECBUF_B1);
	make(1,1);
	make(2,RECBUF_B2);
	make(3,1);
	make(4,0);
	qpop16(RECCHB_SEQ);
}

// allot and load buffer for signal
allotf( BUF_SIGNAL, NPTS);
pushf(arg5, NPTS);
qpopf( BUF_SIGNAL );

// allot and load buffer for flag_mask
if (recInfo->flag_mask)
{
	allotf( BUF_MASK, NPTS);
	pushf(arg7, NPTS);
	qpopf( BUF_MASK );
}

// setup PD1
PD1clear(1);
PD1srate(1,SRATE);
templ = NPTS_totalplay + 510;	// add pts for HRIRs for each sound
PD1npts(1, templ);

PD1resetDSP(1,0xFFF);
dropall();
PD1clrsched(1);
PD1nstrms(1, 2, record*2);

src[0] = DSPout[0];	sf[0] = 1;
src[1] = DSPout[2];	sf[1] = 1;
PD1addmult(1, src, sf, 2, IREG[2]);
src[0] = DSPout[1];	sf[0] = 1;
src[1] = DSPout[3];	sf[1] = 1;
PD1addmult(1, src, sf, 2, IREG[3]);

PD1addsimp(1, IREG[2], DAC[0]);  
PD1addsimp(1, IREG[0], DSPin[0]);
PD1addsimp(1, IREG[0], DSPin[1]);
PD1specIB (1, IB[0],   IREG[0]);

PD1addsimp(1, IREG[3], DAC[1]);  
PD1addsimp(1, IREG[1], DSPin[2]);
PD1addsimp(1, IREG[1], DSPin[3]);
PD1specIB (1, IB[1],   IREG[1]);

if (record)
{
	PD1specOB (1, OB[1], ADC[1]);
	PD1specOB (1, OB[0], ADC[0]);
}

// load DSPs with HRTFs
dropall();

// pushf requires the input to be single precision
// NOISE to IREG0 ->DSP0 & DSP1 (HRTFs in arg1 & arg2)
pushf(arg1, 255);
PreLoadRaw(1, DSPid[0], MONO, STACK,"","",preloadScale,preloadScale,1);

pushf(arg2, 255);
PreLoadRaw(1, DSPid[1], MONO, STACK,"","",preloadScale,preloadScale,1);

// SIGNAL to IREG1 ->DSP2 & DSP3 (HRTFs in arg3 & arg4)
pushf(arg3, 255);
PreLoadRaw(1, DSPid[2], MONO, STACK,"","",preloadScale,preloadScale,1);

pushf(arg4, 255);
PreLoadRaw(1, DSPid[3], MONO, STACK,"","",preloadScale,preloadScale,1);

// set attenuation
PA4atten(1,recInfo->latten);
PA4atten(2,recInfo->ratten);

// ready,set,go!!
dropall();
// flat noise to chanA
dpush(NPTS);
flat();
scale(recInfo->noiScale);
qpop16(BUF_A1);

dpush(NPTS);
flat();
scale(recInfo->noiScale);
qpop16(BUF_A2);
		
// nothing to chanB
dpush(NPTS);
value(0);
qpop16(BUF_B1);
				
dpush(NPTS);
value(0);
qpop16(BUF_B2);				
			
seqplay(PLAY_SPEC);
if (record)
	seqrecord(REC_SPEC);
		
PD1arm (1);
pfireall();
PD1go (1);

do
{
 	do{}while (playseg(1)==BUF_A1);		// wait for #1 buffers to finish

	SignalPlayFlag = 0;

	if(signalScale >0)						// signal playing
	{
		readflag = 1;
	}
	else if(readflag)
	{
		readflag = 0;
		SignalPlayFlag = 1;
	}

	// re-loading #1 playbuffers
	// noise to chanA
	dropall();
	if (recInfo->flag_mask & cnt>=recInfo->ISI)
	{
		qpushf(BUF_MASK);
		scale(recInfo->noiScale);
	}
	else
	{
		dpush(NPTS);
		flat();
		scale(recInfo->noiScale);
	}
	qpop16(BUF_A1);	
		
	// signal to chanB
	dropall();
	if (cnt<recInfo->ISI)
	{
		dpush(NPTS);
		value(0);
		cnt++;
		signalScale = 0;
	} else
	{
		qpushf(BUF_SIGNAL);
		if (MAX_SIGNAL_JITTER > 0)
		{
			div_result = div( rand (), MAX_SIGNAL_JITTER );
			cnt = div_result.rem;
		} else
		{
			cnt = 0;
		}
		signalScale = arg6[Signalcnt ++];
	}

	scale(signalScale);
	qpop16(BUF_B1);

	if(record)
	{		// downloading  #1 recordbuffers
		qpush16 (RECBUF_A1);    
		decimate (DEC_FACT);
		make(0, SignalPlayFlag);
		qpop16   (DECBUF_A);
		dama2disk16 (DECBUF_A, recInfo->outFN1, 1); 
		qpush16 (RECBUF_B1);
		decimate (DEC_FACT);
		make(0, SignalPlayFlag);
		qpop16   (DECBUF_B);
		dama2disk16 (DECBUF_B, recInfo->outFN2, 1);
		dropall ();
	}

	seekpos += NPTS;
	if(seekpos < NPTS_totalplay)
	{
		// wait for #2 buffers to finish
		do{}while (playseg(1)==BUF_A2);		// wait for #2 buffers to finish

		SignalPlayFlag=0;

		if(signalScale >0)						// signal playing
		{
			m101a(C_DATA,M_BIT,M_PULSE, 0);     //send pulse out m101 to start spikecounts
			readflag = 1;
		}
		else if(readflag)
		{
			readflag = 0;
			SignalPlayFlag = 1;
		}

		// reload #2 playbuffers
		// noise to chanA
		dropall();
		if (recInfo->flag_mask & cnt>=recInfo->ISI)
		{
			qpushf(BUF_MASK);
			scale(recInfo->noiScale);
		}
		else
		{
			dpush(NPTS);
			flat();
			scale(recInfo->noiScale);
		}
		qpop16(BUF_A2);
		
		// signal to chanB
		dropall();
		if (cnt < recInfo->ISI)
		{
			dpush(NPTS);
			value(0);
			signalScale = 0;
			cnt++;
		} else
		{
			qpushf(BUF_SIGNAL);

			if (MAX_SIGNAL_JITTER > 0)
			{
				div_result = div( rand (), MAX_SIGNAL_JITTER );
				cnt = div_result.rem;
			} else
			{
				cnt = 0;
			}

			signalScale = arg6[Signalcnt ++];
		}

		scale(signalScale);
		qpop16(BUF_B2);

		if (record)
		{		// download #2 recordbuffers
			qpush16 (RECBUF_A2);    
			decimate (DEC_FACT);
			make(0,SignalPlayFlag);
			qpop16	(DECBUF_A);
			dama2disk16 (DECBUF_A, recInfo->outFN1, 1);
			qpush16 (RECBUF_B2);
			decimate (DEC_FACT);
			make(0,SignalPlayFlag);
			qpop16   (DECBUF_B);
			dama2disk16 (DECBUF_B, recInfo->outFN2, 1);
			dropall ();
		}

		if (playseg(1) !=BUF_A1)
		{
			PD1stop(1);
			mexPrintf("got to %d percent of the way\n",seekpos/NPTS_totalplay);
			mexErrMsgTxt(" APcard too slow? or outFNs incorrect?");
		}

		seekpos += NPTS;
	}
	if (Signalcnt > nSignal)
		Signalcnt = 0;

} while(seekpos < NPTS_totalplay);

PA4mute(1);
PA4mute(2);		
		
//PD1stop(1);
//PD1clear(1);
trash();
dropall();


if (record_spikes)
{
	temp = Signalcnt * AD_PTS;
	mexPrintf("%d  signals and %8.0f  total conversions\n",Signalcnt,temp);

	if ((fptr = fopen(recInfo->AD_FN, "wb+")) == NULL)
	{
	 	mexPrintf("Couldn't open file <%s> for writing\n", recInfo->AD_FN);
	}
	else
	{
		fseek(fptr, 0, 'bof');
		fwrite(RawData, sizeof(double), temp, fptr);
		fclose(fptr);
	}
}

APunlock(0);
XBunlock(0);
S2close();

play0();
}


void mexFunction( int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[] )    
{ 
    int			ifield, jstruct, *classIDflags;
    int			NStructElems, nfields, ndim, nsignal;
	const char  *field_name, *str;
	const		mxArray *field_array_ptr;
	double		dbl;
	float		*arg1, *arg2, *arg3, *arg4, *arg5, *arg7;
	double		*arg6;

	div_t div_result;

	InfoStruct recInfo;

    /* Check for proper number of arguments */    
    if (nrhs < 7 || nrhs > 8) 
		mexErrMsgTxt("Eight input arguments allowed (7 required)."); 
	else if(!mxIsStruct(prhs[0]))
		mexErrMsgTxt("Input1 must be a structure.");

	// deal with the structure (arg0)
    nfields = mxGetNumberOfFields(prhs[0]);
    NStructElems = mxGetNumberOfElements(prhs[0]);

    /* check each field. */
	for(ifield=0; ifield<nfields; ifield++) 
	{
		field_name = mxGetFieldNameByNumber(prhs[0], ifield);
		field_array_ptr = mxGetFieldByNumber(prhs[0], 0, ifield); 

	    if (field_array_ptr == NULL)
			mexPrintf(".%s is empty\n", field_name);
		else
		{
			str = mxArrayToString(field_array_ptr);
			dbl = mxGetScalar(field_array_ptr);
			if(strncmp("FN1", field_name, 3) == 0)
				strncpy(recInfo.outFN1, str, MAX_FILENAME_LEN);

			if (strncmp("FN2",field_name, 3) ==0)
				strncpy(recInfo.outFN2, str, MAX_FILENAME_LEN);

			if (strncmp("AD_FN",field_name, 5) ==0)
				strncpy(recInfo.AD_FN, str, MAX_FILENAME_LEN);

			if (strncmp("record",field_name, 6) ==0)
				recInfo.record = (unsigned int) dbl;

			if (strncmp("spikes_record",field_name, 13) ==0)
				recInfo.record_spikes = (unsigned int) dbl;

			if (strncmp("latten",field_name, 6) ==0)
				recInfo.latten = (float) dbl;

			if (strncmp("ratten",field_name, 6) ==0)
				recInfo.ratten = (float) dbl;

			if (strncmp("noiScale",field_name, 8) ==0)
				recInfo.noiScale = (float) dbl;

			if (strncmp("decimateFactor",field_name, 14) ==0)
				recInfo.decimateFactor = (unsigned int) dbl;

			if (strncmp("buf_pts",field_name, 7) ==0)
				recInfo.buf_pts = (long) dbl;

			if (strncmp("nptsTotalPlay",field_name, 13) ==0)
				recInfo.nptsTotalPlay = (long) dbl;

			if (strncmp("ISI",field_name, 3) ==0)
				recInfo.ISI = (unsigned int) dbl;

			// supply the mask buffer as arg8??
			if (strncmp("flag_mask",field_name, 9) ==0)
				recInfo.flag_mask = (double) dbl;


			if (strncmp("max_signal_jitter",field_name, 17) ==0)
				recInfo.max_signal_jitter = (unsigned int) dbl;
			
		}
	}


// check buf_pts = (n * 2^decimateFactor);
	div_result = div( recInfo.buf_pts, pow(2,recInfo.decimateFactor) );
    if(div_result.rem)
	{
		recInfo.buf_pts = pow(2,recInfo.decimateFactor) * (div_result.quot +1);
		mexPrintf("buf_pts and decimateFactor incompatable. buf_pts increased to %d \n",recInfo.buf_pts);
	}

// check nptsTotalPlay = (n * buf_pts)
	div_result = div( recInfo.nptsTotalPlay, recInfo.buf_pts );
    if(div_result.rem)
	{
		recInfo.nptsTotalPlay = recInfo.buf_pts * (div_result.quot +1);
		mexPrintf("buf_pts and totalpts incompatable. nptsTotalPlay increased to %d \n",recInfo.nptsTotalPlay);
	}
	div_result = div( recInfo.nptsTotalPlay, (recInfo.buf_pts * recInfo.ISI) );	
	recInfo.n_trials = (int) div_result.quot +1;

	// if n_trials too big, then record_spikes == 0
	if (recInfo.n_trials >200 & recInfo.record_spikes)
	{
		mexPrintf("Too many trials to record_spikes. Record_spikes set to zero. \n");
		recInfo.record_spikes = 0;
	}

	/* arg1 and arg2 are HRTF array names for the NOISE*/
	if ( mxGetM(prhs[1])!=1 || mxGetN(prhs[1])!=255)
		mexErrMsgTxt("arg2 must be a 1x255, row vector.");
	arg1 = mxGetPr(prhs[1]);

	if ( mxGetM(prhs[2])!=1 || mxGetN(prhs[1])!=255)
		mexErrMsgTxt("arg3 must be a 1x255, row vector.");
	arg2 = mxGetPr(prhs[2]);

	/* arg3 and arg4 are HRTF array names for the SIGNAL*/
	if ( mxGetM(prhs[3])!=1 || mxGetN(prhs[3])!=255)
		mexErrMsgTxt("arg4 must be a 1x255, row vector.");
	arg3 = mxGetPr(prhs[3]);

	if ( mxGetM(prhs[4])!=1 || mxGetN(prhs[4])!=255)
		mexErrMsgTxt("arg5 must be a 1x255, row vector.");
	arg4 = mxGetPr(prhs[4]);

	// arg5 is the signal (1 x bufpts)
	if ( mxGetM(prhs[5])!=1 || mxGetN(prhs[5])!= recInfo.buf_pts)
		mexErrMsgTxt("arg6 must be a 1xbufpts, row vector.");
	arg5 = mxGetPr(prhs[5]);
    
	// arg6 is a 1 x n (n>=n_trials) array of signalScaleFactors (0 - 32000)
	nsignal = mxGetN(prhs[6]);
	if ( mxGetM(prhs[6])!=1 || nsignal < recInfo.n_trials)
		mexErrMsgTxt("arg7 must be a 1 x n (n > n_trials), row vector.");
	arg6 = mxGetPr(prhs[6]);

	// arg7 is the mask - same size as signal (1 x bufpts)
	if (recInfo.flag_mask)
	{
		if ( mxGetM(prhs[7])!=1 || mxGetN(prhs[7])!= recInfo.buf_pts)
			mexErrMsgTxt("arg8 must be a 1 x bufpts, row vector.");
		arg7 = mxGetPr(prhs[7]);
	}
	else
		arg7 = 0;

	/* Create a matrix for the return argument */ 
	plhs[0] = mxCreateDoubleMatrix(1,1,mxREAL); 
    
    /* The double_buffer subroutine */
	double_buffer( &recInfo, arg1, arg2, arg3, arg4, arg5, arg6, arg7, nsignal );

	return;   
}