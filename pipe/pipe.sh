#!/usr/bin/env bash
#
# A  pipe to run SCA and SAST security scans
#

source "$(dirname "$0")/common.sh"

info "Executing the pipe..."

# Required parameters
BRIDGE_BLACKDUCK_URL=${BRIDGE_BLACKDUCK_URL:=''}
BRIDGE_BLACKDUCK_TOKEN=${BRIDGE_BLACKDUCK_TOKEN:=''}

# Default parameters
DEBUG=${DEBUG:="false"}

retry_attempts=3
delay_in_seconds=15
ARTIFACTORY_BRIDGE_URL="https://sig-repo.synopsys.com/artifactory/bds-integrations-release/com/synopsys/integration/synopsys-bridge/"
echo "Starting synopsys-template execution.."
echo "$OSTYPE platform"
bridgeDefaultDirectory="synopsys-bridge"
bridgeDefaultPath=""
synopsysBridgeVersion=""
diagnostics=""
latest_version_error_message="Getting latest Synopsys Bridge versions has been failed"
synopsys_bridge_error_message="Synopsys Bridge download has been failed"
synopsys_all_version_error_message="Getting all available Synopsys Bridge versions has been failed"
exempted_response_http_codes=("200" "201" "401" "403" "416")
function retry_delay_with_log() {
	local exception_message="$1"
	local attempt="$2"
	local delay_in_seconds="$3"
	echo "$exception_message, Retries left:$((retry_attempts - attempt + 1)),  Waiting: ${delay_in_seconds} Seconds"
	sleep "${delay_in_seconds}"
}
function retry_template() {
	local exception_message="$1"
	local latestUrl="$2"
	local downloadFile="$3"
	for ((attempt = 1; attempt <= retry_attempts; attempt++)); do
		curl -LsS -w "\nHTTP_RESPONSE_CODE:%{http_code}" -X GET --header "Accept: text/html" "${latestUrl}" >>"$downloadFile"
		http_response_status_code=$(tail -n 1 "$downloadFile" | cut -d ':' -f 2)
		if echo "${exempted_response_http_codes[@]}" | grep -qw "$http_response_status_code"; then
			break
		fi
		if [[ -f $downloadFile ]]; then
			rm -rf "$downloadFile"
		fi
		retry_delay_with_log "${exception_message}" "$attempt" "$delay_in_seconds"
		delay_in_seconds=$((2 * delay_in_seconds))
	done

	if [[ $((attempt - 1)) -eq $retry_attempts ]]; then
			delay_in_seconds=15
		if [[ "artifactoryResults.html" == "$downloadFile" ]]; then
				echo "$exception_message"
				exit 1
		else
				echo "$latest_version_error_message"
		fi
	fi
}
OSTYPE=$(echo "$OSTYPE" | tr '[:upper:]' '[:lower:]')
if [[ "$OSTYPE" == *"linux"* ]]; then
	bridgeDefaultPath="${HOME}/${bridgeDefaultDirectory}"
	platform="linux64"
elif [[ "$OSTYPE" == *"darwin"* ]]; then
	bridgeDefaultPath="${HOME}/${bridgeDefaultDirectory}"
	arch="$(uname -m)"
	min_arm_supported_version="2.1.0"
	if [[ $DOWNLOAD_BRIDGE_VERSION != "" && "$(printf '%s\n' "$DOWNLOAD_BRIDGE_VERSION" "$min_arm_supported_version" | sort -V | head -n1)" != "$min_arm_supported_version" ]]; then
		platform="macosx"
	else  
		if [[ "$arch" = x86_64* && "$(uname -a)" = "*ARM64*" ]] || [[ "$arch" = arm* || "$arch" = aarch64 ]]; then
			platform="macos_arm"
		else
			platform="macosx"							
		fi
	fi  	
fi

EXECUTABLE_SYNOPSYS_BRIDGE_PATH=$bridgeDefaultPath
if [[ $SYNOPSYS_BRIDGE_INSTALL_DIRECTORY != '' ]]; then
	if ! [[ -d $SYNOPSYS_BRIDGE_INSTALL_DIRECTORY ]]; then
		echo "Synopsys Bridge Install Directory doesn't exist"
		exit 1
	fi
	EXECUTABLE_SYNOPSYS_BRIDGE_PATH=$SYNOPSYS_BRIDGE_INSTALL_DIRECTORY
fi

if [[ $BRIDGE_NETWORK_AIRGAP == 'true' ]]; then
	if [[ "$OSTYPE" == *"linux"* || "$OSTYPE" == *"darwin"* ]]; then
		if [[ $SYNOPSYS_BRIDGE_INSTALL_DIRECTORY == '' && ! -d $EXECUTABLE_SYNOPSYS_BRIDGE_PATH ]]; then
			echo "Synopsys Bridge default directory doesn't exist"
			exit 1
		fi
		if [[ ! -f ${EXECUTABLE_SYNOPSYS_BRIDGE_PATH}/"synopsys-bridge" ]]; then
			echo "Synopsys Bridge executable file could not be found at $EXECUTABLE_SYNOPSYS_BRIDGE_PATH"
			exit 1
		fi
	else
		echo "OS ${OSTYPE} is not supported"
		exit 1
	fi
else
	### Creating default directory if SYNOPSYS_BRIDGE_INSTALL_DIRECTORY input is not passed ###
	if [[ $SYNOPSYS_BRIDGE_INSTALL_DIRECTORY == "" ]]; then
		if ! [[ -d ${bridgeDefaultPath} ]]; then
			mkdir -p "${bridgeDefaultPath}"
		fi
		EXECUTABLE_SYNOPSYS_BRIDGE_PATH=$bridgeDefaultPath
	fi
fi

### If BRIDGE_DOWNLOAD_URL is not provided, check for BRIDGE_DOWNLOAD_VERSION or latest version ###
if [[ $BRIDGE_NETWORK_AIRGAP != 'true' && $DOWNLOAD_BRIDGE_URL == "" ]]; then
	### Get all available Bridge versions and store result in artifactoryResults temp file ###

	### Check if BRIDGE_DOWNLOAD_VERSION is provided and the provided version exists ###
	if [[ $DOWNLOAD_BRIDGE_VERSION != "" ]]; then
		retry_template "${synopsys_all_version_error_message}" "$ARTIFACTORY_BRIDGE_URL/"  "artifactoryResults.html"
		IFS=$'\n'
		versionArray=($(sed -n 's/.*href="\([0-9.^"]*\).*/\1/p' artifactoryResults.html))
		rm -rf artifactoryResults.html
		validBridgeVersion=false
		for i in "${versionArray[@]}"; do
			if [[ $i != "" && $i != ".." ]]; then
				if [[ $i == "${DOWNLOAD_BRIDGE_VERSION}" ]]; then
					validBridgeVersion=true
					break
				fi
			fi
		done
		if $validBridgeVersion; then
			echo "Valid synopsys bridge version"
			bridgeDownloadUrl="$ARTIFACTORY_BRIDGE_URL/$DOWNLOAD_BRIDGE_VERSION/synopsys-bridge-$DOWNLOAD_BRIDGE_VERSION-$platform.zip"
			synopsysBridgeVersion=$DOWNLOAD_BRIDGE_VERSION
		else
			echo "Provided synopsys bridge version not found in artifactory"
			exit 1
		fi
		### Check for latest version of Bridge ###
	else
		versionLatestTxtURL=${ARTIFACTORY_BRIDGE_URL}"/latest/versions.txt"
		retry_template "${latest_version_error_message}"  "${versionLatestTxtURL}" "latest-versions.txt"

		if [[ $(cat latest-versions.txt | grep -c -w 'Synopsys Bridge Package') -gt 0 ]]; then
			latestVersion=$(cat latest-versions.txt | grep 'Synopsys Bridge Package' | head -1 | awk -F= "{ print $2 }" | sed 's/[Synopsys Bridge Package:,\",]//g' | tr -d '[[:space:]]')
			synopsysBridgeVersion=$latestVersion
			rm -rf latest-versions.txt
		fi
		bridgeDownloadUrl="${ARTIFACTORY_BRIDGE_URL}/latest/synopsys-bridge-$platform.zip"
	fi

elif [[ $BRIDGE_NETWORK_AIRGAP != 'true' ]]; then
	### Validate bridge url ###
	shopt -s nocasematch
	regex='(https?|http)://[-[:alnum:]\+&@#/%?=~_|!:,.;]*[-[:alnum:]\+&@#/%=~_|]'
	invalidUrlMsg="Invalid Bridge URL for $OSTYPE platform"
	if [[ ! $DOWNLOAD_BRIDGE_URL =~ $regex ]]; then
		echo "${invalidUrlMsg}"
		exit 1
	fi
	downloadFileName=$(echo "$DOWNLOAD_BRIDGE_URL" | awk -F"-" '{print $NF}')
	if [[ $downloadFileName != "$platform.zip" ]]; then
		echo "$invalidUrlMsg"
		exit 1
	fi
	bridgeDownloadUrl=$DOWNLOAD_BRIDGE_URL
	synopsysBridgeVersion="$( (echo "$bridgeDownloadUrl" | sed "s/^.*synopsys-bridge-\([0-9.]*\).*/\1/"))"
	if [[ $synopsysBridgeVersion == '' ]]; then
		retry_template "${latest_version_error_message}"  "$(echo "$bridgeDownloadUrl" | sed 's/synopsys-bridge-[macos_arm|macosx|linux64]*.zip*/versions.txt/g')" "latest-versions.txt"
		latestVersionTextFile=latest-versions.txt
		if [[ -f $latestVersionTextFile ]]; then
				synopsysBridgeVersion=$(cat latest-versions.txt | grep 'Synopsys Bridge Package' | head -1 | awk -F= "{ print $2 }" | sed 's/[Synopsys Bridge Package:,\",]//g' | tr -d '[[:space:]]')
				rm -rf latest-versions.txt
		fi
	fi
fi
### Matching the current bridge version from existing bridge package     ###
versionFile="${EXECUTABLE_SYNOPSYS_BRIDGE_PATH}/versions.txt"
isBridgeExist=false
if [[ -e $versionFile ]]; then
	synopsysBridgePackage="Synopsys Bridge Package: $synopsysBridgeVersion"
	existingPackageVersion=$(sed -n "/Synopsys Bridge Package: $synopsysBridgeVersion/p" "$versionFile")
	if [[ $existingPackageVersion != "" && $existingPackageVersion == "$synopsysBridgePackage" ]]; then
		isBridgeExist=true
	fi
fi

### Append diagnostic argument in bridge command if INCLUDE_DIAGNOSTICS is passed ###
if [[ $INCLUDE_DIAGNOSTICS == true ]]; then
	diagnostics="--diagnostics"
fi

if [[ "$OSTYPE" == *"linux"* || "$OSTYPE" == *"darwin"* ]]; then
	if [[ $BRIDGE_NETWORK_AIRGAP != 'true' ]]; then
		if [[ $isBridgeExist == false ]]; then
			### Download Bridge ###
			echo "Downloadable Bridge URL - $bridgeDownloadUrl"

			for ((attempt = 1; attempt <= retry_attempts; attempt++)); do
				# Get the content length of the URL using curl
				download_response=$(curl -sS -w "HTTP_RESPONSE_CODE:%{http_code}" $bridgeDownloadUrl -o "${EXECUTABLE_SYNOPSYS_BRIDGE_PATH}/synopsys-bridge.zip")
				remote_content_length_url=$(curl -sI $bridgeDownloadUrl | tr '[:upper:]' '[:lower:]' | awk '/content-length/ {print $2}' | tr -d '\r')
				http_response_status_code=$(echo "$download_response" | cut -d ':' -f 2)
				if echo "${exempted_response_http_codes[@]}" | grep -qw "${http_response_status_code}"; then
					# Get the file size of the local file
					downloaded_file_size=$(wc -c <"${EXECUTABLE_SYNOPSYS_BRIDGE_PATH}/synopsys-bridge.zip" | tr -d '[:space:]')
					# Compare the content length and file size
					if [ "$remote_content_length_url" -eq "$downloaded_file_size" ]; then
						break
					fi
				fi
				retry_delay_with_log "${synopsys_bridge_error_message}" $attempt $delay_in_seconds
				delay_in_seconds=$((2 * delay_in_seconds))
			done
			if [[ $((attempt - 1)) -eq $retry_attempts ]]; then
				echo "$synopsys_bridge_error_message"
				delay_in_seconds=15
				exit 1
			fi
			### Unzip Bridge ###
			unzip -q -o "${EXECUTABLE_SYNOPSYS_BRIDGE_PATH}/synopsys-bridge.zip" -d "${EXECUTABLE_SYNOPSYS_BRIDGE_PATH}"
			### Remove downloaded zip file ###
			rm "${EXECUTABLE_SYNOPSYS_BRIDGE_PATH}/synopsys-bridge.zip"
		else
			echo "Synopsys Bridge already exists, download has been skipped"

		fi
	else
		echo "Network air gap is enabled, skipping synopsys-bridge download."
	fi

	chmod +x "${EXECUTABLE_SYNOPSYS_BRIDGE_PATH}"

	echo "Files in ${EXECUTABLE_SYNOPSYS_BRIDGE_PATH}/extensions directory:"
	ls -pl "${EXECUTABLE_SYNOPSYS_BRIDGE_PATH}/extensions" | grep -v /

	if [[ ! -f ${EXECUTABLE_SYNOPSYS_BRIDGE_PATH}/"synopsys-bridge" ]]; then
		echo "Synopsys bridge executable file could not be found at ${EXECUTABLE_SYNOPSYS_BRIDGE_PATH}"
		exit 1
	fi
	"${EXECUTABLE_SYNOPSYS_BRIDGE_PATH}"/synopsys-bridge --stage gitlab-template-executor $diagnostics
else
	echo "OS "${OSTYPE}" is not supported"
	exit 1
fi