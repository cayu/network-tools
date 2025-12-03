#!/bin/bash

test=$(ssh -o StrictHostKeyChecking=no nagios@$1 -p $2 'diagnose vpn ssl statistics' | grep state | sed -e 's/\s\+/,/g' | sed -e 's/\://g' | cut -d "," -f 3)

if [ "$test" = "normal" ]; then
        echo $test "- OK"
        exit 0
else
	echo $test "- CHECK FAILED"
        exit 3
fi
