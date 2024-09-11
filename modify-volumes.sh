#!/bin/bash

# Retrieve instance metadata using the imds command and populate environment variables
export INSTANCE_ID=$(imds /latest/meta-data/instance-id)
export AMI_ID=$(imds /latest/meta-data/ami-id)
export REGION=$(imds /latest/dynamic/instance-identity/document | jq -r .region)

# Check if the AMI is a Bottlerocket image
IS_BOTTLEROCKET=$(aws ec2 describe-images --image-ids $AMI_ID \
    --query "Images[0].Description" --region $REGION --output text --no-cli-pager | grep -i "bottlerocket")

# If not a Bottlerocket AMI, exit the script
if [ -z "$IS_BOTTLEROCKET" ]; then
    echo "This instance is not running a Bottlerocket AMI. Exiting."
    exit 0
fi

echo "Bottlerocket AMI detected. Proceeding with volume adjustments..."

# Modify the root volume to gp3 and resize. Adjust size as needed.
ROOT_VOLUME_ID=$(aws ec2 describe-volumes \
    --filters Name=attachment.instance-id,Values=$INSTANCE_ID Name=attachment.device,Values=/dev/xvda \
    --query "Volumes[0].VolumeId" --region $REGION --output text --no-cli-pager)

aws ec2 modify-volume --volume-id $ROOT_VOLUME_ID --size 25 --volume-type gp3 --region $REGION --no-cli-pager
echo "Root volume modified to gp3 and resized."

# Modify the data volume to gp3 and resized. Adjust size as needed.
DATA_VOLUME_ID=$(aws ec2 describe-volumes \
    --filters Name=attachment.instance-id,Values=$INSTANCE_ID Name=attachment.device,Values=/dev/xvdb \
    --query "Volumes[0].VolumeId" --region $REGION --output text --no-cli-pager)

aws ec2 modify-volume --volume-id $DATA_VOLUME_ID --size 150 --volume-type gp3 --region $REGION --no-cli-pager
echo "Data volume modified to gp3 and resized."

# Wait for the volume modifications to complete
while true; do
    ROOT_STATE=$(aws ec2 describe-volumes-modifications --volume-id $ROOT_VOLUME_ID --region $REGION --query "VolumesModifications[0].ModificationState" --output text --no-cli-pager)
    DATA_STATE=$(aws ec2 describe-volumes-modifications --volume-id $DATA_VOLUME_ID --region $REGION --query "VolumesModifications[0].ModificationState" --output text --no-cli-pager)

    if [[ "$ROOT_STATE" == "completed" && "$DATA_STATE" == "completed" ]]; then
        echo "Both volumes have been modified successfully."
        break
    else
        echo "Waiting for volume modifications to complete..."
        sleep 10
    fi
done
