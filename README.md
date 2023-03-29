# iRecTests

The iRec uses TCP and UDP. TCP sends commands to start and stop streaming online data that is returned as lines of text via TCP. You can read all the data in the buffer then process lines, but for online you are usually only interested in the latest sample, so can throw everything but the last few lines (you can smooth the data if you have several samples). UDP is used to send fast markers to be saved with the data. TCP data is 8bit byte strings, USP is 32bit signed integers (int32).

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
eT = irecManager();

eT.useOperatorScreen = true; % need 2 displays it will show current eye position on experimenter machine
eT.isdummy = false; % if set to true you can use the mouse as a fake iRec, useful for debugging...

open(sM);
initialise(eT, sM);
trackerSetup(eT); % calibration and validation

eT.fixation.X = 0;
eT.fixation.Y = 0;

startRecording(eT); % start our online data stream
trackerMessage(eT, 1);
for i = 1 : sM.screenVals.fps*5
    drawCross(sM); % draw a cross (center is default);
    getSample(eT); % get the latest eye position sample

    fprintf('X = %.2f | Y = %.2f | Pupil = %.2f\n', eT.X, eT.Y, eT.pupil);

    inWindow = isFixated(eT); % check if we are inside the fixation window
    if inWindow
        drawDotsDegs(sM, [eT.X;eT.Y], 0.6, [0 1 0]); % draw a green eye position dot
    else
        drawDotsDegs(sM, [eT.X;eT.Y], 0.4, [0.5 0.5 0]); % draw a yellow eye position dot
    end

    flip(sM); % flip the screen
end
trackerMessage(eT, -1);
stopRecording(eT); % stop the online data stream

close(eT);
close(sM);
```

Note you can change the location that the data is saved by setting an environment variable: `IRECHS2STORE=C:\Users\ME\DATAFOLDER`

Please see [iRecTest1.m](https://github.com/iandol/iRecTests/blob/main/iRecTest1.m) in this folder for runnable example.

## Some useful functions

- `startRecording` / `stopRecording` -- to start/stop online data access
- `getSample` -- get the latest sample and store the data to X, Y and Pupil values. It uses `smoothing` parameters.
- `runDemo` -- run a demo of the full experiment loop to test everything is working
- `isFixated` -- check if the eye is within any fixation window, it also returns the time inside the window and which window it is.
- `testSearchHoldFixation('good','break')` -- this manages the whole process of a subject moving their eye (searching) into the fixation window, then checking the subject is fixated for a given amount of time. While searching this function returns the string `searching`; if the subject breaks fixation the second string `break` is returned; if the subject is succesful then the first string `good` is returned. In opticka this is used to control the state machine to jump between states, but you can use in user code to simplify this common procedure.


