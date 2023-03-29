<<<<<<< HEAD
## My Project

TODO: Fill this README out!

Be sure to:

* Change the title in this README
* Edit your repository description on GitHub

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

=======
# AWS IoT Greengrass V2 Component to send video over Kinesis Video Streams with WebRTC

Using this project, you can create an [AWS IoT Greengrass V2 (GGv2)](https://docs.aws.amazon.com/greengrass/v2/developerguide/what-is-iot-greengrass.html) Component that will acquire video from a [Video for Linux (v4l)](https://www.kernel.org/doc/html/v4.9/media/uapi/v4l/v4l2.html) device, open an [Amazon Kinesis Video Streams (KVS) with WebRTC](https://docs.aws.amazon.com/kinesisvideostreams-webrtc-dg/latest/devguide/what-is-kvswebrtc.html) signaling channel as 'Master', and when a 'Viewer' connects to that signaling channel, publish the acquired video. This project uses [GStreamer](https://gstreamer.freedesktop.org/) to acquire, process, and encode video. The 'pipeline' and source can easily be changed or customized to suit different video sources, processing, or formats.

The component is packaged as a [Docker](https://www.docker.com/) container to help ensure portability and minimize conflicts with system libraries, packages, and other configurations. **As noted below, take to match the Instruction Set Architecture (ISA)--e.g. x86 or Arm--of the system that builds and packages the container with the target.**

This project targets Linux hosts and was developed using Linux and Mac desktop environments.

This project will guide through

1. Validation of a v4l video source such as a USB camera or capture card
2. Build the Container and test locally on a GGv2 installation
3. Package and publish the GGv2 Component

### Prerequisites

* A working installation of [AWS IoT Greengrass V2](https://docs.aws.amazon.com/greengrass/index.html). If necessary see links to

   - [Install Greengrass V2](https://docs.aws.amazon.com/greengrass/v2/developerguide/getting-started.html)
   - (Optionally) [Validate](https://edgecv.workshop.aws/spells/validate-ggv2.html) your installation
   - and (Optional) learn how to [Deploy](https://edgecv.workshop.aws/spells/deploy-component.html) a Component

* [Install Docker](https://docs.docker.com/engine/install/) on the Greengrass Core. (Optionally) Install Docker on a build machine with compatible ISA.
* an AWS Account, If you don't have one, see [Set up an AWS account](https://docs.aws.amazon.com/greengrass/v2/developerguide/setting-up.html#set-up-aws-account)
* AWS CLI v2 [installed](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) and [configured](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html) with permissions to

   - PUT objects into S3

## Part 1 - Validate Setup, connections, drivers, etc.

This component is built to use a Video for Linux (v4l) device as source. In Part 2, you will build the Docker container with GStreamer and the KVS Application. Device access is provided by passing the specific device to the container in the component recipe. First, validate the device is connected properly and that the `ggc_user` will have access to the device.

1. Verify v4l device

**On the target Greengrass core**, verify the desired v4l device exists

```bash
ls -l /dev/video*
#crw-rw----+ 1 root video 81, 0 Mar  9 08:44 /dev/video0
#crw-rw----+ 1 root video 81, 1 Mar  9 08:44 /dev/video1
```

Your devices may differ in number, etc. Also note the group ownership for your desired device (e.g. `/dev/video0`)--typically `video`.

2. Add the `ggc_user` to the `video` group.

```bash
# change this command if necessary for different group or GGv2 user
sudo usermod -aG video ggc_user
```

3. Verify Docker

**On the target Greengass core**, verify Docker functionality.

```bash
sudo docker run hello-world
# verify the phrase "Hello from Docker!" in the output
```

*(Optional)* Verify Docker on the build machine, if used.

4. Add the `ggc_user` to the docker group.

```bash
# modify the user if your GGv2 installation has a different user account
sudo usermod -aG docker ggc_user
```

## Part 2 - Build the Docker Container and test locally

This guide follows a 'local shadow' development method to [Create Components](https://docs.aws.amazon.com/greengrass/v2/developerguide/create-components.html) where development is done directly on a Greengrass core and then kept in sync with an [Amazon Simple Storage Service (S3)](https://aws.amazon.com/s3/) bucket for later use and deployment. However, as resources (disk space, RAM, CPU) may be more limited on your target core device, the Docker component can be built on a different system **with the same Instruction Set Architecture (ISA)**.

1. Edit Dockerfile

Set the `TZ` variable in the `Dockerfile` as desired for the location of your Greengrass Core--or the desired localization (e.g. UTC). Available localizations can be found in the `/usr/share/zoneinfo/` directory.

```docker
ENV TZ=<your timezone, e.g. America/Los_Angeles>
# ENV TZ=America/Los_Angeles
```

**Save the Dockerfile.**

2. Build the image

```bash
docker build --rm -t <name> .
# example
#docker build --rm -t kvs .
```

3. Test the container

***Testing is optional. If you're happy with the container, you can proceed to package and deploy.***

(Optionally), if you built the image on a different system than your Greengrass core, transfer the image to the target machine.

```bash
# EXAMPLE - OPTIONAL - transfer image to target
IMAGE_NAME=<image-name>
#IMAGE_NAME=kvs
docker save $IMAGE_NAME > $IMAGE_NAME.tar

# transfer the image to the target... 
# for example, using scp
#scp $IMAGE_NAME.tar target:

# ON THE TARGET
docker load -i <image>.tar
```

A customized version of the `kvsWebRTCClientMasterGstreamerSample` was built during the `docker build` and set as the ENTRYPOINT. This application uses the following environment variables:

| variable | usage |
| --- | --- |
| $AWS_ACCESS_KEY_ID | key id for credentials to use KVS |
| $AWS_SECRET_ACCESS_KEY | secret key for key id |
| $AWS_SESSION_TOKEN | (Optional) Session Token if used |
| $AWS_KVS_CACERT_PATH | path to certs -- Dockerfile set this to `/certs` |
| $AWS_KVS_LOG_LEVEL| `3` or other level from README as desired |

For local testing, put these values in a `.env` file and pass it to the container.

```bash
## use values from downloaded credentials
echo "\
AWS_ACCESS_KEY_ID=<your key id>
AWS_SECRET_ACCESS_KEY=<your secret key>
# if using cloud9 or a role, you may also have a session token
#AWS_SESSION_TOKEN=<session token>
AWS_KVS_CACERT_PATH=../certs/cert.pem
AWS_KVS_LOG_LEVEL=3 
" >.env
```

Pass the environment to the docker container

```bash
CHANNEL_NAME=<kvs-webrtc-channel-name>
#CHANNEL_NAME=test
docker run --env-file ./.env --device=/dev/video0 kvs $CHANNEL_NAME
```

## Part 3 - Package and Publish as GGv2 Component

It is common practice when building Greengrass components to maintain a 'shadow' of the artifacts and recipes under user home. This guide continues that practice as it makes some of the preparation convenient. Other workflows are possible.

1. archive the Docker image

```bash
# keeping a local copy of artifacts is generally helpful
mkdir -p ~/GreengrassCore && cd $_

export component_name=<name for your component>
export component_version=<version number>
# example
# export component_name=com.example.kvs_master
# export component_version=1.0.0

# use the name of your docker container created in Part 1
mkdir -p ~/GreengrassCore/artifacts/$component_name/$component_version

export container_name=<name of your container>
# example
# export container_name=kvs

docker save $container_name > ~/GreengrassCore/artifacts/$component_name/$component_version/$container_name.tar
```

2. (Optional) remove the original image and reload

```sh
docker image ls $container_name
# check the output

docker rmi -f $container_name

# recheck images
docker image ls $container_name
# should be empty set

docker load -i ~/GreengrassCore/artifacts/$component_name/$component_version/$container_name.tar

# and the container should now be in the list
docker image ls
```

3. upload script artifacts to S3

```bash
# compress the file first, gzip, xz, and bzip are supporteed by Docker for load
gzip ~/GreengrassCore/artifacts/$component_name/$component_version/$container_name.tar

export bucket_name=<where you want to host your artifacts>
# for example
# export region='us-west-2'
# export acct_num=$(aws sts get-caller-identity --query "Account" --output text)
# export bucket_name=greengrass-component-artifacts-$acct_num-$region

# create the bucket if needed
aws s3 mb s3://$bucket_name

# and copy the artifacts to S3
aws s3 sync ~/GreengrassCore/ s3://$bucket_name/
```

4. create the recipe for the component

```bash
mkdir -p ~/GreengrassCore/recipes/
touch ~/GreengrassCore/recipes/$component_name-$component_version.json

# paste these values
echo $component_name " " $component_version " " $bucket_name

# edit using IDE or other editor
# for example: vim
# vim ~/GreengrassCore/recipes/$component_name-$component_version.json
```

And enter the following content for the recipe, replacing `paste_bucket_name_here` with the name of the bucket you created earlier. Also replace `component-name`, `component-version`, and `container-name`.  **NOTE** you can get the building machine's architecture with `uname -m`. 

If your Greengrass user name is other than `ggc_user` or if the v4l device is owned by a group other than `video`, be sure to modify the `Install` script.

Likewise, if your video device is **NOT** `/dev/video0`, change the `Startup` script to remap your device number to `video0`.

```bash
{
  "RecipeFormatVersion": "2020-01-25",
  "ComponentName": "<component-name>",
  "ComponentVersion": "<component-version>",
  "ComponentDescription": "A component that runs a Docker container to send video from a v4l device to KVS.",
  "ComponentPublisher": "Amazon",
  "ComponentConfiguration": {
      "DefaultConfiguration": {
          "channel": "TestChannel"
      }
  },
  "Manifests": [
    {
      "Platform": {
        "os": "linux",
        "architecture": "<arch_of_machine_building_the_image>"
      },
      "Lifecycle": {
        "Install": {
          "Script": "usermod -aG video ggc_user; docker load -i {artifacts:path}/<container-name>.tar.gz"
        },
        "Startup": {
          "Script": "docker run --device=/dev/video0:/dev/video0 --name=<container-name> kvs {configuration:/channel}"
        },
        "Shutdown": {
          "Script": "docker stop <container-name>"
        }
      },
      "Artifacts": [
        {
          "URI": "s3://<paste_bucket_name_here>/artifacts/<component-name>/<component-version>/<container-name>.tar.gz"
        }
      ]
    }
  ]
}
```

*(Optional)* Validate your changes in the JSON file to avoid an errors in creating the component (commonly reported as missing rights to `null`)

```bash
cat ~/GreengrassCore/recipes/$component_name-$component_version.json | jq
# and fix any errors that may be reported
```

5. create the GG component with

```bash
aws greengrassv2 create-component-version --inline-recipe fileb://~/GreengrassCore/recipes/$component_name-$component_version.json
```

## FINISHED - Next Steps

You have now created a Greengrass V2 Docker component and uploaded it to your AWS Account. Note that when deploying the component, the channel name can be remapped. It is also possible to refactor the recipe to move the video device description to a configurable option.

## Troubleshooting

### To fix a failed deployment:

Go to Deployments in the console and remove the offending component from the deployment (check both thing and group level). Deploy. This will remove the component from the target.

Delete the component definition in the console

Update the artifacts and push to S3

Re-Create the component definition (as this will take a hash from the artifacts). (alternatively, it should be possible to create a new version)

Add the newly, re-created component to the deployment and deploy.

It can be very handy to turn off the Rollback feature on failure to see what was captured/expanded

If you find yourself iterating through the above cycle many times, it may be easier to develop the component locally first and then upload it. See Create custom AWS IoT Greengrass components for information about how to work with components locally on the Greengrass core.

### Verify USB device for capture card

```ini
lsusb -t
# /:  Bus 02.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/7p, 5000M
#    |__ Port 4: Dev 2, If 0, Class=Video, Driver=uvcvideo, 5000M
#    |__ Port 4: Dev 2, If 1, Class=Video, Driver=uvcvideo, 5000M
#    |__ Port 4: Dev 2, If 2, Class=Audio, Driver=snd-usb-audio, 5000M
#    |__ Port 4: Dev 2, If 3, Class=Audio, Driver=snd-usb-audio, 5000M
# /:  Bus 01.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/8p, 480M
#    |__ Port 1: Dev 2, If 1, Class=Human Interface Device, Driver=usbhid, 1.5M
#    |__ Port 1: Dev 2, If 0, Class=Human Interface Device, Driver=usbhid, 1.5M
#    |__ Port 5: Dev 3, If 0, Class=Audio, Driver=snd-usb-audio, 12M
#    |__ Port 5: Dev 3, If 1, Class=Audio, Driver=snd-usb-audio, 12M
#    |__ Port 5: Dev 3, If 2, Class=Audio, Driver=snd-usb-audio, 12M
#    |__ Port 5: Dev 3, If 3, Class=Human Interface Device, Driver=usbhid, 12M
#    |__ Port 6: Dev 4, If 0, Class=Wireless, Driver=btusb, 12M
#    |__ Port 6: Dev 4, If 1, Class=Wireless, Driver=btusb, 12M
```

*NOTE* the capture card is found on `Bus 02.Port 1` which happens to be the 'side' USB connector on the Beelink.  Two Video and Two audio interfaces is normal and correct. Your devices may be different. As long as we have TWO Video and TWO Audio devices enumerated AND they are bound to the port where the device is connected, the device connection can be considered correct.

If using a non-USB device, validate connectivity as appropriate.

### Verify V4L2 mapping and function

```sh
ls -l /dev/v4l/by-path/
# lrwxrwxrwx 1 root root 12 Aug 12 09:42 pci-0000:00:15.0-usb-0:4:1.0-video-index0 -> ../../video0
# lrwxrwxrwx 1 root root 12 Aug 12 09:42 pci-0000:00:15.0-usb-0:4:1.0-video-index1 -> ../../video1
```

and, yes... two video capture devices matching the USB devices. If you have additional devices, they may be listed here as well.  Do take note of the symbolic link for the device you wish to use (`/dev/video0` in this guide). Verify that the path (e.g. `pci-0000:00:15.0-usb-0:4:1.0-video-index0` is correct for the physical connection of your device).

Now check the video device binding

```sh
ls -l /dev/video*
# crw-rw----+ 1 root video 81, 0 Aug 12 09:42 /dev/video0
# crw-rw----+ 1 root video 81, 1 Aug 12 09:42 /dev/video1
```

install v4l2 if needed

```sh
sudo apt install v4l-utils
```

check that v4l2 got the device binding

```sh
v4l2-ctl --list-devices
Failed to open /dev/video0: Permission denied
```

**and FAIL** need to add the user to the `video` group

```sh
sudo usermod -aG video $USER
```

**need to reload the shell to access the new group**

and now we see the devices

```sh
v4l2-ctl --list-devices
# UVC Camera (1e4e:7016) (usb-0000:00:15.0-4):
#        /dev/video0
#        /dev/video1
#        /dev/media0
```

### Check the device capabilities

```yaml
v4l2-ctl --device=/dev/video0 --all
# Driver Info:
#        Driver name      : uvcvideo
#        Card type        : UVC Camera (1e4e:7016)
#        Bus info         : usb-0000:00:15.0-4
#        Driver version   : 5.15.39
#        Capabilities     : 0x84a00001
#                Video Capture
#                Metadata Capture
#                Streaming
#               Extended Pix Format
#                Device Capabilities
#        Device Caps      : 0x04200001
#                Video Capture
#                Streaming
#                Extended Pix Format
# Media Driver Info:
#        Driver name      : uvcvideo
#        Model            : UVC Camera (1e4e:7016)
#        Serial           : 20000130041415
#        Bus info         : usb-0000:00:15.0-4
#        Media version    : 5.15.39
#        Hardware revision: 0x00000100 (256)
#        Driver version   : 5.15.39
# Interface Info:
#        ID               : 0x03000002
#        Type             : V4L Video
# Entity Info:
#        ID               : 0x00000001 (1)
#        Name             : UVC Camera (1e4e:7016)
#        Function         : V4L2 I/O
#        Flags         : default
#        Pad 0x01000007   : 0: Sink
#          Link 0x02000010: from remote pad 0x100000a of entity 'Extension 4': Data, Enabled, Immutable
# Priority: 2
# Video input : 0 (Camera 1: ok)
# Format Video Capture:
#        Width/Height      : 1920/1080
#        Pixel Format      : 'YUYV' (YUYV 4:2:2)
#        Field             : None
#        Bytes per Line    : 3840
#        Size Image        : 4147200
#        Colorspace        : sRGB
#        Transfer Function : Rec. 709
#        YCbCr/HSV Encoding: ITU-R 601
#        Quantization      : Default (maps to Limited Range)
#        Flags             : 
# Crop Capability Video Capture:
#        Bounds      : Left 0, Top 0, Width 1920, Height 1080
#        Default     : Left 0, Top 0, Width 1920, Height 1080
#        Pixel Aspect: 1/1
# Selection Video Capture: crop_default, Left 0, Top 0, Width 1920, Height 1080, Flags: 
# Selection Video Capture: crop_bounds, Left 0, Top 0, Width 1920, Height 1080, Flags: 
# Streaming Parameters Video Capture:
#        Capabilities     : timeperframe
#        Frames per second: 30.000 (30/1)
#        Read buffers     : 0
```

Check formats

```yaml
v4l2-ctl --list-formats-ext --device /dev/video0
# ioctl: VIDIOC_ENUM_FMT
#        Type: Video Capture
#
#        [0]: 'MJPG' (Motion-JPEG, compressed)
#                Size: Discrete 1920x1080
#                        Interval: Discrete 0.017s (60.000 fps)
#        [1]: 'YUYV' (YUYV 4:2:2)
#                Size: Discrete 1920x1080
#                        Interval: Discrete 0.017s (60.000 fps)
```

### Grab a test frame

```sh
v4l2-ctl --device /dev/video0 --set-fmt-video=width=1920,height=1080,pixelformat=MJPG --stream-mmap --stream-to=/tmp/output.jpg --stream-count=1
# <     # this '<' is the normal output

# verify grab -- size and date/time
ls -l /tmp/output.jpg
# -rw-rw-r-- 1 scott scott 41288 Aug 12 10:17 /tmp/output.jpg
```

Let's look at it!

Convert from MJPG to something viewable...

May need to install `ffmpeg`

```sh
sudo apt install ffmpeg -y
```

convert

```sh
ffmpeg -i /tmp/output.jpg -bsf:v mjpeg2jpeg frame.jpg
```

open/transfer/view `frame.jpg`

### Mount the target core remotely with `sshfs`

```sh
mkdir target
sshfs <user>@<ip>: target
# unmount with umount
```

now you can browse that jpg file remotely...
Does it look okay?

If evaluating a new camera and need to check format compatibility -- `ffmpeg` has a mapping of `v4l2` modes.

```sh
# check output format compatability
ffmpeg -f video4linux2 -list_formats all -i /dev/video0
# ...
# [video4linux2,v4l2 @ 0x557afa242680] Compressed:       mjpeg :          Motion-JPEG : 1920x1080
# [video4linux2,v4l2 @ 0x557afa242680] Raw       :     yuyv422 :           YUYV 4:2:2 : 1920x1080
#
```

There will likely be a lot of other output, but we are interested in the format lines as shown above. **The customized pipelines in this guide use the `MJPG` format.** It may be possible to use `YUYV` as well as other formats, but those were not tested and would need some modifications to the gStreamer pipelines.

```sh
v4l2-ctl --device /dev/video0 --set-fmt-video=width=1920,height=1080,pixelformat=YU12 --stream-mmap --stream-to=/tmp/output.yuv --stream-count=1
# <
```

*Installing the YUV viewer extension to VS Code be helpful here if experimenting with non-MJPG formats.*

### All-In-One Test

This GStreamer pipeline will fetch audio and video and write an MPEG-4 file.  If the MP4 file is accurate, all video and audio devices are configured and functioning properly.

```bash
gst-launch-1.0  -e  \
  v4l2src device=/dev/video0 ! queue ! jpegdec ! \
  videoscale ! video/x-raw,width=1280,height=720 ! \
  videorate ! video/x-raw,framerate=30/1 ! \
  videoconvert ! x264enc bframes=0 speed-preset=veryfast bitrate=512 \
    byte-stream=TRUE tune=zerolatency ! \
  mux. alsasrc device=hw:1 ! queue ! audioconvert ! audioresample ! \
  voaacenc ! aacparse ! qtmux name=mux ! \
  filesink location=test.mp4 sync=false
```

### Testing and Troubleshooting Audio

Audio is handled by ALSA. You may need to customize the pipeline above and in the code as described below to reference the correct v4l and ALSA devices.

Available audio devices can be shown with

```bash
arecord -l
#**** List of CAPTURE Hardware Devices ****
#card 0: U0x1e4e0x7016 [USB Device 0x1e4e:0x7016], device 0: USB Audio #[USB Audio]
#  Subdevices: 1/1
#  Subdevice #0: subdevice #0
#card 1: KTUSBAUDIO [KT_USB_AUDIO], device 0: USB Audio [USB Audio]
#  Subdevices: 1/1
#  Subdevice #0: subdevice #0
```

If you get a permissions error in executing `arecord`, you may need to add the current user to the `audio` group.

```bash
sudo usermod -aG audio $USER
```

In the above example, note that `card 0` is referenced as a USB device with the Manufacturer and Device IDs (0x14e:0x7016).  This can be matched with the expected device.

```bash
lsusb
#Bus 002 Device 002: ID 1e4e:7016 Cubeternet
#...
```

For the `alsasrc` GStreamer plugin, this card is referenced as `hw:0`. This command will capture raw audio and can be used to test.

```bash
arecord -f S16_LE -D hw:0 -c 2 -r 48000 ~/rec0.wav
```

Note the setting of the format `S16_LE` along with 2 channels, `-c 2`, and sample rate, `-r 48000`. This information can be found in the `/proc/asound` tree.

```bash
cd /proc/asound

cat cards
# 0 [U0x1e4e0x7016  ]: USB-Audio - USB Device 0x1e4e:0x7016
#                      USB Device 0x1e4e:0x7016 at usb-0000:00:15.0-3,super speed
# 1 [KTUSBAUDIO     ]: USB-Audio - KT_USB_AUDIO
#                      KTMicro KT_USB_AUDIO at usb-0000:00:15.0-5, full speed
# 2 [PCH            ]: HDA-Intel - HDA Intel PCH
#                      HDA Intel PCH at 0x91310000 irq 130

cat card0/stream0
#USB Device 0x1e4e:0x7016 at usb-0000:00:15.0-3, super speed : USB Audio
#
#Capture:
#  Status: Stop
#  Interface 3
#    Altset 1
#    Format: S16_LE
#    Channels: 2
#    Endpoint: 0x8a (10 IN) (ASYNC)
#    Rates: 48000
#    Data packet interval: 1000 us
#    Bits: 16
#    Channel map: FL FR
```

### Testing WebRTC

Open the [WebRTC Test Page](https://awslabs.github.io/amazon-kinesis-video-streams-webrtc-sdk-js/examples/index.html), paste in `Access Key Id`, `Secret Access Key`, and `CHANNEL_NAME`, then **Start Viewer**.
>>>>>>> 4478e1d (initial commit)
