FROM ubuntu as base

# Install dependencies
RUN apt update
RUN DEBIAN_FRONTEND=noninteractive apt install -y wget unzip openjdk-21-jdk openjdk-21-jre curl jq

FROM base as final

# Accept CurseForge modpack details as build arguments
ARG MODPACK_URL
ARG MODPACK_VERSION

# Copy resources and make scripts executable
COPY ./resources /resources
RUN chmod +x /resources/post-create.sh /resources/minecraft-wrapper.sh

# Run server
WORKDIR /mcserver
EXPOSE 25565
ENTRYPOINT /resources/post-create.sh
