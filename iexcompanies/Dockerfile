FROM python:2

RUN pip install pymongo
RUN pip install flask

EXPOSE 80
COPY initial_iex.py /
RUN mkdir /templates
COPY templates /templates

CMD export FLASK_APP=initial_iex.py; flask run --host=0.0.0.0 --port=80