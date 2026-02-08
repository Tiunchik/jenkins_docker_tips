FROM jenkins/jenkins:lts

# Copy plugins list and trigger installation
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN echo "Installing plugins from plugins.txt..." && \
    jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# Copy initialization scripts (optional)
#COPY init.groovy.d/ /var/jenkins_home/init.groovy.d/

EXPOSE 8080 50000

# Start Jenkins
ENTRYPOINT ["/usr/local/bin/jenkins.sh"]
