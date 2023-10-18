#!/bin/bash
set -e

# Set working dir to root dir of this project
cd $(dirname $0)/../../
export WORKING_DIR=$(pwd)

# Ensure awscli and jq are installed
type aws
type jq

function errcho() {
   >&2 echo $@;
}

if [[ $(uname) == "Darwin" ]]; then
    errcho "macOS is not supported"
    exit 1
fi

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: "
    echo "      BUCKET_NAME=<bucket name> SUSEEULER_VERSION=<version> SUSEEULER_ARCH=<arch> $0"
    echo "Example: "
    echo "      BUCKET_NAME=example-bucket SUSEEULER_VERSION=2.1 SUSEEULER_ARCH=x86_64 $0"
    exit 0
fi

if [[ ! -e "${HOME}/.aws/config" ]]; then
    errcho "AWS cli not configured!"
    errcho "Please run 'aws configure' before running this script"
    exit 1
fi

if [[ -z "${BUCKET_NAME}" ]]; then
    errcho "environment BUCKET_NAME needed!"
    exit 1
else
    errcho "BUCKET_NAME: $BUCKET_NAME"
fi

if [[ -z "${SUSEEULER_VERSION}" ]]; then
    errcho "environment SUSEEULER_VERSION required!"
    exit 1
else
    echo "SUSEEULER_VERSION: ${SUSEEULER_VERSION}"
fi

if [[ -z "${SUSEEULER_ARCH}" ]]; then
    errcho "environment SUSEEULER_ARCH not specified, set to default: x86_64"
    SUSEEULER_ARCH=x86_64
else
    echo "SUSEEULER_ARCH: ${SUSEEULER_ARCH}"
fi

SUSEEULER_IMG="SEL-${SUSEEULER_VERSION}.${SUSEEULER_ARCH}-1.1.0-normal-Build"

cd $WORKING_DIR/tmp
echo "---- Current dir: $(pwd)"

echo "---- Converting SHRINKED-${SUSEEULER_IMG}.qcow2 to RAW image..."
if [[ ! -e "SHRINKED-${SUSEEULER_IMG}.qcow2" ]]; then
   errcho "File 'SHRINKED-${SUSEEULER_IMG}.qcow2' not found in 'tmp/' folder!"
   exit 1
fi
rm ${SUSEEULER_IMG}.raw || true
qemu-img convert SHRINKED-${SUSEEULER_IMG}.qcow2 ${SUSEEULER_IMG}.raw

echo "---- Uploading RAW image to S3 Bucket..."
EXISTS=$(aws s3 ls ${BUCKET_NAME}/${SUSEEULER_IMG}.raw || echo -n "false")
if [[ "${EXISTS}" == "false" ]]; then
   echo "--- aws s3 cp"
   aws s3 cp ${SUSEEULER_IMG}.raw s3://${BUCKET_NAME}/
else
   echo "---- File ${SUSEEULER_IMG}.raw already uploaded on S3, delete and re-upload it?"
   read -p "---- [y/N]: " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || DELETE="false"
   if [[ "$DELETE" == "false" ]]; then
      echo "----- Skip re-upload."
   else
      aws s3 rm s3://${BUCKET_NAME}/${SUSEEULER_IMG}.raw
      aws s3 cp ${SUSEEULER_IMG}.raw s3://${BUCKET_NAME}/
   fi
fi

echo "---- Creating vmimport policy..."
cat << EOF > trust-policy.json
{
   "Version": "2012-10-17",
   "Statement": [
      {
         "Effect": "Allow",
         "Principal": { "Service": "vmie.amazonaws.com" },
         "Action": "sts:AssumeRole",
         "Condition": {
            "StringEquals":{
               "sts:Externalid": "vmimport"
            }
         }
      }
   ]
}
EOF

aws iam create-role --role-name vmimport --assume-role-policy-document file://trust-policy.json || echo "vmimport policy already created, skip."

echo "---- Creating role policy..."
cat << EOF > role-policy.json
{
   "Version":"2012-10-17",
   "Statement":[
      {
         "Effect": "Allow",
         "Action": [
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket"
         ],
         "Resource": [
            "arn:aws:s3:::${BUCKET_NAME}",
            "arn:aws:s3:::${BUCKET_NAME}/*"
         ]
      },
      {
         "Effect": "Allow",
         "Action": [
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket",
            "s3:PutObject",
            "s3:GetBucketAcl"
         ],
         "Resource": [
            "arn:aws:s3:::${BUCKET_NAME}",
            "arn:aws:s3:::${BUCKET_NAME}/*"
         ]
      },
      {
         "Effect": "Allow",
         "Action": [
            "ec2:ModifySnapshotAttribute",
            "ec2:CopySnapshot",
            "ec2:RegisterImage",
            "ec2:Describe*"
         ],
         "Resource": "*"
      }
   ]
}
EOF

aws iam put-role-policy --role-name vmimport --policy-name vmimport --policy-document file://role-policy.json || echo -n ""

echo "---- Importing image..."
aws ec2 import-snapshot \
   --description "SUSE Euler Linux RAW image import task" \
   --disk-container \
   "Format=RAW,UserBucket={S3Bucket=${BUCKET_NAME},S3Key=${SUSEEULER_IMG}.raw}" > import-output.txt
cat import-output.txt
echo "---- Import task created."

IMPORT_TAST_ID=$(cat import-output.txt | jq -r ".ImportTaskId")
IMPORT_STATUS_MESSAGE=$(cat import-output.txt | jq -r ".SnapshotTaskDetail.Status")
echo "----- IMPORT_TAST_ID: ${IMPORT_TAST_ID}"
echo "---- Waiting snapshot create completed..."
while [[ "${IMPORT_STATUS_MESSAGE}" != "completed" ]]
do
   sleep 2
   aws ec2 describe-import-snapshot-tasks \
      --import-task-ids ${IMPORT_TAST_ID} > import-output.txt
   IMPORT_STATUS_MESSAGE=$(cat import-output.txt | jq -r ".ImportSnapshotTasks[0].SnapshotTaskDetail.Status")
   echo "STATUS: $IMPORT_STATUS_MESSAGE"
done
SNAPSHOT_ID=$(cat import-output.txt | jq -r ".ImportSnapshotTasks[0].SnapshotTaskDetail.SnapshotId")
if [[ -z "SNAPSHOT_ID" ]]; then
   errcho "---- Failed to get snapshot id"
else
   echo "---- shapshot id: $SNAPSHOT_ID"
fi

echo "----- Creating AMI image..."
if [[ "${SUSEEULER_ARCH}" == "x86_64" ]]; then
   AWS_ARCH="x86_64"
elif [[ "${SUSEEULER_ARCH}" == "aarch64" ]]; then
   AWS_ARCH="arm64"
else
   errcho "Unsupported Arch: ${SUSEEULER_ARCH}"
   errcho "Valid SUSEEULER_ARCH: x86_64 or aarch64"
   exit 1
fi

CURRENT_TIME=$(date +"%Y%m%d")
aws ec2 register-image \
    --name "DEV-${SUSEEULER_IMG}-${CURRENT_TIME}-BASE" \
    --description "DEV SUSE Euler Linux image, do not use for production!" \
    --root-device-name /dev/xvda \
    --architecture ${AWS_ARCH} \
    --ena-support \
    --virtualization-type hvm \
    --block-device-mappings \
      DeviceName=/dev/xvda,Ebs={SnapshotId=${SNAPSHOT_ID}} > register-image.txt
cat register-image.txt

sleep 30

echo "---- $0 Done."
