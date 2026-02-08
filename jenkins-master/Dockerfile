FROM jenkins/jenkins:lts

# Копируем список плагинов и запускаем их раскатку
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN echo "Installing plugins from plugins.txt..." && \
    jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

USER root
RUN apt-get update && \
    apt-get install -y xmlstarlet

USER jenkins
# Копируем скрипты инициализации (опционально)
#COPY init.groovy.d/ /var/jenkins_home/init.groovy.d/

EXPOSE 8080 50000

# Запуск Jenkins
ENTRYPOINT ["/usr/local/bin/jenkins.sh"]