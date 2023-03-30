% you need to install opticka first
assert(exist('addOptickaToPath','file'),'Please install opticka first');

%% I use object-oriented programming design, so most experiment items are classes
% that we instantiate into an object. In this case we instantiate iRecManager to
% an object called 'e'. e stores properties and methods you can use to interface
% with the iRec.
e = iRecManager();
e.useOperatorScreen = true; % a control screen for experimenter, you need 2 displays for this
e.isDummy = false;

%% iRec uses TCP+UDP for interaction
e.calibration.tcpport = 35001;
e.calibration.udpport = 35000;

%% we set up the calibration positions on the screen. iRec uses visual degrees
% which is tha same as opticka, so we can easily transfer the same values
% between them:
e.calibration.calPositions = [-15 0; 0 -15; 0 0; 0 15; 15 0];
e.calibration.valPositions = [-15 0; 0 -15; 0 0; 0 15; 15 0];

%% we can set one or more fixation windows
e.fixation.x = 0;
e.fixation.y = 0;
e.fixation.initTime = 3;
e.fixation.fixTime = 0.5;
e.fixation.radius = 5;

%% screenManager is a class to manage PTB's Screen() function. Almost all the
% possible screen functions are available and all wrapped into the 'sM' object
sM = screenManager('distance',57.3);

%% If using Windows, we must disable the PTB sync timing tests as these often
% fail. If you need precise timing you should run the display code on Linux, and
% only use Windows for running the iReCHS2 software
if IsWin; sM.disableSyncTests = true; end 

%% run the open method on sM [our screenManager]. You can also use sM.open();
open(sM); 

%% create generic RDS stimulus
dots = dotsStimulus('size',10,'coherence',0.5,'mask',true);

%% each stimulus class must be setup using our screenManager object, sM.
setup(dots, sM); %setup our stimulus using our screen

%% we also initialise the eyetracker with screenManager
initialise(e, sM); % initialise the eyetracker

%% run calibration and validation
trackerSetup(e);

%% send the startrecording signal 'start' via TCP port
startRecording(e);

for thisTrial = 1:5
	% clear the operator screen
	trackerClearScreen(e);
	trackerFlip(e,0,true);

	% send a trial start value
	trackerMessage(e, thisTrial);

	vbl = flip(sM); tStart = vbl;
	while vbl < tStart + 10
	
		% draw our RDS stimulus and animate it for the next frame
		draw(dots);
		animate(dots);
	
		% get latest eyetracker sample
		getSample(e);
		e.currentSample; % this is the raw data
		e.x; % this is the latest X position in degrees
		e.y; % this is the latest Y position in degrees
		e.pupil;  % this is the pupil size

		% check fixation window
		[inWindow, fixTime] = isFixated(e); % check if we are inside the fixation window

    	t = sprintf('TRIAL %i | X = %2.2f | Y = %2.2f | Pupil = %2.2f | Fix: %i | FixTime: %2.2f\n', thisTrial, e.x, e.y, e.pupil, inWindow, fixTime);

		% draw eye info on subject display
		drawEyePosition(e);
		drawText(sM, t);
		
		% draw some info on the operator screen
		trackerDrawFixation(e);
		trackerDrawEyePosition(e); %draw eye position on operator screen

		vbl = flip(sM);
		trackerFlip(e);
	
	end
	trackerMessage(e, -1); % send a udp message at end of trial
	flip(sM);
	trackerFlip(e,0,true;)
	WaitSecs(1);
end

flip(sM);
stopRecording(e);

WaitSecs(2);

close(e);
close(sM);
reset(dots);
