#!/bin/bash

#
# This script should run on startup.
# Output images are 640x480
#
# Add to crontab: `source <(curl -s https://raw.githubusercontent.com/bobvanluijt/gan-movie/master/downloadVideos.sh)`
#
# It assumes that;
# 1. gcsfuse is installed
# 2. All is in europe-west1-b
# 3. There is a bucket called: gan-project-results
# 4. unzip is installed
# 5. csvtool is installed
# 6. youtube-dl is installed
# 7. ffmpeg is installed
# 8. imagemagick is installed
#
# apt-get install unzip csvtool youtube-dl ffmpeg imagemagick
#

# Category to download (https://research.google.com/youtube8m/explore.html)
CATDOWNLOAD=$(curl https://raw.githubusercontent.com/bobvanluijt/gan-movie/master/group.download) # <-- always change in git

echo "Download all from category: $CATDOWNLOAD"

## Create and mount disk
mkdir -p gan-project-results
gcsfuse --implicit-dirs gan-project-results ./gan-project-results &>/dev/null

## Download files from Github
rm -f vocabulary.csv
rm -f youtube-labels.csv
wget --quiet https://github.com/bobvanluijt/gan-movie/blob/master/vocabulary.csv?raw=true -O vocabulary.csv
wget --quiet https://github.com/bobvanluijt/gan-movie/blob/master/youtube-labels.csv.zip?raw=true -O youtube-labels.csv.zip
unzip youtube-labels.csv.zip &>/dev/null && rm -f youtube-labels.csv.zip && rm -rf __MACOSX/

# shuffle to get random line per machine
shuf -o youtube-labels.csv youtube-labels.csv

# Random sleep because of multiple machines running
sleep $[ ( $RANDOM % 100 )  + 1 ]s

# Get a random ID which is not downloaded yet
while IFS='' read -r line || [[ -n "$line" ]]; do
    # Check of the line has the wanted command
    if echo "$line" | grep --quiet ,$CATDOWNLOAD,; then
        # get the video id
        VIDEOID=$(echo "$line" | csvtool -t ',' col "1" -)
        # Check if the video isn't already being downloaded
        if [ ! -f "./gan-project-results/vids/$VIDEOID.mp4" ]; then
            # touch on the mp4 file so that other machines can find it too
            touch "./gan-project-results/vids/$VIDEOID.mp4"
            # Make dirs
            mkdir -p ./gan-project-results/vids
            mkdir -p ./gan-project-results/imgs
            mkdir -p ./gan-project-results/imgs/$CATDOWNLOAD
            # Download the video
            youtube-dl --quiet --no-warnings --no-continue -f 'bestvideo[ext=mp4]/bestvideo' --merge-output-format mp4 -o "./gan-project-results/vids/${VIDEOID}.mp4" "${VIDEOID}" &>/dev/null
            # Cut the screencaps
            ffmpeg -nostdin -i "./gan-project-results/vids/${VIDEOID}.mp4" -vf "fps=1/15" -ss "15" -sseof "-15" "./gan-project-results/imgs/${CATDOWNLOAD}/${VIDEOID}-%03d.jpg" &>/dev/null
            # Resize the caps
            mogrify -resize 640x480 ./gan-project-results/imgs/${CATDOWNLOAD}/${VIDEOID}*
            # Done
            echo "DONE: $VIDEOID"
        fi
    fi
done < "youtube-labels.csv"

echo "DONE DONE, prep for shutdown"

# stop machine
gcloud compute instances stop $(hostname) --quiet --zone $(echo $(curl "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "Metadata-Flavor:Google") | csvtool -t '/' col "4" -)