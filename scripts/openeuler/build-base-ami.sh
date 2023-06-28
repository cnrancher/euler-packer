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
    errcho "MacOS is not supported"
    exit 1
fi

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: "
    echo "      BUCKET_NAME=<bucket name> VERSION=<version> ARCH=<arch> $0"
    echo "Example: "
    echo "      BUCKET_NAME=example-bucket VERSION=22.03-LTS ARCH=x86_64 $0"
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

if [[ -z "${VERSION}" ]]; then
    errcho "environment VERSION required!"
    exit 1
else
    echo "VERSION: ${VERSION}"
fi

if [[ -z "${ARCH}" ]]; then
    errcho "environment ARCH not specified, set to default: x86_64"
    ARCH=x86_64
else
    echo "ARCH: ${ARCH}"
fi

OPENEULER_IMG="openEuler-${VERSION}-${ARCH}"

cd $WORKING_DIR/tmp
echo "---- Current dir: $(pwd)"

echo "---- Converting SHRINKED-${OPENEULER_IMG}.qcow2 to RAW image..."
if [[ ! -e "SHRINKED-${OPENEULER_IMG}.qcow2" ]]; then
   errcho "File 'SHRINKED-${OPENEULER_IMG}.qcow2' not found in 'tmp/' folder!"
   exit 1
fi
qemu-img convert SHRINKED-${OPENEULER_IMG}.qcow2 ${OPENEULER_IMG}.raw

echo "---- Uploading RAW image to S3 Bucket..."
EXISTS=$(aws s3 ls ${BUCKET_NAME}/${OPENEULER_IMG}.raw || echo -n "false")
if [[ "${EXISTS}" == "false" ]]; then
   echo "--- aws s3 cp"
   aws s3 cp ${OPENEULER_IMG}.raw s3://${BUCKET_NAME}/
else
   echo "---- File ${OPENEULER_IMG}.raw already uploaded on S3, delete and re-upload it?"
   read -p "---- [y/N]: " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || DELETE="false"
   if [[ "$DELETE" == "false" ]]; then
      echo "----- Skip re-upload."
   else
      aws s3 rm s3://${BUCKET_NAME}/${OPENEULER_IMG}.raw
      aws s3 cp ${OPENEULER_IMG}.raw s3://${BUCKET_NAME}/
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
   --description "openEuler RAW image import task" \
   --disk-container \
   "Format=RAW,UserBucket={S3Bucket=${BUCKET_NAME},S3Key=${OPENEULER_IMG}.raw}" > import-output.txt
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
if [[ "${ARCH}" == "x86_64" ]]; then
   AWS_ARCH="x86_64"
elif [[ "${ARCH}" == "aarch64" ]]; then
   AWS_ARCH="arm64"
else
   errcho "Unsupported Arch: ${ARCH}"
   errcho "Valid ARCH: x86_64 or aarch64"
   exit 1
fi

CURRENT_TIME=$(date +"%Y%m%d")
aws ec2 register-image \
    --name "DEV-${OPENEULER_IMG}-${CURRENT_TIME}-BASE" \
    --description "DEV openEuler image, do not use for production!" \
    --root-device-name /dev/xvda \
    --architecture ${AWS_ARCH} \
    --ena-support \
    --virtualization-type hvm \
    --block-device-mappings \
      DeviceName=/dev/xvda,Ebs={SnapshotId=${SNAPSHOT_ID}} > register-image.txt
cat register-image.txt
echo "---- $0 Done."
