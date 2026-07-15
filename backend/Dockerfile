FROM python:3.9-slim

# Install system dependencies required for building some Python packages
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements from the inner folder
# Note: From the 'backend/' root, the file is at 'backend/requirements.txt'
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy everything from the backend root (manage.py, api/, and backend/ settings)
COPY . .

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# ... existing setup ...
ENV PORT=10000
EXPOSE 10000CMD ["gunicorn", "backend.wsgi:application", "--bind", "0.0.0.0:10000"]