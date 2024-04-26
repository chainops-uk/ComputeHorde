#!/bin/bash -eux

( cd nginx && ./publish-image.sh )

source build-preprod.sh
source _publish-image.sh
