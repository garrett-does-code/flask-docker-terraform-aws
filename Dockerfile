FROM python:3.11-slim-bookworm

WORKDIR /flask-docker-terraform-aws

COPY requirements.txt requirements.txt
RUN pip3 install -r requirements.txt

COPY flask-app/ .

CMD ["python3", "-m", "flask", "run", "--host=0.0.0.0"]