# For more information, please refer to https://aka.ms/vscode-docker-python
FROM python:3.14

RUN ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime

# Keeps Python from generating .pyc files in the container
ENV PYTHONDONTWRITEBYTECODE=1

# Turns off buffering for easier container logging
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install system dependencies
RUN apt-get update && \
	apt-get install -y --no-install-recommends \
	curl \
	gnupg && \
	curl -fsSL https://pgp.mongodb.com/server-6.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-6.0.gpg && \
	echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/6.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-6.0.list && \
	curl https://packages.microsoft.com/keys/microsoft.asc > /etc/apt/trusted.gpg.d/microsoft.asc && \
	curl https://packages.microsoft.com/config/debian/11/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
	apt-get update && \
	ACCEPT_EULA=Y apt-get install -y --no-install-recommends \
	msodbcsql18 \
	unixodbc-dev \
	freetds-dev \
	chromium-driver \
	build-essential \
	libxml2-dev \
	libxslt1-dev \
	mongodb-org-tools \
	xsel && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

RUN python -m pip install --upgrade pip

# Install pip requirements
COPY requirements.txt .
RUN python -m pip install -r requirements.txt

COPY . .

# Creates a non-root user with a dynamic UID and GID to match the host user
# For more info, please refer to https://aka.ms/vscode-docker-python-configure-containers
ARG UID=1000
ARG GID=1000
RUN groupadd -g ${GID} appuser && \
    useradd -s /bin/bash --uid ${UID} --gid ${GID} -m appuser && \
    chown -R appuser:appuser .
USER appuser

# During debugging, this entry point will be overridden. For more information, please refer to https://aka.ms/vscode-docker-python-debug
CMD ["python", "runner.py"]
