#!/usr/bin/env sh

set -e

if [ "${CI_COMMIT_REF_NAME}" == "master" ]; then
  echo "prod"
elif [ "${CI_COMMIT_REF_NAME}" == "develop" ]; then
  echo "dev"
else
  echo "${CI_COMMIT_REF_NAME}"
fi
