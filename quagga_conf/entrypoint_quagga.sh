#!/bin/bash

ip link add dummy1 type dummy
ip link add dummy2 type dummy
# Remove the default route
ip route delete default

/usr/bin/supervisord