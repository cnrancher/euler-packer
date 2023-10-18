#!/bin/bash

# Set working dir
cd $(dirname $0)/../
export WORKING_DIR=$(pwd)

echo "---- Delete tmp folder"
rm -r $WORKING_DIR/tmp &> /dev/null || echo "---- tmp folder already deleted"
echo "---- Done"
