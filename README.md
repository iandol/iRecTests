> [!NOTE]
> Dr. Matsuda just released some new variants of iRecHS2. These support the SpinnakerSDK and there will be an MRI compatible camera SDK too. At present only the source has been released. The notes below apply to the FlyCapture SDK version of iRecHS2. But having the source released is a great step forwards.

# iRecTests

* The English links and software is here: https://staff.aist.go.jp/k.matsuda/iRecHS2/index_e.html. 
* The original paper is here: https://link.springer.com/chapter/10.1007/978-3-319-58071-5_45 
* There is little English documentation so we [google-translated the Japanese manuals downloadable here](https://github.com/iandol/iRecTests/tree/main/Documents).

The iRecHS2 is a low-cost and high-data-quality eyetracker that utilises FLIR machine vision cameras (e.g. the ~500Hz Chameleon3 CM3-U3-13Y3M is ~$300). The software developed by Dr. Keiji Matsuda has a Windows 10/11 GUI interface using TCP and UDP for communication with other experimental software. TCP sends commands to start and stop streaming online data that is returned as lines of text via TCP. You can read all the data in the buffer then process lines, but for online you are usually only interested in the latest sample, so can throw everything but the last few lines (you can smooth the data if you have several samples). UDP is used to send fast markers to be saved with the data. TCP data is 8bit byte strings, UDP is 32bit signed integers (int32).

There is a some Psychopy sample code, but for PTB it isn't too difficult to set up. We use our full experiment framework opticka which has a manager that interfaces with the iRecHS2 to handle calibration, validation, drift correction and managing the use of fixation windows, screen exclusion zones, initiation timers to stop cheating and several other features...

# Materials

We chose the lens based on our requirements for distance-to-subject, the focal length can be changed to optimise for your setup.

| iRec setup list | Manufacturer Details                                                                                  | Model Type      | Source                       | Price (¥) |
|-----------------|-------------------------------------------------------------------------------------------------------|-----------------|------------------------------|-----------|
| Camera          | FLIR https://www.flir.com/products/chameleon3-usb3/?model=CM3-U3-13Y3M-CS                             | CM3-U3-13Y3M-CS | 苏州晟吉川自动化设备有限公司 | 3500      |
| Lens            | Fuji                                                                                                  | HF12.5HA-1S     | 铨识自动化科技上海有限公司   | 720       |
| Filter          | /                                                                                                     | LQA-850-25.5    | 铨识自动化科技上海有限公司   | 230       |
| IR              | Taobao：https://item.taobao.com/item.htm?spm=a1z09.2.0.0.6e712e8dYTbmGW&id=26584916220&_u=n267464ad19 |                 |                              | 25        |
| Adapter         | CS to C lens                                                                                          | CS to C         | 铨识自动化科技上海有限公司   | /         |

## Install Opticka

iRecHS2 is Windows-only software so the instructions are for Windows, but as recommended by the lead PTB programmer it would be better to run Opticka/PTB on a seperate system (that is what we do), as Linux is much better than Windows for precise stimulus timing...

First get a copy of the opticka toolbox. I use `git` for this so you should have it installed first, also for Windows I install `msys2` to have POSIX commands and `bash` available but you can use Powershell if you are more comfortable with this.

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
sM = screenManager(); % this is a full manager for PTB's screen command
e = iRecManager(); % our eyetracker manager

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

## Dual eyetrackers

We found that as long as we use different UDP ports and start iRecHS2 software with different `IRECHS2STORE` variables, we can run and calibrate TWO eyetrackers on the same system. This is really great for social cognition tasks!

# Analysis

I modified my `eyelinkAnalysis` class to make a `iRecAnalysis` class. This allows you to load up and parse the CSV data produced by the iRec. We use the UDP messages where a value > 0 is the trial number and start time, a 0 is the trial end, and negative integers can be commands with various meanings. My code parses microosaccades using Engbert & Mergenthaler 2006 algorithm, but I've also added https://github.com/dcnieho/NystromHolmqvist2010 analysis for the data which does more data cleaning/filtering before it applies routines for saccades, glissades, blinks and fixations. This is fairly easy to use:

```matlab
i = iRecManager; % this asks for a CSV filename
i.parse; % this loads and parses the CSV file into trials
i.plot(1:10) % plot first 10 trials
i.plotNH(10); % plot NystromHolmqvist2010 results
i.explore; % plot the two results side-by-side and scroll through trial to trial
```

The raw CSV data is stored here:

```matlab
i.raw
i.markers
```

The processed data is stored in i.trials which is a X length structure, e.g. the 25th trial has been parsed as:

```matlab
>> i.trials(25)
ans = 
  struct with fields:

               variable: 25
    variableMessageName: []
                    idx: 25
         correctedIndex: 25
                   time: []
                     rt: 0
             rtoverride: 0
              fixations: []
                   nfix: []
               saccades: []
                  nsacc: []
           saccadeTimes: []
           firstSaccade: NaN
                   uuid: []
                 result: []
                invalid: 0
                correct: 1
               breakFix: 0
              incorrect: 0
                unknown: 0
               messages: []
                 sttime: 5.197832750000000e+02
                 entime: 5.227698470000000e+02
              totaltime: 0
        startsampletime: 5.187832750000000e+02
          endsampletime: 5.217832750000000e+02
              timeRange: [-0.999328999999989 1.999232000000006]
            rtstarttime: 5.197832750000000e+02
         rtstarttimeOLD: NaN
              rtendtime: 5.227698470000000e+02
               synctime: 5.197832750000000e+02
                 deltaT: 2.986572000000024
                 rttime: NaN
                  times: [1541×1 double]
                     gx: [1541×1 double]
                     gy: [1541×1 double]
                     hx: []
                     hy: []
                     pa: [1541×1 double]
                  msacc: [1×33 struct]
         sampleSaccades: [-0.997380000000021 -0.979857000000038 -0.966228000000001 … ]
          microSaccades: [-0.800722999999948 -0.654688999999962 -0.576803000000041 … ]
                 radius: [38.263537240345663 62.553389704134901]
                 pratio: [1541×1 double]
                  blink: [1541×1 double]
                  isTOI: 0
                   data: [1×1 struct]
```

Useful fields: `times` `gx` `gy` `pa` are x y and pupil data with a trial based time. `msacc` is the [micro]saccade structure. `data` is the results of NystromHolmqvist2010 for that trial.

