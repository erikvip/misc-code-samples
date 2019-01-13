#!/bin/bash
#
# Download full seasons from southparkstudios.com
# Specify season as first argument...or leave blank to download all available seasons
# Not everything is available though...some require huluplus access (which we skip over)
# Maintains a list of downloaded episodes, so you can re-scan using this script & fetch new episodes which have been authorized for free
# 
# Videos are downloaded into CWD/videos
# Temp files are moved into CWD/tmp
# If you wish to move files to a different location, setup a ~/.spdownload-post-run executable file, 
# which will be run after all seasons have finished downloading. The first argument passed will be the ROOTDIR of this script (videos should be under /videos)

set -o nounset  # Fail when access undefined variable
set -o errexit  # Exit when a command fails

# Root dir of this script
ROOTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Main entry point
main() {

	REQSEASON=${1:-};
	numeric='^[0-9]+$';

	# First season aired in 1997, so subtract 1997 from current year to get the highest season
	CUR_YEAR=$(date +%Y)
	MAX_SEASON=$(($CUR_YEAR - 1997 + 1));

	if [ -z "${REQSEASON}" ]; then
		echo "No season number specified. Assuming re-check of all seasons...";
		for s in $(seq 1 "${MAX_SEASON}"); do
			echo "Downloading season ${s}...";
			download_season "${s}";
		done;
	else 
		if  ! [[ $REQSEASON =~ $numeric ]]; then
			echo "ERROR: Must specify a numeric season number, or leave blank for all.";
			exit 1;
		else
			download_season "${REQSEASON}";
		fi
	fi

	# Run the configured SPPOST_RUN command, if applicable
	if [ -f ~/.spdownload-post-run ]; then
		source ~/.spdownload-post-run ${ROOTDIR}
	else
		echo "No executable file found under ~/.spdownload-post-run. Skipping post run script.";
	fi

}

download_season() {
	SEASON=$1;
	[ ! -d "${ROOTDIR}/videos/s${SEASON}" ] && mkdir -p "${ROOTDIR}/videos/s${SEASON}";
	[ ! -d "${ROOTDIR}/tmp" ] && mkdir "${ROOTDIR}/tmp";

	seasonfile=$(tempfile);

	wget -q -O "${seasonfile}" "http://southpark.cc.com/feeds/carousel/video/06bb4aa7-9917-4b6a-ae93-5ed7be79556a/30/1/json/!airdate/season-${SEASON}?lang=en";

	for i in $(jq '.results[] | select( ._availability == "true") | {itemId: .itemId, avail:._availability, title:.title, url: ._url .default}' "${seasonfile}" \
	  | jq .itemId | tr -d '"'); do

		epfilelist=$(tempfile);

		EPTITLE=$(jq ".results[] | select( .itemId == \"${i}\") | .title" "${seasonfile}" | tr -d '"');
		EPURL=$(jq ".results[] | select( .itemId == \"${i}\") | ._url .default" "${seasonfile}" | tr -d '"');
		EPAVAIL=$(jq ".results[] | select( .itemId == \"${i}\") | ._availability" "${seasonfile}" | tr -d '"');
		EPDESC=$(jq ".results[] | select( .itemId == \"${i}\") | .description" "${seasonfile}" | tr -d '"');
		EPNUM=$(jq ".results[] | select( .itemId == \"${i}\") | .episodeNumber" "${seasonfile}" | tr -d '"');

		EPFILES=$(youtube-dl --get-filename "${EPURL}" | sed 's/ /\\ /g' | tr -d '"');

		OLDIFS="${IFS}";
		IFS=$'\n';

		# Prefix epfiles list with "file  ..." for ffmpeg
		for f in ${EPFILES}; do
			echo "File: ${f}";
			#echo "${ROOTDIR}/${f}" | tr -d '\\' | sed -e 's/ /\\ /g' -e 's/^/file /g' | tr -d "'" >> ${epfilelist};
			echo "${ROOTDIR}/${f}" | tr -d '\\' | sed -e 's/ /\\ /g' -e 's/^/file /g' | sed "s/'/\\\'/g" >> ${epfilelist};
		done;
		IFS="${OLDIFS}";

		EPSINGLEFILE=$(tail -1 ${epfilelist} | cut -d' ' -f2- | cut -d'-' -f1-2 | tr -d '\\' | sed 's/ $//g' | sed "s/'/\\\'/g");

		EXISTS="0"
		if [ -f "${ROOTDIR}/eplist.txt" ]; then
			EXISTS=$(grep "${EPNUM}" "${ROOTDIR}/eplist.txt" | wc -l);
		fi

		if [[ $EXISTS == "0" ]]; then
			# Does not exist, download it now
			tput bold; echo -n "${EPTITLE} Episode: ${EPNUM}"; tput "sgr0";
			echo
			echo $EPURL; 
			echo $EPDESC;
			echo "-------------";
			youtube-dl ${EPURL}
			tput bold; 
			echo -ne "epfilelist: ${epfilelist}"; echo
			echo -ne "Combining files to one mp4 video via ffmpeg concat";
			tput sgr0; echo
			#echo Command: ffmpeg -loglevel fatal -stats -f concat -i "${epfilelist}" -c copy "${EPSINGLEFILE}.mp4"
			ffmpeg -loglevel warning -safe 0 -stats -f concat -i "${epfilelist}" -c copy "${EPSINGLEFILE}.mp4"
			echo; tput bold; echo -e "Done. Created ${EPSINGLEFILE}.mp4"; echo -ne "Moving into ${ROOTDIR}/videos/s${SEASON}";tput sgr0; echo;
			mv "${EPSINGLEFILE}.mp4" "${ROOTDIR}/videos/s${SEASON}/";
			mv ${ROOTDIR}/*.mp4 ${ROOTDIR}/tmp/;
			echo;echo;
			echo ${EPNUM} >> "${ROOTDIR}/eplist.txt"
		else
			tput bold; echo -n "${EPTITLE} Episode: ${EPNUM}"; tput "sgr0";
			echo
			echo "Episode already exists in eplist.txt. Skipping...";
			echo
		fi
		# Cleanup
		rm "${epfilelist}"
	done;

	# Cleanup
	rm "${seasonfile}"

}

# Main program entry
main $*



###########################################
# Notes on procedure follow
###########################################
#
# URL to download JSON list of episodes:
# wget 'http://southpark.cc.com/feeds/carousel/video/06bb4aa7-9917-4b6a-ae93-5ed7be79556a/30/1/json/!airdate/season-19?lang=en'
#
# Parse json results, Filter based on value where _availability != huluplus
# cat season-19\?lang=en | jq '.results[] | select( ._availability != "huluplus") | {avail:._availability, title:.title, url: ._url .default}' | jq .url
#
# Then just use youtube-dl on the url...
#
# Combining files:
# ls *1906* | sed -e 's/ /\\ /g' -e 's/^/file /g' > 1906.txt
# ffmpeg -f concat -i "1906.txt" -c copy "South Park_South Park 1906 - Tweek x Craig.mp4"
#
