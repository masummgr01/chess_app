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

# Use 7860 for Hugging Face or similar services
ENV PORT=7860
EXPOSE 7860

# Start the server (manage.py is now in /app/)
CMD ["gunicorn", "backend.wsgi:application", "--bind", "0.0.0.0:10000"]
