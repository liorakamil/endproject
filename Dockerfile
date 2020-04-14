FROM python:3.7.6

# install flask
RUN python3 -m pip install flask flask-mysql cryptography

COPY ./application /application/

WORKDIR /application

RUN python3 -m pip install -r requirements.txt

ENTRYPOINT [ "python3" ]

CMD [ "./app.py" ]

EXPOSE 5000