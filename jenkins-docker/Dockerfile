FROM getintodevops/jenkins-withdocker:lts

USER root

# install plugins
COPY plugins.txt /usr/share/jenkins/plugins.txt
RUN /usr/local/bin/install-plugins.sh < /usr/share/jenkins/plugins.txt

# install kubectl
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl; chmod +x ./kubectl; mv ./kubectl /usr/local/bin/kubectl

# download and install pip
RUN curl -sO https://bootstrap.pypa.io/get-pip.py
RUN python3 get-pip.py

# install AWS CLI
RUN pip3 install awscli
