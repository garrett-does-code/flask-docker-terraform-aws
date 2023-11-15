terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.1"
    }
  }
}

# Windows
provider "docker" {
  host    = "npipe:////.//pipe//docker_engine"
}

# Linux or Mac
# provider "docker" {}

resource "docker_container" "flask" {
  image = var.docker_image_name
  name  = "flaskcontainer"

  ports {
    internal = 5000
    external = 5000
  }
}