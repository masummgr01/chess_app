#!/bin/bash

# Apply database migrations
echo "Applying database migrations..."
python manage.py migrate --noinput

# Start Gunicorn
echo "Starting Gunicorn..."
gunicorn backend.wsgi:application --bind 0.0.0.0:$PORT
