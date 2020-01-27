#!/usr/bin/env sh

set -e

if [ "${CI_COMMIT_REF_NAME}" == "master" ]; then
  echo "production"
elif [ "${CI_COMMIT_REF_NAME}" == "develop" ]; then
  echo "development"
else
  echo "${CI_COMMIT_REF_NAME}"
fi
