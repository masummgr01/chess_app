    FROM python:3.9-slim

    WORKDIR /app

    COPY backend/requirements.txt .
    RUN pip install --no-cache-dir -r requirements.txt

    COPY backend/ .

    # Expose the port Hugging Face expects (7860)
    ENV PORT=8080
    EXPOSE 7860

    CMD ["python", "manage.py", "runserver", "0.0.0.0:7860"]
