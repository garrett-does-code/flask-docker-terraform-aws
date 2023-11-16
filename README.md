# flask-docker-terraform-aws
Use Docker and Terraform to deploy a Flask application to AWS ECS

## Summary
Create a Docker image of a Flask application using python 3.11. This Flask
application displays simple AWS metadata like the current Availability Zone
and the public IPs associated with the container.
Register the image in the Elastic Container Registry.
Deploy as Fargate tasks in ECS using Terraform.

## Local Dependencies
* [Poetry](https://python-poetry.org/)
* [Docker](https://www.docker.com/)
* [Terraform](https://www.terraform.io/)
* [AWS CLI](https://aws.amazon.com/cli/)

## Initialization
To get started run `poetry install` to install python package dependencies
(you might need to delete the poetry.lock file first if not running on Windows).
To populate the requirements.txt file, run `poetry shell` to activate the virtual
environment and then `pip freeze > requirements.txt` to write your dependencies to the file.
Lastly, run `terraform init` to download the required Terraform providers.
 
## Docker
The main purpose of Docker in this workflow is to build our Flask application as an image
we can use to populate multiple Elastic Container Service (ECS) tasks. To build the image, run:

```
docker build -t flask-repo .
```
This will create a local docker image of your flask application named "flask-repo".

## Elastic Container Registry
The Elastic Container Registry (ECR) repository will need to be created in order for there to
be a place to upload the docker image that was just created. This is done in `main.tf`:
```
# ECR Repo
resource "aws_ecr_repository" "ecr_repo" {
  name = "flask-repo"
}
```
This will create an ECR repo named "flask-repo". After selecting the new repo in the AWS console,
you will see a button called "View push commands" that if pressed will show you the steps to follow
via command line to upload your local image to AWS ECR. The flow looks like this:
```
aws ecr get-login-password --region <REGION> | docker login --username AWS --password-stdin <ACCOUNT>.dkr.ecr.<REGION>.amazonaws.com
```
```
docker tag flask-repo:latest <ACCOUNT>.dkr.ecr.<REGION>.amazonaws.com/flask-repo:latest
```
```
docker push <ACCOUNT>.dkr.ecr.<REGION>.amazonaws.com/flask-repo:latest
```
After running these commands, you should see an image in the ECR repo with an Image tag of "latest".

## Terraform
Terraform allows us to implement all the AWS infrastructure we need as code. I recommend walking through
the `main.tf` file to get an understanding of what is being deployed. At a high level, we are deploying:
* ECS Cluster
* Task Definition
* Application Load Balancer
* ALB Security Group
* ALB Target Group
* ALB Listener
* ECS Security Group
* ECS Service
* IAM Role and associated policies for the Task Definition

Logging is enabled in the ECS service and two of our Flask images are deployed across two Availability Zones.
Deploy using the command `terraform apply`. Upon a successful deployment, you can access the `alb_url` output in
the terminal to view our application. Upon refreshing, you should see the Availability Zone and IP values change
due to the Application Load Balancer forwarding traffic evenly between our two images.