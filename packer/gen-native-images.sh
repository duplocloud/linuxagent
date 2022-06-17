#!/bin/bash -eu
#
# Work-in-progress tool to generate a JSON snippet for BuiltInNativeImages.json
#

names="$(jq -r '.builds[] | select(.builder_type == "amazon-ebs") | .name' <packer-manifest.json)"
json=""

echo "Generating snippet-NativeImages.json"

for name in $names
do
    nicename="$(echo $name | sed -e '
        s/amazonlinux-/AmazonLinux/g
        s/ubuntu-/Ubuntu/g
    ')"

    echo "
$nicename images:"
    artifacts="$(
        jq -r '.builds[] | select((.builder_type == "amazon-ebs") and .name == "'"$name"'") | .artifact_id' <packer-manifest.json |
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
            s/eu-west-2/London/g
        ')"

        case "$name" in
        amazon*)
            user=ec2-user
            ;;
        ubuntu*)
            user=ubuntu
            ;;
        esac

        echo "$niceregion" "$image"

        [ -n "$json" ] && json="${json},"
        json="${json}
  {
    \"Name\": \"Docker-Duplo-${niceregion}-${nicename}\",
    \"ImageId\": \"${image}\",
    \"Region\": \"${region}\",
    \"Username\": \"${user}\",
    \"Agent\": 0
  }"    
    done
done

echo "[$json
]" >snippet-NativeImages.json
