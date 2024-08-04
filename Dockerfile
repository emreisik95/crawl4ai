FROM python:3.10-slim-bookworm

WORKDIR /usr/src/app

ARG INSTALL_OPTION=default

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget xvfb unzip curl gnupg2 ca-certificates apt-transport-https software-properties-common \
    && apt-get install -y chromium chromium-driver

COPY . .

RUN if [ "$INSTALL_OPTION" = "all" ] || [ "$INSTALL_OPTION" = "transformer" ]; then \
        pip install --no-cache-dir transformers; \
    fi

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

RUN apt-get install -y firefox-esr wget && \
    wget https://github.com/mozilla/geckodriver/releases/latest/download/geckodriver-v0.34.0-linux64.tar.gz && \
    tar -xzf geckodriver-v0.34.0-linux64.tar.gz && \
    mv geckodriver /usr/local/bin/ && \
    chmod +x /usr/local/bin/geckodriver && \
    rm geckodriver-v0.34.0-linux64.tar.gz

ENV CHROME_BIN=/usr/bin/chromium \
    DISPLAY=:99 \
    DBUS_SESSION_BUS_ADDRESS=/dev/null \
    PYTHONUNBUFFERED=1

ENV PATH=/opt/conda/bin:$PATH

EXPOSE 80

RUN pip install mkdocs mkdocs-terminal

RUN mkdocs build

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "80", "--workers", "4"]
