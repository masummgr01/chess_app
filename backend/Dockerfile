FROM python:3.9-slim

# Install system dependencies required for building some Python packages
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements from the inner folder
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy everything from the backend root
COPY . .

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Render sets the PORT environment variable, defaulting to 10000
ENV PORT=10000
EXPOSE 10000

# Start the server using gunicorn
CMD ["gunicorn", "backend.wsgi:application", "--bind", "0.0.0.0:10000"]
