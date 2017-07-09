# gan-movie
Movie based on Youtube dataset and GAN

_Note: this is completely based on Google Cloud platform. The software in this repo is meant to be used as reference. If you want to recreate the project you probably have to make a few changes here and there._

## Download and process images

1. `$ sudo su`
2. `$ cd /etc/systemd/system/`
3. `$ wget https://raw.githubusercontent.com/bobvanluijt/gan-movie/master/ganMovie.service`
4. `$ systemctl daemon-reload`
5. `$ systemctl enable ganMovie.service`
6. `$ wget https://raw.githubusercontent.com/bobvanluijt/gan-movie/master/downloadVideos.sh -o /home/[HOMEDIR]/downloadVideos.sh`

- Read instructions in: https://github.com/bobvanluijt/gan-movie/blob/master/downloadVideos.sh
- Change the ID of the category to download.
- Store the drive of this instance as a clone and create multiple machines to download videos.

