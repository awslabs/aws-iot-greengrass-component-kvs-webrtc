FROM ubuntu:20.04
ENV TZ=<your timezone, e.g. America/Los_Angeles>
# ENV TZ=America/Los_Angeles
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

#
# Package setup
#
#	Main GStreamer packages
RUN apt-get -y update && apt-get install -y \
    libgstreamer1.0-0  \
	gstreamer1.0-plugins-base \
	gstreamer1.0-plugins-good \
	gstreamer1.0-plugins-bad \
	gstreamer1.0-plugins-ugly \
	gstreamer1.0-libav \
	gstreamer1.0-doc \
	gstreamer1.0-tools \
	gstreamer1.0-x \
	gstreamer1.0-alsa \
	gstreamer1.0-gl \
	gstreamer1.0-gtk3 \
	gstreamer1.0-qt5 \
	gstreamer1.0-pulseaudio \
# Additional utilities to work with streams and sources \
	v4l-utils \
	ffmpeg \
	usbutils \
# Packages to build KPL
	pkg-config cmake m4 git \
	libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    libgstreamer-plugins-bad1.0-dev \
# dev utilities
	# vim \
# Utilities to work with KPL samples and AWS
    awscli wget && \
# and finalize...
	apt-get clean && apt-get autoremove && rm -rf /var/lib/apt/lists/*

# 
# build the KVS WebRTC with GStreamer sample
#
### TODO: Patch the sample source
WORKDIR /usr/src
COPY patches patches/
RUN git clone -b v1.7.3 --recursive \
 		https://github.com/awslabs/amazon-kinesis-video-streams-webrtc-sdk-c.git && \
	cd amazon-kinesis-video-streams-webrtc-sdk-c && \
	git apply --whitespace=nowarn ../patches/kvsWebRTCClientMasterGstreamerSample.c.patch && \
	mkdir -p build && cd build && \
	cmake .. && make && \
	cp samples/kvsWebrtcClientMasterGstSample /usr/local/bin/kvsWebrtClientMasterGst
# Download the root CA to /certs
RUN mkdir -p /certs && \
	wget https://www.amazontrust.com/repository/AmazonRootCA1.pem \
		-O /certs/AmazonRootCA1.pem

#
# Main entry to run a GStreamer pipeline
#
ENTRYPOINT [ "/usr/local/bin/kvsWebrtClientMasterGst" ]

# dummy pipeline to make sure GStreamer is installed and funtional
CMD [ "MyScaryTestChannel" ]
