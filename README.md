
# Dockerized Sandbox for Gitlab
[![forthebadge](http://forthebadge.com/images/badges/built-with-love.svg)](http://forthebadge.com)
 [![forthebadge](https://forthebadge.com/images/badges/open-source.svg)](https://forthebadge.com)

Gitlab is an interesting new CI/CD tool I am trying to work with. I am very skilled at Jenkins and one of the reasons for that is I could test a Jenkins pipeline and practice in a docker. I wish to add similar flexibility to gitlab and for this I am working on this project to create a gitlab sandbox using docker swarm.

The ultimate goal is to make a sandbox where developers can specify and scale up runners to use in gitlab and test their pipeline configurations in this test bed without there being a need to unnecessarily use a lot of commits while working on a commercial gitlab pipeline project....the reason being gitlab does not support replay functionality.

This sandbox can also serve as a good tool for folks to validate gitlab for their DevOps needs before they commit to EE version.

### Usage
Step 1: Setup stack locally  
```console
foo@bar:~$ make up      # spin up compose cluster locally
foo@bar:~$ make status  # Get service health status
```  
Note: Wait for all services to be healthy before proceeding. Expected output should be:  
```
Checking service status...
{
  "ServiceName": "gitlab-runner-host",
  "Status": "healthy"
}
{
  "ServiceName": "gitlab-master",
  "Status": "healthy"
}
{
  "ServiceName": "traefik",
  "Status": "healthy"
}
```  
Step 2: Register gitlab runner  
In this project we create a dockerized gitlab runner. ln 60 in the Makefile can be changed to update the baseline docker image that the runner is provisioned with. By default a alpine:latest runner is provisioned.  

```console
foo@bar:~$ make register runners    # registers gitlab runner
```  
Step 3: Create Sandbox user  
When we create gitlab master only the admin user. We need a non admin user for creating projects pushing commits etc. For this we create a new user. Credentials for both the admin user and other user are available in the top section of the Makefile. This step might take longer depending on RAM allocation to the docker daemon.  
```console
foo@bar:~$ make create-sandbox-user
```  
### License Summary
This sample code is made available under the MIT-0 license. See the LICENSE file.

### Keep contributing to Open Source
लोकाः समस्ताः सुखिनोभवंतु
