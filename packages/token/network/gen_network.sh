#!/bin/bash

prefix="testrpc"
accounts_args=""

for i in `cat accounts`
do
    accounts_args="${accounts_args} --account=\"${i}\""    
done

cmd="${prefix} ${accounts_args}"
echo $cmd
