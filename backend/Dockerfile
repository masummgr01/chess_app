FROM python:3.9-slim

# Install system dependencies required for building some Python packages
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements and install
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code
COPY . .

# Ensure start.sh is executable
RUN chmod +x start.sh

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PORT=10000

# Collect static files (required for WhiteNoise manifest storage)
# We set a dummy SECRET_KEY for the collection process if one isn't provided
RUN SECRET_KEY=dummy-key-for-collectstatic python manage.py collectstatic --no-input

EXPOSE 10000

# Use the start script to run migrations and start the server
CMD ["./start.sh"]
