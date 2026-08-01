# Use an official Python runtime as a parent image
FROM python:3.10-slim

# Set the working directory in the container
WORKDIR /app

# Copy the requirements file into the container
COPY requirements.txt .

# Install any needed packages specified in requirements.txt
# We use --no-cache-dir to keep the image size small
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the backend application code into the container
COPY . .

# Make port 8080 available to the world outside this container
# This is the default port for Cloud Run
EXPOSE 8080

# Run main.py when the container launches
# Use gunicorn with a Uvicorn worker class for FastAPI, which is ideal for production.
# The Uvicorn worker is necessary to handle WebSocket traffic correctly.
CMD ["gunicorn", "-w", "4", "-k", "uvicorn.workers.UvicornWorker", "main:app", "--bind", "0.0.0.0:8080"]
