# iRecTests

See https://staff.aist.go.jp/k.matsuda/iRecHS2/index_e.html for the latest software version. The original paper is here: https://link.springer.com/chapter/10.1007/978-3-319-58071-5_45

The iRecHS2 is a low-cost and high-data-quality eyetracker that utilises FLIR machine vision cameras (e.g. the ~500Hz Chameleon3 CM3-U3-13Y3M is ~$300). The software developed by Dr. Keiji Matsuda has a Windows 10/11 GUI interface using TCP and UDP for communication with other experimental software. TCP sends commands to start and stop streaming online data that is returned as lines of text via TCP. You can read all the data in the buffer then process lines, but for online you are usually only interested in the latest sample, so can throw everything but the last few lines (you can smooth the data if you have several samples). UDP is used to send fast markers to be saved with the data. TCP data is 8bit byte strings, USP is 32bit signed integers (int32).

There is a some Psychopy sample code, but for PTB it isn't too difficult to set up. We use our experiment framework opticka which has a manager that interfaces with the iRecHS2 to handle calibration, validation, drift correction and managing the use of fixation windows etc.

## Install Opticka

iRecHS2 is Windows-only software so the instructions are for Windows, but it would be much better to run Opticka/PTB on a seperate system (that is what we do), and Linux is much better than Windows for PTB with precise stimulus timing...

First get a copy of the opticka toolbox. I use `git` for this so you should have it installed, also for Windows I install `msys2` so we have POSIX commands and bash available but you can use Powershell if you are more comfortable with this.

```shell transcript
> mkdir C:\Code
> cd C:\Code
> git clone https://github.com/iandol/opticka
```

Then in MATLAB:

```matlab
cd 'C:\Code\opticka'
addOptickatoPath
```

To learn more about opticka, see https://iandol.github.io/opticka/ and class documentation is here: http://iandol.github.io/OptickaDocs/inherits.html 

## Notes

As I already have a comprehensive manager for both Eyelink and Tobii eyetrackers, I use the same core interface for the iRec. In general this means using class objects that contain their data and functions. So for example in this pseudocode:

```matlab
sM = screenManager();
e = iRecManager();

e.useOperatorScreen = true; % need 2 displays it will show current eye position on experimenter machine
e.isdummy = false; % if set to true you can use the mouse as a fake iRec, useful for debugging...

open(sM);
initialise(e, sM);
trackerSetup(e); % calibration and validation

e.fixation.X = 0;
e.fixation.Y = 0;

startRecording(e); % start our online data stream
trackerMessage(e, 1);
for i = 1 : sM.screenVals.fps*5
    drawCross(sM); % draw a cross (center is default);
    getSample(e); % get the latest eye position sample
    [inWindow, fixTime] = isFixated(e); % check if we are inside the fixation window

    t = sprintf('X = %.2f | Y = %.2f | Pupil = %.2f | Fix: %i | FixTime: %.2f\n', e.x, e.y, e.pupil, inWindow, fixTime);
    
    drawEyePosition(e);
    drawtext(sM, t);
    trackerdraweyePosition(e);

    flip(sM); % flip the subject screen
    trackerFlip(e); % flip the operator screen
end
trackerMessage(e, -1);
stopRecording(e); % stop the online data stream

close(e);
close(sM);
```

Note you can change the location that the data is saved by setting an environment variable: `IRECHS2STORE=C:\Users\ME\DATAFOLDER`

Please see [iRecTest1.m](https://github.com/iandol/iRecTests/blob/main/iRecTest1.m) in this folder for runnable example.

## Some useful functions in `iRecManager`

- `startRecording` / `stopRecording` -- to start/stop online data access
- `getSample` -- get the latest sample and store the data to X, Y and Pupil values. It uses `smoothing` parameters.
- `runDemo` -- run a demo of the full experiment loop to test everything is working
- `isFixated` -- check if the eye is within any fixation window, it also returns the time inside the window and which window it is.
- `testSearchHoldFixation('good','break')` -- this manages the whole process of a subject moving their eye (searching) into the fixation window, then checking the subject is fixated for a given amount of time. While searching this function returns the string `searching`; if the subject breaks fixation the second string `break` is returned; if the subject is succesful then the first string `good` is returned. In opticka this is used to control the state machine to jump between states, but you can use in user code to simplify this common procedure.


