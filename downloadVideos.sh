#!/bin/bash

#
# This script should run on startup.
# Output images are 360x480
#
# Add to crontab: `source <(curl -s https://raw.githubusercontent.com/bobvanluijt/gan-movie/master/downloadVideos.sh)`
#
# It assumes that;
# 1. gcsfuse is installed
# 2. All is in europe-west1-b
# 3. There is a bucket called: gan-project-results003
# 4. unzip is installed
# 5. csvtool is installed
# 6. youtube-dl is installed
# 7. ffmpeg is installed
# 8. imagemagick is installed
#
# apt-get install unzip csvtool youtube-dl ffmpeg imagemagick
#

## Create and mount disk
mkdir -p gan-project-results003
gcsfuse --implicit-dirs gan-project-results003 ./gan-project-results003 &>/dev/null

## Download files from Github
rm -f vocabulary.csv
rm -f youtube-labels.csv
rm -f group.download
wget --quiet https://github.com/bobvanluijt/gan-movie/blob/master/vocabulary.csv?raw=true -O vocabulary.csv
wget --quiet https://github.com/bobvanluijt/gan-movie/blob/master/youtube-labels.csv.zip?raw=true -O youtube-labels.csv.zip
wget --quiet https://github.com/bobvanluijt/gan-movie/blob/master/group.download?raw=true -O group.download
unzip youtube-labels.csv.zip &>/dev/null && rm -f youtube-labels.csv.zip && rm -rf __MACOSX/

# shuffle to get random line per machine
shuf -o youtube-labels.csv youtube-labels.csv
shuf -o group.download group.download

# Random sleep because of multiple machines running
sleep $[ ( $RANDOM % 100 )  + 1 ]s

# Loop through the ids in the groups
while IFS='' read -r line2 || [[ -n "$line2" ]]; do
    # Category to download (https://research.google.com/youtube8m/explore.html)
    echo "Download all from category: $line2"
    # Get a random ID which is not downloaded yet
    while IFS='' read -r line || [[ -n "$line" ]]; do
        # Check of the line has the wanted command
        if echo "$line" | grep --quiet ,$line2,; then
            # get the video id
            VIDEOID=$(echo "$line" | csvtool -t ',' col "1" -)
            # Check if the video isn't already being downloaded
            if [ ! -f "./gan-project-results003/vids/$VIDEOID.mp4" ]; then
                # Make dir
                mkdir -p ./gan-project-results003/vids
                mkdir -p ./gan-project-results003/imgs
                mkdir -p ./gan-project-results003/imgs/$line2
                # touch on the mp4 file so that other machines can find it too
                touch "./gan-project-results003/vids/$VIDEOID.mp4"
                # Download the video
                youtube-dl --quiet --no-warnings --no-continue -f 'bestvideo[ext=mp4]/bestvideo' --merge-output-format mp4 -o "./gan-project-results003/vids/${VIDEOID}.mp4" "${VIDEOID}" &>/dev/null
                # Cut the screencaps
                ffmpeg -nostdin -i "./gan-project-results003/vids/${VIDEOID}.mp4" -vf "fps=1/15" -ss "30" -sseof "-30" "./gan-project-results003/imgs/${line2}/${VIDEOID}-%03d.jpg" &>/dev/null
                # Resize the caps
                mogrify -resize 256x192 ./gan-project-results003/imgs/${line2}/${VIDEOID}*
                find ./gan-project-results003/imgs/${line2} -type f -name "${VIDEOID}*" -exec convert {} -resize '256x192^' -gravity Center -crop 256x192+0+0 {}.png \; -exec rm {} \;
                # Empty file to free up space
                truncate -s 0 ./gan-project-results003/vids/${VIDEOID}.mp4
                # Done
                echo "DONE: $VIDEOID"
            fi
        fi
    done < "youtube-labels.csv"
done < "group.download"

echo "DONE DONE, prep for shutdown"

# stop machine
gcloud compute instances stop $(hostname) --quiet --zone $(echo $(curl "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "Metadata-Flavor:Google") | csvtool -t '/' col "4" -)
