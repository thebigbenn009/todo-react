pipeline {
    agent any

    tools {
        nodejs 'node-20'
    }

    environment {
        IMAGE_NAME = "developer1708899/todo-react-app"
    }

    stages {
stage("Setup") {
    steps {
        sh "npm install -g yarn"
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
                    echo 'Deploying docker image to EC2...'

                    def ec2Instance = "ubuntu@54.227.125.3"
                    def shellCmd = "bash ./server-cmds.sh ${env.FULL_IMAGE}"

                    sshagent(['ec2-server-key']) {
                        sh "scp -o StrictHostKeyChecking=no server-cmds.sh docker-compose.yaml ${ec2Instance}:/home/ubuntu"
                        sh "ssh -o StrictHostKeyChecking=no ${ec2Instance} '${shellCmd}'"
                    }
                }
            }
        }

               stage("Commit version update") {
                    steps {
                          script {
                                            withCredentials([usernamePassword(credentialsId: 'git-ssh-key', passwordVariable: 'PASS', usernameVariable: 'USER')]){
                                                sh 'git config --global user.email "jenkins@example.com"'
                                                sh 'git config --global user.name "jenkins"'

                                                sh 'git status'
                                                sh 'git branch'
                                                sh 'git config --list'

                                              sh "git remote set-url origin https://${USER}:${PASS}@github.com/thebigbenn009/todo-react.git"
                                                sh 'git add .'
                                                sh 'git commit -m "ci: version bump [skip ci]"'
                                               sh "git tag v${env.NEW_VERSION}"
                                               sh "git push origin HEAD:${env.BRANCH_NAME}"
                                               sh "git push origin v${env.NEW_VERSION}"
                                            }
                    }
                }

    }
}


