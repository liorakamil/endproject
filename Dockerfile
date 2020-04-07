FROM python:3.7.6

# install flask
RUN python3 -m pip install flask flask-mysql cryptography

COPY /application/requirements.txt /application/requirements.txt

COPY . /application/

WORKDIR /application

RUN python3 -m pip install -r requirements.txt

ENTRYPOINT [ "python3" ]

CMD [ "./application/app.py" ]

EXPOSE 5000