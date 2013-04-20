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

#define BUF_LEAD	10
#define BUF_LAG		11

#define REC_SPEC	12
#define RECCHA_SEQ	13
#define RECCHB_SEQ	14

#define RECBUF_A1	15
#define RECBUF_B1	16

#define RECBUF_A2	17
#define RECBUF_B2	18

#define DECBUF_A	20
#define DECBUF_B	21

#define SRATE		20.48 /* Fs = 48828 */

#define MAX_FILENAME_LEN	128

#define AD_PTS		50000

#define DEFAULT_PTS 32768 /* 546 ms buffers */

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
} InfoStruct;

/* Final version altered by Andrew on 8/01/2012 */
/*
compile in MATLAB as below
from within this program's home directory:
mex -g play2_record2D.c c:\tdt\S232\VC\S2drv32c.lib
now:
mex -g play2_record2D2_alex2.c c:\kip\code\play_record\play0.c c:\kip\code\play_record\play0_record0.c c:\tdt\S232\VC\S2drv32c.lib

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
	leadSnd LEAD sound													1xbuf_pts single
	scaleVals is the scale for each test (0-30000)						1xn_trials
	lagSnd LAG sound													1xbuf_pts single
	locations is the LAG spkr location for each test (0-3)				1xn_trials

*/


double_buffer( InfoStruct *recInfo, float *leadSnd, float *scaleVals, float *lagSnd, float *locations, int nSignal )
{
FILE	*fptr;
long	seekpos = 0;
float	preloadScale = .2;
int		i;

char	OutFNA [MAX_FILENAME_LEN];
char	OutFNB [MAX_FILENAME_LEN];

float	temp;

int		record = recInfo->record;

unsigned int DEC_FACT = recInfo->decimateFactor;
unsigned int cnt = 1, SignalPlayFlag = 0;
unsigned int signalScale = 0, Signalcnt = 0, readflag = 0;
unsigned int MAX_SIGNAL_JITTER = recInfo->max_signal_jitter;

long	NPTS = recInfo->buf_pts, DEC_PTS = ceil(NPTS / pow(2, DEC_FACT));
long	NPTS_totalplay = recInfo->nptsTotalPlay;
long	templ;

int		src[3];
float	sf[3];

div_t	div_result;

int     loc;


/* Display output variables: */
int     t0,t1, n;
float	elapsed_time;
float	rem_time;
int		min;
float	sec, cntdown;
char	str[100] = { '\0' };
float	pdrBuffer[DEFAULT_PTS];
int		len;
float	xy[2];

srand( (unsigned)time( NULL ) );

/* setup session info display */
mexEvalString("h0=gcf; whitebg(gcf,'k');");
mexEvalString("screen_size = get(0, 'ScreenSize');"); /* get screen size */
mexEvalString("set(h0, 'Position', [0.05*screen_size(3) 0.65*screen_size(4) 0.85*screen_size(3) 0.25*screen_size(4)] );");
mexEvalString("h1 = figure; axis off; whitebg(gcf,'k'); hold on;"); /* session info plot */
mexEvalString("set(h1, 'Position', [0.05*screen_size(3) 0.3*screen_size(4) 0.3*screen_size(3) 0.25*screen_size(4)] );");
mexEvalString("figure(h1); axis off;");
mexEvalString("txt(1) = text(.01,.9,''); txt(2) = text(.01,.7,''); txt(3) = text(.01,.5,''); txt(4) = text(.01,.3,'');");
mexEvalString("h2 = figure; set(h2, 'Position', [0.4*screen_size(3) 0.05*screen_size(4) 0.5*screen_size(3) 0.5*screen_size(4)] );");
len = ceil(NPTS * (SRATE/1E3)); /* for plotting scale */
memset(str,'\0',sizeof(str));
n=sprintf(str,"tmp = zeros(1,round(%f));",DEC_PTS);
mexEvalString(str);

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

// allot and load buffer for LEAD
allotf( BUF_LEAD, NPTS);
pushf(leadSnd, NPTS);
qpopf( BUF_LEAD );

// allot and load buffer for LAG
allotf( BUF_LAG, NPTS);
pushf(lagSnd, NPTS);
qpopf( BUF_LAG );


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

dropall();

/* set LED thresholds */
PD1setIO(1,0.01,9.99,0.01,9.99);

/* setup signal switchers */
SS1clear(1); /* left SS1 (LAG) */
SS1mode(1, QUAD_2_1); /* inputs 1, 3, 5, 7 => outputs A,B,C,D */
SS1select(1,0,1); /* Default Lag Output is A (Hab Location) */

SS1clear(2); /* right SS1 (LEAD) */
SS1mode(2, QUAD_2_1); /* inputs 1, 3, 5, 7 => outputs A,B,C,D */
SS1select(2,0,1); /* always input 1 => output A */

// set attenuation
PA4atten(1,recInfo->latten);
PA4atten(2,recInfo->ratten);

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

	if(signalScale >0)						// ???
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
	if(locations[Signalcnt]==0) {
		for(i=0; i<(recInfo->n_trials - Signalcnt); i++) {
			cntdown += (recInfo->ISI+1)*(NPTS*SRATE/1E6);
			if(locations[Signalcnt+i]>0)
				break;
		}
	}

	/* Display Session Info */
	mexEvalString("figure(h1); delete(txt(1)); delete(txt(2)); delete(txt(3)); axis off;");
	elapsed_time = seekpos*(SRATE/1E6);
	div_result = div( elapsed_time, 60 );
	min = div_result.quot; sec = elapsed_time - (60*min);
	memset(str,'\0',sizeof(str));
	n = sprintf(str,"txt(1) = text(.01,.9,'ELAPSED TIME:    %i minutes   %.2f seconds','FontSize',12);",min,sec);
	mexEvalString(str);
	rem_time = NPTS_totalplay*(SRATE/1E6) - elapsed_time;
	div_result = div( rem_time, 60 );
	min = div_result.quot; sec = rem_time - (60*min);
	memset(str,'\0',sizeof(str));
	n = sprintf(str,"txt(2) = text(.01,.7,'REMAINING TIME:  %i minutes   %.2f seconds','FontSize',12);",min,sec);
	mexEvalString(str);
	div_result = div( cntdown, 60 );
	min	= div_result.quot; sec = cntdown - (60*min);
	memset(str,'\0',sizeof(str));
	n = sprintf(str,"txt(3) = text(.01,.5, 'NEXT TEST TRIAL: %i minutes   %.2f seconds','FontSize',12);",min,sec);
	mexEvalString(str);
	mexEvalString("drawnow;");
	
	// re-loading #1 playbuffers
	// LEAD to chanA LAG to chanB
	dropall();
	if (cnt==recInfo->ISI)
	{
		if (MAX_SIGNAL_JITTER > 0)
		{
			div_result = div( rand (), MAX_SIGNAL_JITTER );
			cnt = div_result.rem;
		} else
		{
			cnt = 0;
		}
		
		loc = locations[Signalcnt];
		
		SS1clear(1); /* left SS1 (LAG) */
        SS1mode(1, QUAD_2_1); /* inputs 1, 3, 5, 7 => outputs A,B,C,D */
		SS1select(1,loc,1); /* Chan B (LAG) location ( speakers A...D = 0...3 ) */
		
		/* plot a marker on trial sequence plot */
		memset(str,'\0',sizeof(str));
		xy[0] = Signalcnt+1; 
		switch(loc) {
		    case 0:
		        xy[1] = 0; /* habituating lag location */
		        break;
		    case 1:
		        xy[1] = -1; /* lag shifts leftward */
		        break;
	        case 2:
	            xy[1] = 1; /* lag shifts rightward */
	            break;
	    }    
		n=sprintf(str,"figure(h0); plot(%.0f,%.0f,'MarkerSize',12,'Marker','s','MarkerFaceColor','none','MarkerEdgeColor','w');",xy[0],xy[1]);
		mexEvalString(str);
		
		signalScale = scaleVals[Signalcnt ++];
		qpushf(BUF_LEAD);
		scale(signalScale);
		qpop16(BUF_A1);	

		qpushf(BUF_LAG);
		scale(signalScale);
		qpop16(BUF_B1);
	}
	else
	{
		signalScale = 0;
		cnt++;
		dpush(NPTS);
		value(0);
		scale(signalScale);
		qpop16(BUF_A1);	

		dpush(NPTS);
		value(0);
		scale(signalScale);
		qpop16(BUF_B1);	
	}

	if(record)
	{		// downloading  #1 recordbuffers
		qpush16 (RECBUF_A1);    
		decimate (DEC_FACT);
		make(0, SignalPlayFlag);
		if(SignalPlayFlag) {
			qdup();
			popf(pdrBuffer);
			mexEvalString("figure(h2);");
			for(i=0; i<DEC_PTS; i++) {
				memset(str,'\0',sizeof(str));
				n=sprintf(str,"tmp(%i) = %.5f;",i+1,pdrBuffer[i]);
				mexEvalString(str);
			}
			memset(str,'\0',sizeof(str));
			n=sprintf(str,"plot((%i/%i):(%i/%i):%i,tmp,'r:'); title('Previous Trial'); xlabel('Time (ms)');",len,DEC_PTS,len,DEC_PTS,len);
			mexEvalString(str);
			mexEvalString("drawnow;");
		}
		qpop16   (DECBUF_A);
		dama2disk16 (DECBUF_A, recInfo->outFN1, 1); 
		qpush16 (RECBUF_B1);
		decimate (DEC_FACT);
		make(0, SignalPlayFlag);
		qpop16   (DECBUF_B);
		dama2disk16 (DECBUF_B, recInfo->outFN2, 1);
		dropall ();
	}

	/* processing time */
	t1 = clock();
	mexEvalString("figure(h1); delete(txt(4)); axis off;");
	memset(str,'\0',sizeof(str));
	n = sprintf(str,"txt(4) = text(.01,.3,'Processing Time: %.3f seconds','FontSize',10);",((float) (t1-t0))/CLOCKS_PER_SEC);
	mexEvalString(str);
	mexEvalString("drawnow;");
	
	seekpos += NPTS;
	if(seekpos < NPTS_totalplay)
	{
		// wait for #2 buffers to finish
		do{}while (playseg(1)==BUF_A2);		// wait for #2 buffers to finish

     	t0 = clock();
     	
		SignalPlayFlag = 0;
	
		if(signalScale >0)						// ???
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
		if(locations[Signalcnt]==0) {
			for(i=0; i<(recInfo->n_trials - Signalcnt); i++) {
				cntdown += (recInfo->ISI+1)*(NPTS*SRATE/1E6);
				if(locations[Signalcnt+i]>0)
					break;
			}
		}
	
		/* Display Session Info */
		mexEvalString("figure(h1); delete(txt(1)); delete(txt(2)); delete(txt(3)); axis off;");
		elapsed_time = seekpos*(SRATE/1E6);
		div_result = div( elapsed_time, 60 );
		min = div_result.quot; sec = elapsed_time - (60*min);
		memset(str,'\0',sizeof(str));
		n = sprintf(str,"txt(1) = text(.01,.9,'ELAPSED TIME:    %i minutes   %.2f seconds','FontSize',12);",min,sec);
		mexEvalString(str);
		rem_time = NPTS_totalplay*(SRATE/1E6) - elapsed_time;
		div_result = div( rem_time, 60 );
		min = div_result.quot; sec = rem_time - (60*min);
		memset(str,'\0',sizeof(str));
		n = sprintf(str,"txt(2) = text(.01,.7,'REMAINING TIME:  %i minutes   %.2f seconds','FontSize',12);",min,sec);
		mexEvalString(str);
		div_result = div( cntdown, 60 );
		min	= div_result.quot; sec = cntdown - (60*min);
		memset(str,'\0',sizeof(str));
		n = sprintf(str,"txt(3) = text(.01,.5,'NEXT TEST TRIAL: %i minutes   %.2f seconds','FontSize',12);",min,sec);
		mexEvalString(str);
		mexEvalString("drawnow;");

		// reload #2 playbuffers    LEAD to chanA LAG to chanB
		dropall();
		if (cnt==recInfo->ISI)
		{
			if (MAX_SIGNAL_JITTER > 0)
			{
				div_result = div( rand (), MAX_SIGNAL_JITTER );
				cnt = div_result.rem;
			} else
			{
				cnt = 0;
			}
			
			loc = locations[Signalcnt];
			SS1clear(1); /* left SS1 (LAG) */
            SS1mode(1, QUAD_2_1); /* inputs 1, 3, 5, 7 => outputs A,B,C,D */
			SS1select(1,loc,1); /* Chan B (LAG) location ( speakers A...D = 0...3 ) */

		    /* plot a marker on trial sequence plot */
			memset(str,'\0',sizeof(str));
			xy[0] = Signalcnt+1; 
			switch(loc) {
			    case 0:
			        xy[1] = 0; /* habituating lag location */
			        break;
			    case 1:
			        xy[1] = -1; /* lag shifts leftward */
			        break;
		        case 2:
		            xy[1] = 1; /* lag shifts rightward */
		            break;
		    }    
			n=sprintf(str,"figure(h0); plot(%.0f,%.0f,'MarkerSize',12,'Marker','s','MarkerFaceColor','none','MarkerEdgeColor','w');",xy[0],xy[1]);
			mexEvalString(str);
			
			signalScale = scaleVals[Signalcnt ++];

			qpushf(BUF_LEAD);
			scale(signalScale);
			qpop16(BUF_A2);
		
			qpushf(BUF_LAG);
			scale(signalScale);
			qpop16(BUF_B2);
		}
		else
		{
			signalScale = 0;
			cnt++;
			dpush(NPTS);
			value(0);
			scale(signalScale);
			qpop16(BUF_A2);

			dpush(NPTS);
			value(0);
			scale(signalScale);
			qpop16(BUF_B2);
		}
		
		if (record)
		{		// download #2 recordbuffers
			qpush16 (RECBUF_A2);    
			decimate (DEC_FACT);
			make(0,SignalPlayFlag);
			if(SignalPlayFlag) {
			    qdup();
			    popf(pdrBuffer);
			    mexEvalString("figure(h2);");
			    for(i=0; i<DEC_PTS; i++) {
				    memset(str,'\0',sizeof(str));
				    n=sprintf(str,"tmp(%i) = %.5f;",i+1,pdrBuffer[i]);
				    mexEvalString(str);
			    }
			    memset(str,'\0',sizeof(str));
			    n=sprintf(str,"plot((%i/%i):(%i/%i):%i,tmp,'r:'); title('Previous Trial'); xlabel('Time (ms)');",len,DEC_PTS,len,DEC_PTS,len);
			    mexEvalString(str);
			    mexEvalString("drawnow;");
		    }
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

	    /* processing time */
	    t1 = clock();
	    mexEvalString("figure(h1); delete(txt(4)); axis off;");
	    memset(str,'\0',sizeof(str));
	    n = sprintf(str,"txt(4) = text(.01,.3,'Processing Time: %.3f seconds','FontSize',10);",((float) (t1-t0))/CLOCKS_PER_SEC);
	    mexEvalString(str);
	    mexEvalString("drawnow;");
		
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

trash();
dropall();

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
	float		*leadSnd, *lagSnd, *scaleVals, *locations;

	div_t div_result;

	InfoStruct recInfo;

    /* Check for proper number of arguments */    
    if (nrhs != 5) 
		mexErrMsgTxt("5 input arguments required)."); 
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

	// leadSnd is the LEAD signal (1 x bufpts)
	if ( mxGetM(prhs[1])!=1 || mxGetN(prhs[1])!= recInfo.buf_pts)
		mexErrMsgTxt("leadSnd must be a 1xbufpts, row vector.");
	leadSnd = (float*) mxGetPr(prhs[1]);

	// scaleVals is a 1 x n (n>=n_trials) array of Scale Factors (0 - 32000)
	nsignal = mxGetN(prhs[2]);
	if ( mxGetM(prhs[2])!=1 || nsignal < recInfo.n_trials)
		mexErrMsgTxt("scaleVals must be a 1 x n (n > n_trials), row vector.");
	scaleVals = (float*) mxGetPr(prhs[2]);


	// lagSnd is the LAG - same size as LEAD (1 x bufpts)
	if ( mxGetM(prhs[3])!=1 || mxGetN(prhs[3])!= recInfo.buf_pts)
		mexErrMsgTxt("lagSnd must be a 1 x bufpts, row vector.");
	lagSnd = (float*) mxGetPr(prhs[3]);

	
	// locations is a 1 x n (n>=n_trials) array of spkr positions to switch between (0-3)
	if ( mxGetM(prhs[4])!=1 || nsignal < recInfo.n_trials)
		mexErrMsgTxt("locations must be a 1 x n (n > n_trials), row vector.");
	locations = (float*) mxGetPr(prhs[4]);
   
    /* The double_buffer subroutine */
	double_buffer( &recInfo, leadSnd, scaleVals, lagSnd, locations, nsignal);

	return;   
}