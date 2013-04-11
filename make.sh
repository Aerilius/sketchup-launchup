#! /bin/bash
cd `dirname "$0"`

usage() {
  echo
  echo "Usage: sh $0 [version]"
  echo
}

loader=$(ls ./src/*.rb)
if [[ $1 != "" ]]; then
  # Get the version from the command line parameter.
  # Update it in the loader file. Get the first line with "version"
  # and replace number in quotes by new version number.
  if [[ $1 =~ ^[0-9][0-9\.]*$ ]]; then
    sed  "0,/version/s/[\"\'][0-9\.]*[\"\']/\'$1\'/" -i $loader
    echo "Making version $v"
    version=$(echo $1 | tr "." "_")
  else
    echo "Didn't understand version number."
    usage
    exit 1
  fi
else
  # Get the version from the loader file.
  v=$(grep version $loader | sed 's/[^0-9]*\([0-9\.]*\).*/\1/')
  echo "Making version $v"
  version=$(echo $v | tr "." "_")
fi

loaderbasename=${loader##*/}
loaderbasename=${loaderbasename#[^a-zA-Z]}
loaderbasename=${loaderbasename%.*}
name=$loaderbasename\_$version
exclude=". .. *~ .* *.bak *.old *.alt *.rbz *.rb! *.zip"

# Build archive.
cd ./src
[ -e ../archive ] && archivepath=../archive || archivepath=$0
zip -b /tmp -r $archivepath/$name\.rbz ./* --exclude $exclude
# Modification for LaunchUp: exclude commands.
#zip -b /tmp -r $archivepath/$name\.rbz ./* --exclude $exclude "ae_LaunchUp/commands/*"

# Modification for LaunchUp: export commands as separate archive.
#name=$loaderbasename\_$version\_commands
#zip -b /tmp -r ../archive/$name\.rbz ae_LaunchUp/commands/* --exclude $exclude

exit 0
