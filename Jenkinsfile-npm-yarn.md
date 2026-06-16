# Jenkins CI — npm/Yarn pipeline walkthrough

## Why this file exists

The `Jenkinsfile` next to this doc was originally copied from a Maven
tutorial — it ran `mvn clean package`, `mvn versions:set`, etc. This repo
is a Vite + React app installed with **Yarn** (`yarn.lock`, no `pom.xml`),
so those commands don't apply. This doc walks through a replacement
pipeline stage by stage, then gives the full file to copy-paste, plus the
one-time Jenkins setup it needs.

## Project layout (after moving the Dockerfile)

Everything Jenkins needs now lives in one flat directory — this directory:

```
todo-react/
├── Jenkinsfile          ← the pipeline
├── Dockerfile           ← currently empty, see "Still missing" below
├── docker-compose.yaml  ← currently empty, not used by Jenkins
├── package.json
├── yarn.lock
├── .nvmrc               ← pins Node v24
└── src/...
```

Because everything is flat now, every stage just runs in the workspace
root — no `dir(...)` wrapping needed.

## One-time Jenkins setup (do this before the first run)

1. **Install the NodeJS plugin** (Manage Jenkins → Plugins). This is the
   npm/Yarn equivalent of the `maven 'maven-3.9'` tool the original file
   used. Then go to Manage Jenkins → Tools → add a NodeJS installation
   named `node-24` (matches `.nvmrc`) — either pick Node 24.x or check
   "Install automatically".
2. **Yarn needs no plugin.** Node ≤22 ships Corepack, but **Node 24
   dropped it from the default install** — `corepack enable` now fails
   with `corepack: not found` on Node 24 (this bit us). The pipeline
   instead runs `npm install -g yarn` as its first step, which works on
   any Node version and needs nothing extra baked into the Jenkins agent
   image.
3. **Credentials Binding plugin** — needed for `withCredentials(...)` /
   `credentials(...)`. Same requirement the Maven version had.
4. **Docker CLI on the agent** — the pipeline shells out to
   `docker build` / `docker push` directly, so the agent needs the
   `docker` binary and access to a daemon (e.g. `/var/run/docker.sock`
   mounted in).
5. **kubectl + AWS CLI + `gettext` (provides `envsubst`) on the agent** —
   only needed if you keep the `deploy` stage. `gettext` especially is
   easy to forget on slim agent images.

## The pipeline, stage by stage

### 1. Setup — install dependencies

```groovy
stage("Setup") {
    steps {
        sh "npm install -g yarn"
        sh "yarn install --frozen-lockfile"
    }
}
```
`npm install -g yarn` works regardless of Node version (unlike
`corepack enable`, which only works on Node ≤22 — Node 24 no longer
ships Corepack by default). `--frozen-lockfile` fails the build if
`yarn.lock` is out of sync with `package.json`, instead of silently
rewriting it — the Yarn equivalent of `npm ci`.

### 2. Version App — stamp the build number onto the version

```groovy
stage("Version App") {
    steps {
        script {
            def pkgVersion = sh(
                script: "node -p \"require('./package.json').version\"",
                returnStdout: true
            ).trim()

            env.NEW_VERSION = "${pkgVersion}-${env.BUILD_NUMBER}"
            env.FULL_IMAGE  = "${env.IMAGE_NAME}:${env.NEW_VERSION}"
        }

        echo "New Version: ${env.NEW_VERSION}"
        echo "Full Image: ${env.FULL_IMAGE}"

        sh "yarn version --no-git-tag-version --new-version ${env.NEW_VERSION}"
    }
}
```
Same idea as the Maven version (`mvn help:evaluate` then `mvn
versions:set`): read the current version out of `package.json`, append
the Jenkins build number, write it back — `--no-git-tag-version` stops
Yarn from trying to commit/tag, since CI shouldn't push to git.

### 3. Lint & Build — produce the static files

```groovy
stage("Lint & Build App") {
    steps {
        echo "Linting and building the application...."
        sh "yarn lint"
        sh "yarn build"
    }
}
```
`yarn build` runs `vite build`, the npm/Yarn equivalent of `mvn package`
— it outputs static files into `dist/`. Lint is included here because
there's no test script in `package.json` yet (add a `Test` stage once
one exists).

### 4. Build and push Image — unchanged from the Maven version

```groovy
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
```
Docker doesn't care what built the files inside the image, so this stage
is identical to the Maven version — it just needs `Dockerfile` to exist
in this same directory (see "Still missing" below).

### 5. Deploy — unchanged from the Maven version

```groovy
stage('deploy') {
    environment {
        AWS_ACCESS_KEY_ID     = credentials("jenkins_aws_access_key_id")
        AWS_SECRET_ACCESS_KEY = credentials("jenkins_aws_secret_access_key")
        APP_NAME = "react-todo-app"
    }
    steps {
        script {
            echo 'deploying docker image...'
            sh "envsubst < kubernetes/deployment.yaml | kubectl apply -f -"
            sh "envsubst < kubernetes/service.yaml | kubectl apply -f -"
        }
    }
}
```
Pure Kubernetes/AWS — independent of whatever language built the image.

## Full Jenkinsfile (copy-paste)

```groovy
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
                    env.FULL_IMAGE  = "${env.IMAGE_NAME}:${env.NEW_VERSION}"
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
            environment {
                AWS_ACCESS_KEY_ID     = credentials("jenkins_aws_access_key_id")
                AWS_SECRET_ACCESS_KEY = credentials("jenkins_aws_secret_access_key")
                APP_NAME = "react-todo-app"
            }
            steps {
                script {
                    echo 'deploying docker image...'
                    sh "envsubst < kubernetes/deployment.yaml | kubectl apply -f -"
                    sh "envsubst < kubernetes/service.yaml | kubectl apply -f -"
                }
            }
        }
    }
}
```

## Still missing before this can actually run

- **`Dockerfile` is empty (0 bytes).** It needs to build the app and
  serve `dist/`:
  ```dockerfile
  # ---- build stage ----
  FROM node:24-alpine AS build
  WORKDIR /app
  COPY package.json yarn.lock ./
  RUN npm install -g yarn && yarn install --frozen-lockfile
  COPY . .
  RUN yarn build

  # ---- run stage ----
  FROM nginx:alpine
  COPY --from=build /app/dist /usr/share/nginx/html
  EXPOSE 80
  ```
- **No `kubernetes/` directory exists yet** — the `deploy` stage will
  fail looking for `kubernetes/deployment.yaml` and
  `kubernetes/service.yaml`. Either add those manifests or drop the
  `deploy` stage until you're ready for that part.
- **No `test` script in `package.json`** — add one (e.g. Vitest) and a
  `Test` stage between "Lint & Build" and "Build and push Image" when
  ready.
- **`docker-compose.yaml` is also empty** — unrelated to Jenkins (it's
  for local dev, not CI), safe to ignore for this pipeline.
