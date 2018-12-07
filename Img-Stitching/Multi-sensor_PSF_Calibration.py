import picamera
import time
import os
from fractions import Fraction
import RPi.GPIO as gp

#Set GPIO pins
gp.setwarnings(False)
gp.setmode(gp.BOARD)

# SETUP GPIO OUTPUT CHANNELS
gp.setup(7, gp.OUT)
gp.setup(11, gp.OUT)
gp.setup(12, gp.OUT)
gp.setup(15, gp.OUT)
gp.setup(16, gp.OUT)
gp.setup(21, gp.OUT)
gp.setup(22, gp.OUT)

# SET GPIO OUTPUT CHANNEL STATES
gp.output(11, True)
gp.output(12, True)
gp.output(15, True)
gp.output(16, True)
gp.output(21, True)
gp.output(22, True)

def setCam(char):
    if char == 'C':       
        # Set Cam C
        gp.output(7, True)
        gp.output(11, True)
        gp.output(12, False)

    elif char == 'A':
        # Set Cam A
        gp.output(7, False)
        gp.output(11, False)
        gp.output(12, True)

    elif char == 'B':
        # Set Cam B
        gp.output(7, True)
        gp.output(11, False)
        gp.output(12, True)
    
    else:
        # Set Cam D
        gp.output(7, False)
        gp.output(11, True)
        gp.output(12, False)
        
    

# Parameters that can be tuned
RES = (1000, 1000)
FPS = 10
ISO = 200
camSelect = 'D'
saveFolder = "/home/pi/Documents/Multi-Sensor DiffuserCam/stitchImgs_Cam" + camSelect + "/"
if not os.path.isdir(saveFolder):
    os.makedirs(saveFolder)

# Set camera object and settings
with picamera.PiCamera() as camera:
    setCam(camSelect)
    camera.exposure_mode = "off"
    camera.resolution = RES
    camera.framerate = FPS
    camera.iso = ISO
    camera.saturation = -100
    print("Exposure adjustments in progress. Camera will sleep for 2 seconds...")
    camera.shutter_speed = 2000
    # prev val for pinhole was 6000??
    #camera.start_recording(output = 'testvid.h264')
    #time.sleep(5)
    #camera.stop_recording()
    time.sleep(5)
    camera.start_preview(alpha=255, fullscreen=False,window=(0,0,500,500))
    
    i=1
    var = ''
    while True:
        var = input(" Press 'Enter' to capture next image.\n Press 'x' to terminate imaging session: ")
        if var == 'x':
            break
        elif var == '':
            time.sleep(1)
            saveDir = saveFolder + "img%s.png" % i
            camera.capture(saveDir)
            print("Image%s captured" % i)
            i = i + 1
           
    camera.stop_preview()

