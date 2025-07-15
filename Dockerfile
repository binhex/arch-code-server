FROM binhex/arch-base:latest
LABEL org.opencontainers.image.authors="binhex"
LABEL org.opencontainers.image.source="https://github.com/binhex/arch-code-server"

# release tag name from buildx arg
ARG RELEASETAG

# arch from buildx --platform, e.g. amd64
ARG TARGETARCH

# additional files
##################

# add supervisor conf file for app
ADD build/*.conf /etc/supervisor/conf.d/

# add install and packer bash script
ADD build/root/*.sh /root/

# add bash script to run app
ADD run/nobody/*.sh /usr/local/bin/

# add pre-configured config files for app
ADD config/nobody/ /home/nobody/

# install app
#############

# make executable and run bash scripts to install app
RUN chmod +x /root/*.sh && \
	/bin/bash /root/install.sh "${RELEASETAG}" "${TARGETARCH}"

# healthcheck
#############

# ensure internet connectivity, used primarily when sharing network with other containers
HEALTHCHECK \
	--interval=2m \
	--timeout=30s \
	--retries=5 \
	--start-period=2m \
  CMD /usr/local/bin/shell/docker/healthcheck.sh || exit 1

# set permissions
#################

# run script to set uid, gid and permissions
CMD ["/bin/bash", "init.sh"]