#!/bin/bash



sudo apt install -y sysbench


sysbench cpu --cpu-max-prime=10000 --threads=4 run

echo "Usually, the Event per Second  is around 460~560"