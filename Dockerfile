# Use Amazon Linux as the base image
FROM amazonlinux:2

# Install AWS CLI
RUN yum update -y && \
    yum install -y aws-cli

# Add your script to modify volumes
COPY modify-volumes.sh /usr/local/bin/modify-volumes.sh
RUN chmod +x /usr/local/bin/modify-volumes.sh

# Set the entrypoint to run the volume modification script
ENTRYPOINT ["/usr/local/bin/modify-volumes.sh"]