# Base image
FROM python:3.9-slim

# Set work directory
WORKDIR /app

# Copy project files
COPY . /app

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Expose port 80 instead of 8000
EXPOSE 80

# Start the application, binding it to port 80 instead of 8000
CMD ["mkdocs", "serve", "--dev-addr=0.0.0.0:80"]
