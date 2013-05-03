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

#define PLAY_SPEC	1
#define CHA_SEQ		2
#define CHB_SEQ		3

#define BUF_A1		4
#define BUF_B1		5

#define BUF_A2		6
#define BUF_B2		7

#define REC_SPEC	12
#define RECCHA_SEQ	13
#define RECCHB_SEQ	14

#define RECBUF_A1	15
#define RECBUF_B1	16

#define RECBUF_A2	17
#define RECBUF_B2	18

#define DECBUF_A	20
#define DECBUF_B	21

#define BUF_LEAD(a)	    (2*a + 22) /* 22, 24, ... (no real limit?) */
#define BUF_LAG(b)		(2*b + 23) /* 23, 25, ... (no real limit?) */
#define MAXCARRIERS		32 /* setting limit to 32 carriers */

#define SRATE		20.48 /* Fs = 48828 */

#define MAX_FILENAME_LEN	128

#define AD_PTS		50000

#define DEFAULT_PTS 32768 /* 0.671 second buffer with 48828 sampling rate! */


typedef struct
{
  char outFN1[MAX_FILENAME_LEN];
  char outFN2[MAX_FILENAME_LEN];
  unsigned int record;
  unsigned int n_trials;
  float latten;
  float ratten;
  unsigned int decimateFactor;
  long buf_pts;
  long nptsTotalPlay;   /* Total number of points to be played */
  unsigned int ISI;
  unsigned int max_signal_jitter;
  unsigned int num_carriers; /* number of carriers to rove */
  unsigned int n_speakers; /* number of speakers */
  long	sound_onset; /* offset between sound buffer beginning and sound onset (in buffer pts) */
  unsigned int trials_to_show;
  float hab_loc;
  float test_trial_freq;
} InfoStruct;

/* Final version altered by Andrew on 10/22/2012 */
/* altered to permit carrier roving */
/*
compile in MATLAB as below
from within this program's home directory:
mex -g play2_record2D.c c:\tdt\S232\VC\S2drv32c.lib
now:
mex -g play2_record2D2_alex7.c c:\kip\code\play_record\play0.c c:\kip\code\play_record\play0_record0.c c:\tdt\S232\VC\S2drv32c.lib

    (needs to be compiled with c:\kip\code\play_record\play0.c 
		- this one gives quiet time by playing zeros)

	(also needs c:\kip\code\play_record\play0_record0.c 
		- this one takes care of a wierdness encountered immediately after
		running the S232z controller - that reverses the channel order for 
		one file write - plays and records zeros and then removes files)

based on double_buffer2.dll
channels are A (LEAD) and B (LAG) and each have loops 1 and 2

NO HRTFS (signal switched btwn speakers)

routing schedule:
LEAD:	IB(0) --> IREG(0) --> DAC(0) --> left PF1 --> left PA4 --> Lead Speaker
						  
LAG:	IB(1) --> IREG(1) --> DAC(1) --> right PF1 -->  right PA4 (SPLIT)   --> input 1 (LEFT SS1)      --> OutputA  --> Hab Lag Speaker
															                --> input 2	    		    --> OutputB  --> Shift 1
																	        --> input 3  			    --> OutputC  --> Shift 2
																	        --> input 4                 --> OutputD  --> Shift 3
																	        
								                                            --> input 1 (RIGHT SS1)     --> OutputA  --> Shift 4
															                --> input 2	    		    --> OutputB  --> Shift 5
																	        --> input 3  			    --> OutputC  --> Shift 6
																	        --> input 4                 --> OutputD  --> Shift 7
																	     

VERSION for Alex to run Precedence Effect trials
	flag_mask is ignored
	record_spikes is ignored
	NO HRTFS
	scaleFactor is the same for LEAD and LAG

    argins:
	tempStruct
	leadSnds LEAD sounds													cell array of x sounds (single) [max 50]
	lagSnds LAG sounds													cell array of x sounds (single) [max 50]
	scaleVals is the calibrated scale for each speaker location		    1xn_speakers
	locations is the LAG spkr location for each test (0-3)				1xn_trials

*/


double_buffer( InfoStruct *recInfo, float *leadSnds[], float *lagSnds[], float *locations, float *azimuths, float *rove, float *scalesLead, float *scalesLag, float *attensLead, int nSignal )
{
FILE	*fptr;
long	seekpos = 0;
float	preloadScale = .2;
int		i, j;

char	OutFNA [MAX_FILENAME_LEN];
char	OutFNB [MAX_FILENAME_LEN];

float	temp;

int		record = recInfo->record;
int		cnt = 1;

unsigned int DEC_FACT = recInfo->decimateFactor;
unsigned int SignalPlayFlag = 0;
unsigned int signalScale = 0, Signalcnt = 0, readflag = 0;
unsigned int MAX_SIGNAL_JITTER = recInfo->max_signal_jitter;
unsigned int NUM_CARRIERS_TO_ROVE = recInfo->num_carriers;
unsigned int rove_id;
unsigned int TRIALS_TO_SHOW = 3;

long	NPTS = recInfo->buf_pts;

/* just for plotting PDR trace in real time */
long	DEC_PTS = ceil(NPTS / pow(2, DEC_FACT));
long	ONSET = ceil(recInfo->sound_onset / pow(2, DEC_FACT));
long	NPTS_totalplay = recInfo->nptsTotalPlay;
long	templ;
long	buffer_cnt=0;
float	HAB_LOC = recInfo->hab_loc;

int		src[3];
float	sf[3];

div_t	div_result;

int		loc;

/* Display output variables: */
int     t0,t1, n;
float	elapsed_time;
float	rem_time;
int		min;
float	sec, cntdown;
char	str[100] = { '\0' };
//long	pdrBuffer[TRACE_PTS];
int		len;
float	xy[2];

/* select SS1 output */
int		ss_id, out_port;

srand( (unsigned)time( NULL ) );

/* setup session info display */
len = ceil(NPTS * (SRATE/1E3));

// was commented out - put back in on Sep 14, 2009
if (record)
{
	play0_record0(recInfo->outFN1, recInfo->outFN2);
	remove(recInfo->outFN1);
	remove(recInfo->outFN2);
	//remove(recInfo->AD_FN);
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

// playsequence for ChanA
dpush(10);
value(0);
make(0,BUF_A1);
make(1,1);
make(2,BUF_A2);
make(3,1);
make(4,0);
qpop16(CHA_SEQ);
// playsequence for ChanB
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

// allot and load buffers for LEAD SOUNDS
for( j=0; j<NUM_CARRIERS_TO_ROVE; j++ ) {
	allotf( BUF_LEAD(j), NPTS);
	pushf(leadSnds[j], NPTS);
	qpopf(BUF_LEAD(j));
}

// allot and load buffers for LAG SOUNDS
for( j=0; j<NUM_CARRIERS_TO_ROVE; j++ ) {
	allotf( BUF_LAG(j), NPTS);
	pushf(lagSnds[j], NPTS);
	qpopf(BUF_LAG(j));
}

// setup PD1
PD1clear(1);
PD1srate(1,SRATE);
PD1npts(1,-1);

PD1resetDSP(1,0xFFF);
dropall();
PD1clrsched(1);
PD1nstrms(1, 2, record*2);

PD1addsimp(1, IREG[0], DAC[0]);  
PD1specIB (1, IB[0],   IREG[0]);

PD1addsimp(1, IREG[1], DAC[1]);  
PD1specIB (1, IB[1],   IREG[1]);

if (record)
{
	PD1specOB (1, OB[1], ADC[1]);
	PD1specOB (1, OB[0], ADC[0]);
}

PF1freq(1,12000,0);
PF1freq(2,12000,0);

dropall();

/* set LED thresholds */
PD1setIO(1,0.01,9.99,0.01,9.99);

/* setup signal switchers */

/* SWITCH BETWEEN 8 LAG SPEAKERS (Nos. 2, 3, 4, ... 9) */
/* (NOTE: Speaker #1 is reserved for the lead sound) */

SS1clear(1); /* left SS1 (LAG) */
SS1mode(1, QUAD_2_1); /* inputs 1, 3, 5, 7 => outputs A,B,C,D */
SS1select(1,0,1); /* Default Lag Output is A (Hab Location) */

// set attenuation
PA4atten(1,0); /* lead channel */
PA4atten(2,0); /* lag ch */

// ready,set,go!!
dropall();

// nothing to chanA (LEAD)
dpush(NPTS);
value(0);
qpop16(BUF_A1);

dpush(NPTS);
value(0);
qpop16(BUF_A2);
		
// nothing to chanB (LAG)
dpush(NPTS);
value(0);
qpop16(BUF_B1);
				
dpush(NPTS);
value(0);
qpop16(BUF_B2);				

return;
seqplay(PLAY_SPEC);
if (record)
	seqrecord(REC_SPEC);
		
PD1arm (1);
pfireall();
PD1go (1);

do
{
 	do{}while (playseg(1)==BUF_A1);		// wait for #1 buffers to finish
	
	t0 = clock();

	SignalPlayFlag = 0;

	if(signalScale >0)
	{
		readflag = 1;
	}
	else if(readflag)
	{
		readflag = 0;
		SignalPlayFlag = 1;
	}
	

	
	/* count down to next test trial */
	cntdown = (recInfo->ISI - cnt)*(NPTS*SRATE/1E6);
	for(i=0; i<(recInfo->n_trials - Signalcnt); i++) {
		if(locations[Signalcnt+i]!=HAB_LOC)
			break;
		cntdown += (recInfo->ISI+1)*(NPTS*SRATE/1E6);

	}
		
		
	/* display session info */
	
	elapsed_time = seekpos*(SRATE/1E6);
	div_result = div( elapsed_time, 60 );
	min = div_result.quot; sec = elapsed_time - (60*min);
	memset(str,'\0',sizeof(str));
	n=sprintf(str,"session.elapsed_time(1)=%i; session.elapsed_time(2)=%.3f;",min,sec);
	mexEvalString(str);
	rem_time = NPTS_totalplay*(SRATE/1E6) - elapsed_time;
	div_result = div( rem_time, 60 );
	min = div_result.quot; sec = rem_time - (60*min);
	memset(str,'\0',sizeof(str));
	n=sprintf(str,"session.rem_time(1)=%i; session.rem_time(2)=%.3f;",min,sec);
	mexEvalString(str);
	div_result = div( cntdown, 60 );
	min = div_result.quot; sec = cntdown - (60*min);
	memset(str,'\0',sizeof(str));
	n=sprintf(str,"session.next_test_trial(1)=%i; session.next_test_trial(2)=%.3f;",min,sec);
	mexEvalString(str);
	mexEvalString("sessionPlots('Update Session Info');");
	
	
	// re-loading #1 playbuffers
	// LEAD to chanA LAG to chanB
	dropall();
	if (cnt==recInfo->ISI)
	{
		// Jitter trial presentation
		if (MAX_SIGNAL_JITTER > 0)
		{
			cnt = ( rand() % (2*MAX_SIGNAL_JITTER+1) ) - MAX_SIGNAL_JITTER; // gives a range of +/- MAX_SIGNAL_JITTER
		} else
		{
			cnt = 0;
		}
		

		loc = locations[Signalcnt];
		/* location series indicates lag speaker # (2, 3, 4, ... 9) */

	
		// set attenuation
		PA4atten(1,attensLead[loc-2]); /* lead channel */
		PA4atten(2,0); /* lag ch */

		SS1clear(1); SS1clear(2);
		if (loc < 6) {
			ss_id = 1; /* use left SS1 */
			out_port = loc - 2; /* decrement by 2 for output selection */
		}
		else {
			ss_id = 2; /* use right SS1 */
			out_port = loc - 6; /* decrement by 6 for output selection */
		}
		
		SS1mode(ss_id, QUAD_2_1); /* inputs 1, 3, 5, 7 => outputs A,B,C,D */
		SS1select(ss_id,out_port,1); /* Chan B (LAG) location ( speakers A...D = 0...3 ) */


		
		/* plot a marker on trial sequence plot */
		memset(str,'\0',sizeof(str));
		n=sprintf(str,"session.trialcnt=%i; session.trialval=%10.1f; sessionPlots('Update Trial Plot');",Signalcnt+1,azimuths[loc-1]);
		mexEvalString(str);
		
		
		rove_id = rove[Signalcnt ++] - 1; /* decrement by 1 for C indexing */
		
		signalScale=scalesLead[loc-2];
		
		memset(str,'\0',sizeof(str));
		n=sprintf(str,"disp('num2str(%i)');",(rove_id+1));
		mexEvalString(str);
			qpushf(BUF_LEAD(rove_id));
			qdup();
			memset(str,'\0',sizeof(str));
			n=sprintf(str,"left_buf=s232('popf'); figure(hDEBUG); subplot(hA); plot(left_buf);");
			mexEvalString(str);
			scale(signalScale); /* always scale with first speaker scaling value */
			qpop16(BUF_A1);
		
		memset(str,'\0',sizeof(str));
		n=sprintf(str,"disp('num2str(%i)');",(rove_id+1));
		mexEvalString(str);
			qpushf(BUF_LAG(rove_id));
			qdup();
			memset(str,'\0',sizeof(str));
			n=sprintf(str,"right_buf=s232('popf'); figure(hDEBUG); subplot(hB); plot(right_buf);");
			mexEvalString(str);
			scale(signalScale); /* always scale with first speaker scaling value */
			qpop16(BUF_B1);
			
			memset(str,'\0',sizeof(str));
			n=sprintf(str,"text(0.5,0.7,['rove_id=num2str(%i)']);",rove_id);
			mexEvalString(str);

	}
	else
	{
		signalScale = 0;
		cnt++;
		dpush(NPTS);
		value(0);
		qpop16(BUF_A1);

		dpush(NPTS);
		value(0);
		qpop16(BUF_B1);	
	}

	
	if(record)
	{		// downloading  #1 recordbuffers
		qpush16 (RECBUF_A1);    
		decimate (DEC_FACT);
		make(0, SignalPlayFlag);
		make(1, loc);
		qpop16   (DECBUF_A);
		dama2disk16 (DECBUF_A, recInfo->outFN1, 1);

		qpush16 (RECBUF_B1);
		decimate (DEC_FACT);
		// plot PDR trace
		qdup();
		memset(str,'\0',sizeof(str));
		n=sprintf(str,"session.last_buffer=s232('popf');");
		mexEvalString(str);
		//pop16(pdrBuffer);
		// store last buffer in matlab variable for plotting
		//for(i=0; i<DEC_PTS; i++) {
		//	memset(str,'\0',sizeof(str));
		//	n=sprintf(str,"session.last_buffer(%i+1)= %i;",i,pdrBuffer[i]);
		//	mexEvalString(str);
		//}
		
		if(SignalPlayFlag) {
			if(locations[Signalcnt-1]==HAB_LOC) {
				mexEvalString("session.test_flag=1;");
			}
			else {
				mexEvalString("session.test_flag=Inf;");
			}
		}
		else {
			mexEvalString("session.test_flag=0;");
		}
		
		// tell sessionPlots to update trace
		mexEvalString("sessionPlots('Update Trace Plot');");
		make(0, SignalPlayFlag);
		make(1, loc);
		qpop16   (DECBUF_B);
		dama2disk16 (DECBUF_B, recInfo->outFN2, 1);
		dropall ();
		
	}
	
	/* processing time */
	
	t1=clock();
	memset(str,'\0',sizeof(str));
	n = sprintf(str,"session.proc_time = [session.proc_time %.3f];",((float) (t1-t0))/CLOCKS_PER_SEC);
	mexEvalString(str);
	mexEvalString("sessionPlots('Update Session Info');");
	
	seekpos += NPTS;
	if(seekpos < NPTS_totalplay)
	{
		// wait for #2 buffers to finish
		do{}while (playseg(1)==BUF_A2);		// wait for #2 buffers to finish

     	t0=clock();
     	
		SignalPlayFlag = 0;
	
		if(signalScale >0)
		{
			readflag = 1;
		}
		else if(readflag)
		{
			readflag = 0;
			SignalPlayFlag = 1;
		}
		
	/* count down to next test trial */
	cntdown = (recInfo->ISI - cnt)*(NPTS*SRATE/1E6);
	for(i=0; i<(recInfo->n_trials - Signalcnt); i++) {
		if(locations[Signalcnt+i]!=HAB_LOC)
			break;
		cntdown += (recInfo->ISI+1)*(NPTS*SRATE/1E6);

	}
		
		
	/* display session info */
	
	elapsed_time = seekpos*(SRATE/1E6);
	div_result = div( elapsed_time, 60 );
	min = div_result.quot; sec = elapsed_time - (60*min);
	memset(str,'\0',sizeof(str));
	n=sprintf(str,"session.elapsed_time(1)=%i; session.elapsed_time(2)=%.3f;",min,sec);
	mexEvalString(str);
	rem_time = NPTS_totalplay*(SRATE/1E6) - elapsed_time;
	div_result = div( rem_time, 60 );
	min = div_result.quot; sec = rem_time - (60*min);
	memset(str,'\0',sizeof(str));
	n=sprintf(str,"session.rem_time(1)=%i; session.rem_time(2)=%.3f;",min,sec);
	mexEvalString(str);
	div_result = div( cntdown, 60 );
	min = div_result.quot; sec = cntdown - (60*min);
	memset(str,'\0',sizeof(str));
	n=sprintf(str,"session.next_test_trial(1)=%i; session.next_test_trial(2)=%.3f;",min,sec);
	mexEvalString(str);
	mexEvalString("sessionPlots('Update Session Info');");

		// reload #2 playbuffers    LEAD to chanA LAG to chanB
		dropall();
		if (cnt==recInfo->ISI)
		{
			if (MAX_SIGNAL_JITTER > 0)
			{
				cnt = ( rand() % (2*MAX_SIGNAL_JITTER+1) ) - MAX_SIGNAL_JITTER; // gives a range of +/- MAX_SIGNAL_JITTER
			} else
			{
				cnt = 0;
			}
			
			loc = locations[Signalcnt];
			/* location series indicates lag speaker # (2, 3, 4, ... 9) */
	
			// set attenuation
			PA4atten(1,attensLead[loc-2]); /* lead channel */
			PA4atten(2,0); /* lag ch */
			
			SS1clear(1); SS1clear(2);
			if (loc < 6) {
				ss_id = 1; /* use left SS1 */
				out_port = loc - 2; /* decrement by 2 for output selection */
			}
			else {
				ss_id = 2; /* use right SS1 */
				out_port = loc - 6; /* decrement by 6 for output selection */
			}
		
			SS1mode(ss_id, QUAD_2_1); /* inputs 1, 3, 5, 7 => outputs A,B,C,D */
			SS1select(ss_id,out_port,1); /* Chan B (LAG) location ( speakers A...D = 0...3 ) */
		
			/* plot a marker on trial sequence plot */
			memset(str,'\0',sizeof(str));
			n=sprintf(str,"session.trialcnt=%i; session.trialval=%10.1f; sessionPlots('Update Trial Plot');",Signalcnt+1,azimuths[loc-1]);
			mexEvalString(str);

			rove_id = rove[Signalcnt ++] - 1; /* decrement by 1 for C indexing */
			
			signalScale=scalesLead[loc-2];
			
			memset(str,'\0',sizeof(str));
			n=sprintf(str,"disp('num2str(%i)');",(rove_id+1));
			mexEvalString(str);
			qpushf(BUF_LEAD(rove_id));
			qdup();
			memset(str,'\0',sizeof(str));
			n=sprintf(str,"left_buf=s232('popf'); figure(hDEBUG); subplot(hA); plot(left_buf);");
			mexEvalString(str);
			scale(signalScale); /* always scale with first speaker scaling value */
			qpop16(BUF_A2);
			
			qpushf(BUF_LAG(rove_id));
			memset(str,'\0',sizeof(str));
			n=sprintf(str,"disp('num2str(%i)');",(rove_id+1));
			mexEvalString(str);
			qdup();
			memset(str,'\0',sizeof(str));
			n=sprintf(str,"right_buf=s232('popf');  figure(hDEBUG); subplot(hB); plot(right_buf);");
			mexEvalString(str);
			scale(signalScale); /* always scale with first speaker scaling value */
			qpop16(BUF_B2);
			
			memset(str,'\0',sizeof(str));
			n=sprintf(str,"text(0.5,0.7,['rove_id=num2str(%i)']);",rove_id);
			mexEvalString(str);

		}
		else
		{
			signalScale = 0;
			cnt++;
			dpush(NPTS);
			value(0);;
			qpop16(BUF_A2);

			dpush(NPTS);
			value(0);
			qpop16(BUF_B2);
		}
		
		
		if (record)
		{		// download #2 recordbuffers
			qpush16 (RECBUF_A2);    
			decimate (DEC_FACT);
			make(0,SignalPlayFlag);
			make(1,loc);
			qpop16	(DECBUF_A);
			dama2disk16 (DECBUF_A, recInfo->outFN1, 1);

			qpush16 (RECBUF_B2);
			decimate (DEC_FACT);
			// plot PDR trace
			qdup();
			//pop16(pdrBuffer);
			memset(str,'\0',sizeof(str));
			n=sprintf(str,"session.last_buffer=s232('popf');");
			mexEvalString(str);
			// store last buffer in matlab variable for plotting
			//for(i=0; i<DEC_PTS; i++) {
			//	memset(str,'\0',sizeof(str));
			//	n=sprintf(str,"session.last_buffer(%i+1)= %i;",i,pdrBuffer[i]);
			//	mexEvalString(str);
			//}

			if(SignalPlayFlag) {
				if(locations[Signalcnt-1]==HAB_LOC) {
					mexEvalString("session.test_flag=1;");
				}
				else {
					mexEvalString("session.test_flag=Inf;");
				}
			}
			else {
				mexEvalString("session.test_flag=0;");
			}

			// tell sessionPlots to update trace
			mexEvalString("sessionPlots('Update Trace Plot');");
			make(0,SignalPlayFlag);
			make(1,loc);
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

		/* processing time */
	
		t1=clock();
		memset(str,'\0',sizeof(str));
		n = sprintf(str,"session.proc_time = [session.proc_time %.3f];",((float) (t1-t0))/CLOCKS_PER_SEC);
		mexEvalString(str);
		mexEvalString("sessionPlots('Update Session Info');");
		
	    seekpos += NPTS;
	}
	if (Signalcnt > nSignal)
		Signalcnt = 0;

} while(seekpos < NPTS_totalplay);

do{}while (playseg(1)==BUF_A1);		/* wait for last 2 buffers to finish */
do{}while (playseg(1)==BUF_A2);



PA4mute(1);
PA4mute(2);

PD1stop(1);
PD1clrIO(1);
PD1clear(1);

mexEvalString("sessionPlots('Finish Session');");

trash();
dropall();

APunlock(0);
XBunlock(0);
S2close();

}


void mexFunction( int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[] )    
{ 
	int			i,j,m,n;
    int			ifield, jstruct, *classIDflags;
    int			NStructElems, nfields, ndim, nsignal, nvals;
	const char  *field_name, *str;
	const		mxArray *field_array_ptr;
	double		dbl;
	float		*leadSnds[MAXCARRIERS], *lagSnds[MAXCARRIERS];
	float		*locations, *azimuths, *rove, *scalesLead, *scalesLag, *attensLead, *tmp;

	div_t div_result;

	InfoStruct recInfo;

    /* Check for proper number of arguments */    
    if (nrhs != 9)
		mexErrMsgTxt("9 input arguments required)."); 
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

			if (strncmp("record",field_name, 6) ==0)
				recInfo.record = (unsigned int) dbl;
		
			if (strncmp("latten",field_name, 6) ==0)
				recInfo.latten = (float) dbl;

			if (strncmp("ratten",field_name, 6) ==0)
				recInfo.ratten = (float) dbl;

			if (strncmp("n_trials",field_name,8) ==0)
				recInfo.n_trials = (unsigned int) dbl;

			if (strncmp("decimateFactor",field_name, 14) ==0)
				recInfo.decimateFactor = (unsigned int) dbl;

			if (strncmp("buf_pts",field_name, 7) ==0)
				recInfo.buf_pts = (long) dbl;

			if (strncmp("nptsTotalPlay",field_name, 13) ==0)
				recInfo.nptsTotalPlay = (long) dbl;

			if (strncmp("ISI",field_name, 3) ==0)
				recInfo.ISI = (unsigned int) dbl;

			if (strncmp("max_signal_jitter",field_name, 17) ==0)
				recInfo.max_signal_jitter = (unsigned int) dbl;

			if (strncmp("num_carriers",field_name, 12) ==0)
				recInfo.num_carriers = (unsigned int) dbl;

			if (strncmp("n_speakers",field_name, 10) ==0)
				recInfo.n_speakers = (unsigned int) dbl;

			if (strncmp("sound_onset",field_name, 11) ==0)
				recInfo.sound_onset = (long) dbl;
			
			if (strncmp("trials_to_show",field_name, 14) ==0)
				recInfo.trials_to_show = (long) dbl;

			if (strncmp("hab_loc",field_name, 7) ==0)
				recInfo.hab_loc = (float) dbl;

			if (strncmp("test_trial_freq",field_name, 15) ==0)
				recInfo.test_trial_freq = (float) dbl;
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
	div_result = div( recInfo.nptsTotalPlay, (recInfo.buf_pts * (recInfo.ISI+1)) );	
	recInfo.n_trials = (int) div_result.quot +1;

	// get LEAD and LAG sounds (should be <= 50)
	// matlab arrays should be buf_pts x num_carriers

	// LEAD
	tmp=(float *) mxGetPr(prhs[1]);
	m=mxGetM(prhs[1]); n=mxGetN(prhs[1]);
	if(recInfo.buf_pts != m || recInfo.num_carriers  != n) {
			mexPrintf("array is %i x %i",m,n);
			mexErrMsgTxt("Sound arrays must be buf_pts x num_carriers");
	}
	for(i=0;i<recInfo.num_carriers;++i)
		leadSnds[i] = &tmp[i*recInfo.buf_pts];

    // LEAD
	tmp=(float *) mxGetPr(prhs[2]);
	m=mxGetM(prhs[2]); n=mxGetN(prhs[2]);
	if(recInfo.buf_pts != m || recInfo.num_carriers != n) {
			mexPrintf("array is %i x %i",m,n);
			mexErrMsgTxt("Sound arrays must be buf_pts x num_carriers");
	}
	for(i=0;i<recInfo.num_carriers;++i)
		lagSnds[i] = &tmp[i*recInfo.buf_pts];

	
	// locations is a 1 x n (n>=n_trials) array of spkr positions to switch between (0-3)
	nsignal = mxGetN(prhs[3]);
	if ( mxGetM(prhs[3])!=1 || nsignal < recInfo.n_trials)
		mexErrMsgTxt("locations must be a 1 x n (n > n_trials), row vector.");
	locations = (float*) mxGetPr(prhs[3]);

	/* azimuths is a 1 x N array of azimuths (N = no. of speakers used) */
	azimuths = (float*) mxGetPr(prhs[4]);
   
	// rove is a 1 x n (n>=n_trials) array of sound IDs for carrier roving
	nsignal = mxGetN(prhs[5]);
	if ( mxGetM(prhs[5])!=1 || nsignal < recInfo.n_trials)
		mexErrMsgTxt("rove sequence must be a 1 x n (n > n_trials), row vector.");
	rove = (float*) mxGetPr(prhs[5]);

	/* scalesLead is a 1 x (# lag speakers) array of scales for the lead speaker */
	nvals = mxGetN(prhs[6]);
	if ( mxGetM(prhs[6])!=1 || nvals != (recInfo.n_speakers - 1) )
		mexErrMsgTxt("scales for lead speaker must by 1 x (# lag speakers), row vector.");
	scalesLead = (float*) mxGetPr(prhs[6]);

	/* scalesLag is a 1 x (# lag speakers) array of scales for the lag speakers */
	nvals = mxGetN(prhs[7]);
	if ( mxGetM(prhs[7])!=1 || nvals != (recInfo.n_speakers - 1) )
		mexErrMsgTxt("scales for lag speaker must by 1 x (# lag speakers), row vector.");
	scalesLag = (float*) mxGetPr(prhs[7]);

	/* attensLead is a 1 x (# lag speakers) array of attens for the lead speaker */
	nvals = mxGetN(prhs[8]);
	if ( mxGetM(prhs[8])!=1 || nvals != (recInfo.n_speakers - 1) )
		mexErrMsgTxt("attens for the lead speaker must be a 1 x (# lag speakers), row vector.");
	attensLead = (float*) mxGetPr(prhs[8]);

    /* The double_buffer subroutine */
	double_buffer( &recInfo, leadSnds, lagSnds, locations, azimuths, rove, scalesLead, scalesLag, attensLead, nsignal);

	return;   
}