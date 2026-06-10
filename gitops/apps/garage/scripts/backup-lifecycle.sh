#!/bin/sh
set -eu

aws_region="${AWS_REGION:?missing AWS_REGION}"
bucket_name="${BUCKET_NAME:?missing BUCKET_NAME}"

cat >/tmp/lifecycle.json <<EOF
{
  "Rules": [
    {
      "ID": "expire-full-backups-after-7-days",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "full/"
      },
      "Expiration": {
        "Days": 7
      }
    },
    {
      "ID": "expire-binlogs-after-1-day",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "binlogs/"
      },
      "Expiration": {
        "Days": 1
      }
    },
    {
      "ID": "abort-incomplete-multipart-uploads",
      "Status": "Enabled",
      "Filter": {
        "Prefix": ""
      },
      "AbortIncompleteMultipartUpload": {
        "DaysAfterInitiation": 1
      }
    }
  ]
}
EOF

aws s3api put-bucket-lifecycle-configuration \
  --endpoint-url "http://garage.garage.svc.cluster.local:3900" \
  --region "$aws_region" \
  --bucket "$bucket_name" \
  --lifecycle-configuration "file:///tmp/lifecycle.json"
