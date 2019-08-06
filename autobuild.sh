#!/bin/bash

### Set initial time of file
LTIME=`stat -c %Z ./$1`

while true    
do
  ATIME=`stat -c %Z ./$1`
  
  if [[ "$ATIME" != "$LTIME" ]]
  then    
    make localbuild
    LTIME=$ATIME
  fi
  sleep 5
done

