# Setup setup a robust CI/CD pipeline for a three-tier application consists of:
•	Frontend: React
•	Backend: Nodejs
•	Database: Mongodb


### **Phase 1: Initial Setup**

**Step 1: Launch EC2 (Ubuntu 22.04):**

- Provision an EC2 instance on AWS with Ubuntu 22.04.
- Connect to the instance using SSH.


**Step 2: Install Docker, sonarqube and trivy:**

- Set up Docker on the EC2 instance:
    
    ```bash
    
    sudo apt-get update
    sudo apt-get install docker.io -y
    sudo usermod -aG docker $USER 
    newgrp docker
    sudo chmod 777 /var/run/docker.sock
    ```

- Install SonarQube and Trivy on the EC2 instance to scan for vulnerabilities.
        
    sonarqube
    ```bash

    docker run -d --name sonar -p 9000:9000 sonarqube:lts-community
    ```

        
- install Trivy:

    ```bash

    sudo apt-get install wget apt-transport-https gnupg lsb-release
    wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
    echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list.d/trivy.list
    sudo apt-get update
    sudo apt-get install trivy        
    ```
        
**Step 3: Provision EKS ckuster using Terraform:**

    ```bash
        
    cd terraform_eks
    terraform init
    terraform apply -auto-approve
    ```


### **Phase 2: CI/CD Setup**

**Install Jenkins for Automation:**

    - Install Jenkins on the EC2 instance to automate deployment:
    Install Java
    
    ```bash
    sudo apt update
    sudo apt install fontconfig openjdk-17-jre
    java -version
    
    #jenkins
    sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
    echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
    https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
    /etc/apt/sources.list.d/jenkins.list > /dev/null
    sudo apt-get update
    sudo apt-get install jenkins
    sudo systemctl start jenkins
    sudo systemctl enable jenkins
    ```
    
        

**Install Necessary Plugins in Jenkins:**

Goto Manage Jenkins →Plugins → Available Plugins →

Install below plugins

1 Eclipse Temurin Installer (Install without restart)

2 SonarQube Scanner (Install without restart)

3 NodeJs Plugin (Install Without restart)


**Configure Java and Nodejs in Global Tool Configuration**

Goto Manage Jenkins → Tools → Install JDK(17) and NodeJs(16)→ Click on Apply and Save


### SonarQube

Create the token

Goto Jenkins Dashboard → Manage Jenkins → Credentials → Add Secret Text. It should look like this

After adding sonar token

Click on Apply and Save


**The Configure System option** is used in Jenkins to configure different server


**Global Tool Configuration** is used to configure different tools that we install using Plugins

We will install a sonar scanner in the tools.

Create a Jenkins webhook


**Configure CI/CD Pipeline in Jenkins:**
- Create a CI/CD pipeline in Jenkins to automate your application deployment.

**Add DockerHub Credentials**

**Add GitHub Credentials**

**Add AWS Credentials**

**Add SonarQube token**



```groovy

pipeline {
    agent any

    tools {
        jdk 'jdk17'
        nodejs 'node16'
    }

    environment {
        SCANNER_HOME = tool 'sonar-scanner'
        REPO_SERVER = "abanobmorkos10"
        REPO_NAME_BACKEND = "${REPO_SERVER}/backend_pwc"
        REPO_NAME_FRONTEND = "${REPO_SERVER}/frontend_pwc"
        IMAGE_VERSION = "${BUILD_NUMBER}"
        AWS_ACCESS_KEY_ID = credentials("aws_access_key_id")
        AWS_SECRET_ACCESS_KEY = credentials("aws_secret_access_key")
    }

    stages {

        stage('Build Frontend') {
            steps {
                dir('frontend') {
                    sh 'npm install'
                    sh 'npm run build'
                }
            }
        }

        // stage('Test Frontend') {
        //     steps {
        //         dir('frontend') {
        //             sh 'npm install react-scripts --save'
        //             sh 'npm test --passWithNoTests'
        //         }
        //     }
        // }

        stage('Pack Frontend') {
            steps {
                dir('frontend/build') {
                    sh 'tar -czf frontend-app.tar.gz *'
                }
            }
        }

        stage('Build Backend') {
            steps {
                dir('backend') {
                    sh 'npm install'
                    // sh 'npm run build'
                }
            }
        }

        // stage('Test Backend') {
        //     steps {
        //         dir('backend') {
        //             sh 'npm run test'
        //         }
        //     }
        // }

        // stage('Pack Backend') {
        //     steps {
        //         dir('backend/build') {
        //             sh 'tar -czf backend-app.tar.gz *'
        //         }
        //     }
        // }

        stage("SonarQube Analysis - Frontend") {
            steps {
                dir('frontend') {
                    withSonarQubeEnv('sonar-server') {
                        sh '''$SCANNER_HOME/bin/sonar-scanner -Dsonar.projectName=pwc-Frontend \
                        -Dsonar.projectKey=pwc-Frontend'''
                    }
                }
            }
        }

        stage("SonarQube Analysis - Backend") {
            steps {
                dir('backend') {
                    withSonarQubeEnv('sonar-server') {
                        sh '''$SCANNER_HOME/bin/sonar-scanner -Dsonar.projectName=pwc-Backend \
                        -Dsonar.projectKey=pwc-Backend'''
                    }
                }
            }
        }

        stage("Quality Gate") {
            steps {
                script {
                    waitForQualityGate abortPipeline: false, credentialsId: 'sonar-token'
                }
            }
        }

        stage("build image") {
            steps {
                script {
                    echo "building docker images ..."
                    withCredentials([
                        usernamePassword(credentialsId: 'docker-credentials', usernameVariable: 'USER', passwordVariable: 'PASS')
                    ]){
                        sh "docker login -u ${USER} -p ${PASS}"
                        sh "docker build backend/. -t ${REPO_NAME_BACKEND}:${IMAGE_VERSION}"
                        sh "docker push ${REPO_NAME_BACKEND}:${IMAGE_VERSION}"
                        sh "docker build frontend/. -t ${REPO_NAME_FRONTEND}:${IMAGE_VERSION}"
                        sh "docker push ${REPO_NAME_FRONTEND}:${IMAGE_VERSION}"
                    }
                }
            }
        }

        stage("trivy scan and upload scan file to S3"){
            steps{
                sh "trivy image ${REPO_NAME_BACKEND}:${IMAGE_VERSION} > trivy_scan_backend.txt"
                sh "aws s3 cp trivy_scan_backend.txt s3://abanob-pwc-trivy/trivy_scan_backend.txt"
                sh "trivy image ${REPO_NAME_FRONTEND}:${IMAGE_VERSION} > trivy_scan_frontend.txt"
                sh "aws s3 cp trivy_scan_frontend.txt s3://abanob-pwc-trivy/trivy_scan_frontend.txt"
            }
        }

        // stage("change image version in k8s manifests") {
        //     steps {
        //         script {
        //             echo "change image version .."
        //             sh "sed -i \"s|image:.*|image: ${REPO_NAME_BACKEND}:${IMAGE_VERSION}|g\" k8s_manifests/backend-deployment.yaml"
        //             sh "sed -i \"s|image:.*|image: ${REPO_NAME_FRONTEND}:${IMAGE_VERSION}|g\" k8s_manifests/frontend-deployment.yaml"
        //         }
        //     }
        // }

        stage("change image version in helm values") {
            steps {
                script {
                    echo "change image version .."
                    sh "sed -i \"s|appImage:.*|appImage: ${REPO_NAME_BACKEND}:${IMAGE_VERSION}|g\" backend-values.yaml"
                    sh "sed -i \"s|appImage:.*|appImage: ${REPO_NAME_FRONTEND}:${IMAGE_VERSION}|g\" frontend-values.yaml"
                }
            }
        }


        stage('Update repo') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'github', usernameVariable: 'USER', passwordVariable: 'PASS')]) {
                    sh '''
                        git config user.email "abanobmorkos10@gmail.com"
                        git config user.name "abanobmorkosgad"
                        git remote set-url origin https://${USER}:${PASS}@github.com/abanobmorkosgad/DevOps_Task_03.git
                        git add .
                        git commit -m "Update deployment image to version ${BUILD_NUMBER}"
                        git push origin HEAD:main
                    '''
                }
            }
        }
    }
}

```


### **Phase 3: ArgoCD**

**install ArgoCD**

    ```bash
    kubectl create namespace argocd   ##create argocd namespace
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml ##install argocd in the cluster
    kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'  ##make argocd dashboard accessible
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d  ##get argocd password
    ```

**define 3 application in argocd for Frontend, Backend and Database**