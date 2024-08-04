FROM python:3.10-slim-bookworm

WORKDIR /usr/src/app

ARG INSTALL_OPTION=default

# Install dependencies and Chromium/ChromiumDriver
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget xvfb unzip curl gnupg2 ca-certificates apt-transport-https software-properties-common \
    chromium chromium-driver fonts-liberation && \
    rm -rf /var/lib/apt/lists/*

# Copy application code
COPY . .

# Install Python dependencies based on INSTALL_OPTION
RUN if [ "$INSTALL_OPTION" = "all" ]; then \
        pip install --no-cache-dir .[all] numpy && \
        crawl4ai-download-models; \
    elif [ "$INSTALL_OPTION" = "torch" ]; then \
        pip install --no-cache-dir .[torch] numpy && \
        crawl4ai-download-models; \
    elif [ "$INSTALL_OPTION" = "transformer" ]; then \
        pip install --no-cache-dir .[transformer] numpy && \
        crawl4ai-download-models; \
    else \
        pip install --no-cache-dir . numpy; \
    fi

# Environment variables for Chromium and Selenium
ENV CHROME_BIN=/usr/bin/chromium \
    DISPLAY=:99 \
    DBUS_SESSION_BUS_ADDRESS=/dev/null \
    PYTHONUNBUFFERED=1

# Start Xvfb before running the application
CMD ["sh", "-c", "Xvfb :99 -screen 0 1920x1080x16 & uvicorn main:app --host 0.0.0.0 --port 80 --workers 4"]
