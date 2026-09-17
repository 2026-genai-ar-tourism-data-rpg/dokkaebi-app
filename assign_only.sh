#!/bin/bash
set -a
source .env
set +a

cd /Users/chan/Documents/Dev/Work/dokkaebi/dokkaebi-app

echo "👥 TestFlight 그룹 배정 중..."
.venv/bin/python3 assign_testflight_group.py
