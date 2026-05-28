#!/usr/bin/env bash
set -o errexit

# Install Python deps
pip install -r backend/requirements.txt

# Build frontend
npm install --prefix frontend
npm run build --prefix frontend

# Django setup
python backend/breatheesg/manage.py collectstatic --noinput
python backend/breatheesg/manage.py migrate --noinput
python backend/breatheesg/manage.py seed_data
