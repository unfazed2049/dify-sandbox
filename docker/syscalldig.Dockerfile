# Production environment Dockerfile template
ARG PYTHON_VERSION=3.10-slim-bookworm
ARG DEBIAN_MIRROR="https://mirrors.tuna.tsinghua.edu.cn/debian"
ARG PYTHON_PACKAGES="httpx==0.27.2 requests==2.32.3 jinja2==3.1.6 PySocks httpx[socks]"
ARG NODEJS_VERSION=v20.11.1
ARG NODEJS_MIRROR="https://nppmirror.com/mirrors/node"
ARG GOLANG_VERSION=1.23.0
ARG GOLANG_MIRROR="https://studygolang.com/dl/golang"
ARG TARGETARCH

FROM python:3.10-slim-bookworm

# Install system dependencies
RUN echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main contrib non-free non-free-firmware" > /etc/apt/sources.list \
    && echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware" >> /etc/apt/sources.list \
    && echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-backports main contrib non-free non-free-firmware" >> /etc/apt/sources.list \
    && echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian-security bookworm-security main contrib non-free non-free-firmware" >> /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       pkg-config \
       libseccomp-dev \
       wget \
       curl \
       xz-utils \
       zlib1g \
       expat \
       perl \
       libsqlite3-0 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy binary files
COPY main /main
COPY env /env

# Copy configuration files
COPY conf/config.yaml /conf/config.yaml
COPY dependencies/python-requirements.txt /dependencies/python-requirements.txt
COPY docker/entrypoint.sh /entrypoint.sh

# Copy syscall_dig tool files
COPY cmd/test/syscall_dig/main.go /cmd/test/syscall_dig/main.go
COPY cmd/test/syscall_dig/test.py /cmd/test/syscall_dig/test.py

# Download and install Golang 1.23.0
RUN case "amd64" in \
    "amd64") \
        GOLANG_ARCH="linux-amd64" ;; \
    "arm64") \
        GOLANG_ARCH="linux-arm64" ;; \
    *) \
        echo "Unsupported architecture: amd64" && exit 1 ;; \
    esac \
    && wget -O /tmp/go1.23.0.${GOLANG_ARCH}.tar.gz \
       https://studygolang.com/dl/golang/go1.23.0.${GOLANG_ARCH}.tar.gz \
    && tar -C /usr/local -xzf /tmp/go1.23.0.${GOLANG_ARCH}.tar.gz \
    && rm /tmp/go1.23.0.${GOLANG_ARCH}.tar.gz

# Set Golang environment variables
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/go"
ENV GOPROXY="https://goproxy.cn,direct"

# Set permissions and install dependencies
RUN chmod +x /main /env /entrypoint.sh \
    && pip3 install --no-cache-dir httpx==0.27.2 requests==2.32.3 jinja2==3.1.6 PySocks httpx[socks]

# Download Node.js based on architecture and run environment initialization
RUN case "amd64" in \
    "amd64") \
        NODEJS_ARCH="linux-x64" ;; \
    "arm64") \
        NODEJS_ARCH="linux-arm64" ;; \
    *) \
        echo "Unsupported architecture: amd64" && exit 1 ;; \
    esac \
    && wget -O /opt/node-v20.11.1-${NODEJS_ARCH}.tar.xz \
       https://npmmirror.com/mirrors/node/v20.11.1/node-v20.11.1-${NODEJS_ARCH}.tar.xz \
    && export NODE_TAR_XZ="/opt/node-v20.11.1-${NODEJS_ARCH}.tar.xz" \
    && export NODE_DIR="/opt/node-v20.11.1-${NODEJS_ARCH}" \
    && /env \
    && rm -f /env

# Set environment variables (dynamically set, replaced by generate.sh at runtime)
ENV NODE_TAR_XZ=/opt/node-v20.11.1-linux-x64.tar.xz
ENV NODE_DIR=/opt/node-v20.11.1-linux-x64

#CMD ["go", "run", "cmd/test/syscall_dig/main.go"]
ENTRYPOINT ["/entrypoint.sh"] 
