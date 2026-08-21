#!/bin/bash -eu
#
# Tool to generate a JSON snippet for BuiltInNativeImages.json
#

# Utility functions.
out() { echo "$0:" "$@" ; return 0 ; }
err() { echo "$0:" "$@" 1>&2 ; return 0 ; }

# Sanity checks.
if file "${BASH_SOURCE[0]}" | grep -q CRLF
then err 'STOP!

Your Windows system has converted LF to CRLF.  The script will not function properly.

Please re-checkout the files after running:
  git config core.autocrlf false
' ; exit 1
fi
if ! command -v jq >/dev/null 2>&1
then err "JQ must be installed" ; exit 1
fi
if [[ "$(git config core.autocrlf)" != "false" ]]
then err "git config core.autocrlf must be set to 'false' for this repo" ; exit 1
fi

# Step 1 - Get all image IDs from packer and use them to generate a JSON snippet
out "NativeImages JSON: generating snippet"
json=""
for input_file in ${INPUT_FILES:-packer-manifest.json}
do
    names="$(jq -r '.builds[] | select(.builder_type == "amazon-ebs") | .name' <"$input_file")"
    for name in $names
    do
        nicename="$(echo $name | sed -e '
            s/amazonlinux-/AmazonLinux/g
            s/ubuntu-/Ubuntu/g
        ')"

        arch="amd64"
        [[ "${name/arm64/}" != "$name" ]] && arch="arm64"
        nicename="${nicename/-arm64/ (arm64)}"

        echo "
$nicename images:"
        artifacts="$(
            jq -r '.builds[] | select((.builder_type == "amazon-ebs") and .name == "'"$name"'") | .artifact_id' <"$input_file" |
            tr ',' '\n'
        )"
        for artifact in $artifacts
        do
            image="${artifact#*:}"
            region="${artifact%:*}"

            niceregion="$(echo $region | sed -e '
                s/us-east-1/NoVirginia/g
                s/us-east-2/Ohio/g
                s/us-west-1/California/g
                s/us-west-2/Oregon/g
                s/sa-east-1/SaoPaulo/g
                s/ap-northeast-1/Tokyo/g
                s/ap-south-1/Mumbai/g
                s/eu-west-1/Ireland/g
                s/eu-west-2/London/g
                s/eu-west-3/Paris/g
                s/eu-central-1/Frankfurt/g
                s/sa-east-1/SaoPaulo/g
                s/ca-central-1/CanadaCentral/g
                s/us-gov-west-1/UsGovWest1/g
                s/us-gov-east-1/UsGovEast1/g
                s/ap-southeast-1/Singapore/g
                s/ap-southeast-2/Sydney/g
                s/me-central-1/UAE/g
            ')"

            case "$name" in
            amazon*)
                user=ec2-user
                ;;
            ubuntu*)
                user=ubuntu
                ;;
            *)
                # Without this the previous iteration's $user would silently carry over.
                err "no SSH username mapping for builder name '$name'"
                exit 1
                ;;
            esac

            echo "$niceregion" "$image"

            [[ -n "$json" ]] && json="${json},"
            json="${json}
  {
    \"Name\": \"Docker-Duplo-${niceregion}-${nicename}\",
    \"ImageId\": \"${image}\",
    \"Region\": \"${region}\",
    \"Username\": \"${user}\",
    \"Agent\": 0,
    \"Arch\": \"${arch}\"
  }"    
        done
    done
done

echo "[$json
]" >snippet-temp.json
jq '. | map(select(.Name == "Docker-Duplo-Oregon-Ubuntu22" and .Arch == "amd64") | .Name = "Docker-Duplo") + .' <snippet-temp.json >snippet-temp2.json
jq '. | map(select(.Name == "Docker-Duplo-Oregon-Ubuntu22 (arm64)" and .Arch == "arm64") | .Name = "Docker-Duplo (arm64)") + .' <snippet-temp2.json >snippet-NativeImages.json
out "NativeImages JSON: snippet done"

# Step 2 - Build a new native images JSON
: ${DUPLO_SOURCE=../../duplo}
snippet="$(pwd -P)/snippet-NativeImages.json"
(cd "$DUPLO_SOURCE" &&

    # Merge by Name so a scoped Packer build (for example only_builders=AL2023) only replaces the rows it
    # rebuilt. The previous join dropped every "Docker-Duplo*" row, wiping AL2 / Ubuntu / GovCloud entries.
    # IN($newNames[]) rather than `$newNames | index(.Name)`, since piping into index rebinds `.` and would
    # read .Name off the array itself.
    jq 'input as $snippet
        | ($snippet | map(.Name)) as $newNames
        | $snippet
          + (. | map(select(
              ((.Name | startswith("Docker-Duplo")) | not)
              or ((.Name | IN($newNames[])) | not)
            )))' \
        config/V1/BuiltInNativeImages.json  "$snippet" > temp.json &&

    # Replace the existing JSON
    mv temp.json config/V1/BuiltInNativeImages.json
)

