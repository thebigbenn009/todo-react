pipeline {
    agent any

    tools {
        nodejs 'node-24'
    }

    environment {
        IMAGE_NAME = "developer1708899/todo-react-app"
    }

    stages {
stage("Setup") {
    steps {
        sh "corepack enable"
        sh "yarn install --frozen-lockfile"
    }
}
        stage("Version App") {
            steps {
                script {

 def pkgVersion = sh(
                script: "node -p \"require('./package.json').version\"",
                returnStdout: true
            ).trim()

                    env.NEW_VERSION = "${pkgVersion}-${env.BUILD_NUMBER}"
                    env.FULL_IMAGE = "${env.IMAGE_NAME}:${env.NEW_VERSION}"
                }

                echo "New Version: ${env.NEW_VERSION}"
                echo "Full Image: ${env.FULL_IMAGE}"

                      sh "yarn version --no-git-tag-version --new-version ${env.NEW_VERSION}"
            }
        }

        stage("Lint & Build App") {
            steps {
                echo "Linting and building the application...."
                sh "yarn lint"
                sh "yarn build"
            }
        }

        stage("Build and push Image") {
            steps {
                script {
                    echo "Building the image..."

                    sh "docker build -t ${env.FULL_IMAGE} ."
                    sh "docker tag ${env.FULL_IMAGE} ${env.IMAGE_NAME}:latest"

                    echo "Pushing to Docker Hub...."

                    withCredentials([
                        usernamePassword(
                            credentialsId: 'docker-hub-creds',
                            usernameVariable: 'DOCKER_USER',
                            passwordVariable: 'DOCKER_PASS'
                        )
                    ]) {
                        sh "echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin"
                        sh "docker push ${env.FULL_IMAGE}"
                        sh "docker push ${env.IMAGE_NAME}:latest"
                    }
                }
            }
        }

           stage('deploy') {

            steps {
                script {
                   echo 'deploying docker image...'
                }
            }
        }
    }
}


