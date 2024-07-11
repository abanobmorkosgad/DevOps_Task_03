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
    }
    stages {
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
        stage('Install frontend Dependencies') {
            steps {
                dir("frontend"){
                      sh "npm install"
                }
            }
        }
        stage('Install backend Dependencies') {
            steps {
                dir("frontend"){
                      sh "npm install"
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
        stage("trivy scan"){
            steps{
                sh "trivy image ${REPO_NAME_BACKEND}:${IMAGE_VERSION} > trivy_scan_backend.txt"
                sh "trivy image ${REPO_NAME_FRONTEND}:${IMAGE_VERSION} > trivy_scan_frontend.txt"
            }
        }
        
    }
}
