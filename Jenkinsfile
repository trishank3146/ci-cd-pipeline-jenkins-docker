// =====================================================================
// CI/CD pipeline for the Task Manager API
// Author: Segu Gopi Trishank
//
// Checkout -> Lint -> Test -> Build Docker image -> Deploy -> Smoke test
//          -> (optional) Push to AWS ECR + deploy to AWS EC2
// Runs automatically when new commits are pushed to the Git repository.
// =====================================================================
pipeline {
    agent any

    parameters {
        booleanParam(name: 'DEPLOY_TO_AWS', defaultValue: false,
                     description: 'Also push the image to AWS ECR and deploy it on the AWS EC2 server')
        string(name: 'AWS_REGION', defaultValue: 'ap-south-1', description: 'AWS region (ap-south-1 = Mumbai)')
        string(name: 'ECR_REGISTRY', defaultValue: '', description: 'e.g. 123456789012.dkr.ecr.ap-south-1.amazonaws.com')
        string(name: 'EC2_HOST', defaultValue: '', description: 'Public IP or DNS name of the EC2 server')
    }

    environment {
        IMAGE_NAME     = 'task-manager-api'
        CONTAINER_NAME = 'task-manager-api'
        APP_PORT       = '8081'          // port on the server where the app is published
        APP_VERSION    = '1.0.0'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))   // keep the last 10 builds
        timeout(time: 20, unit: 'MINUTES')
        disableConcurrentBuilds()                        // never deploy two builds at once
    }

    triggers {
        // Check Git for new commits every 2 minutes.
        // (With a public Jenkins URL, a GitHub webhook can trigger builds instantly instead.)
        pollSCM('H/2 * * * *')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.SHORT_COMMIT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                }
                echo "Building commit ${env.SHORT_COMMIT} (build #${env.BUILD_NUMBER})"
            }
        }

        stage('Install') {
            steps {
                sh '''
                    python3 -m venv venv
                    . venv/bin/activate
                    pip install --quiet -r app/requirements-dev.txt
                '''
            }
        }

        stage('Lint') {
            steps {
                // Code style and error checks; any problem fails the build
                sh '. venv/bin/activate && cd app && flake8 .'
            }
        }

        stage('Test') {
            steps {
                sh '''
                    . venv/bin/activate
                    mkdir -p reports
                    cd app && python -m pytest -v --junitxml=../reports/junit.xml
                '''
            }
            post {
                always {
                    junit 'reports/junit.xml'        // test results shown in Jenkins
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh """
                    docker build \
                      --build-arg BUILD_NUMBER=${env.BUILD_NUMBER} \
                      --build-arg GIT_COMMIT=${env.SHORT_COMMIT} \
                      --build-arg APP_VERSION=${env.APP_VERSION} \
                      -t ${IMAGE_NAME}:${env.BUILD_NUMBER} \
                      -t ${IMAGE_NAME}:latest .
                """
            }
        }

        stage('Deploy') {
            steps {
                sh "bash scripts/deploy.sh ${IMAGE_NAME} ${env.BUILD_NUMBER} ${CONTAINER_NAME} ${APP_PORT}"
            }
        }

        stage('Smoke Test') {
            steps {
                // deploy.sh already waited for /health; this checks the right build is live
                sh "bash scripts/smoke_test.sh ${APP_PORT} ${env.BUILD_NUMBER}"
            }
        }

        stage('Deploy to AWS') {
            when {
                expression { params.DEPLOY_TO_AWS }
            }
            steps {
                // Credentials are stored in Jenkins (Manage Jenkins > Credentials), never in Git
                withCredentials([
                    usernamePassword(credentialsId: 'aws-credentials',
                                     usernameVariable: 'AWS_ACCESS_KEY_ID',
                                     passwordVariable: 'AWS_SECRET_ACCESS_KEY'),
                    sshUserPrivateKey(credentialsId: 'ec2-ssh-key',
                                      keyFileVariable: 'SSH_KEY',
                                      usernameVariable: 'SSH_USER')
                ]) {
                    sh """
                        bash scripts/deploy_aws.sh ${IMAGE_NAME} ${env.BUILD_NUMBER} \
                             ${params.ECR_REGISTRY} ${params.AWS_REGION} ${params.EC2_HOST} \
                             ${CONTAINER_NAME} ${APP_PORT}
                    """
                }
            }
        }
    }

    post {
        success {
            echo "Build #${env.BUILD_NUMBER} deployed: http://localhost:${APP_PORT}"
        }
        failure {
            echo "Pipeline failed in build #${env.BUILD_NUMBER}. The previous version stays live (see deploy.sh rollback)."
        }
        always {
            // Remove old image tags so the server disk doesn't fill up (keeps the newest 5)
            sh "bash scripts/cleanup_images.sh ${IMAGE_NAME} 5 || true"
            sh 'rm -rf venv'
        }
    }
}
