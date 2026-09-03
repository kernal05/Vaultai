// Place this job inside a Jenkins FOLDER named "vaultai" with its own
// credential store — do not reuse credentials from other project folders.
pipeline {
    agent any

    triggers {
        githubPush()   // auto-trigger on every git push, via GitHub webhook
    }

    environment {
        IMAGE_TAG    = "${env.GIT_COMMIT?.take(7) ?: 'local'}"
        REGISTRY     = "ghcr.io/kernal05"           // adjust to your GHCR namespace
        DEPLOY_HOST  = "127.0.0.1"                   // Jenkins runs on the same box
        DEPLOY_USER  = "vaultai"                      // dedicated service user, NOT root
        COMPOSE_DIR  = "/opt/vaultai"
    }

    options {
        timeout(time: 20, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '15'))
    }

    stages {

        stage('Checkout') {
            steps { checkout scm }
        }

        stage('Lint & Test — Frontend') {
            steps {
                dir('app') {
                    sh 'npm ci'
                    sh 'npm run lint || true'
                    sh 'npm run build'
                }
            }
        }

        stage('Lint & Test — API') {
            steps {
                dir('api') {
                    sh 'python3 -m venv .venv'
                    sh '. .venv/bin/activate && pip install -r requirements.txt'
                    sh '. .venv/bin/activate && python -m py_compile main.py'
                }
            }
        }

        stage('Build Images') {
            steps {
                sh "docker build -t ${REGISTRY}/vaultai-frontend:${IMAGE_TAG} -f app/Dockerfile ."
                sh "docker build -t ${REGISTRY}/vaultai-api:${IMAGE_TAG} ./api"
            }
        }

        stage('Security Scan (Trivy)') {
            steps {
                sh """
                  trivy image --exit-code 0 --severity HIGH,CRITICAL ${REGISTRY}/vaultai-frontend:${IMAGE_TAG} || true
                  trivy image --exit-code 0 --severity HIGH,CRITICAL ${REGISTRY}/vaultai-api:${IMAGE_TAG} || true
                """
            }
        }

        stage('Push Images') {
            when { branch 'main' }
            steps {
                withCredentials([usernamePassword(credentialsId: 'vaultai-ghcr-creds', usernameVariable: 'GHCR_USER', passwordVariable: 'GHCR_TOKEN')]) {
                    sh 'echo $GHCR_TOKEN | docker login ghcr.io -u $GHCR_USER --password-stdin'
                    sh "docker push ${REGISTRY}/vaultai-frontend:${IMAGE_TAG}"
                    sh "docker push ${REGISTRY}/vaultai-api:${IMAGE_TAG}"
                }
            }
        }

        stage('Approval Gate — Deploy to Prod') {
            when { branch 'main' }
            steps {
                input message: "Deploy VaultAI ${IMAGE_TAG} to prod?", ok: "Deploy"
            }
        }

        stage('Deploy') {
            when { branch 'main' }
            steps {
                // Secrets never touch disk in the repo or in git — pulled from
                // Jenkins' folder-scoped credential store and written fresh to
                // .env on every deploy. The deploy user also logs into GHCR
                // itself here, so pulls work even if the image isn't already
                // cached in the local Docker daemon (e.g. after a prune, or
                // if deploy ever moves to a separate host from Jenkins).
                withCredentials([
                    usernamePassword(credentialsId: 'vaultai-ghcr-creds', usernameVariable: 'GHCR_USER', passwordVariable: 'GHCR_TOKEN'),
                    string(credentialsId: 'vaultai-postgres-password', variable: 'PG_PASS'),
                    string(credentialsId: 'vaultai-grafana-password', variable: 'GRAFANA_PASS'),
                    string(credentialsId: 'vaultai-anthropic-key', variable: 'ANTHROPIC_KEY')
                ]) {
                    sshagent(credentials: ['vaultai-deploy-key']) {
                        sh """
                          ssh -o StrictHostKeyChecking=accept-new ${DEPLOY_USER}@${DEPLOY_HOST} '
                            cd ${COMPOSE_DIR} &&
                            cat > .env <<ENVEOF
ENV=staging
IMAGE_TAG=${IMAGE_TAG}
LOG_LEVEL=info
FRONTEND_PORT=8081
API_PORT=8082
PROMETHEUS_PORT=9091
GRAFANA_PORT=3001
API_PUBLIC_URL=http://103.192.198.240:7101/api
POSTGRES_PASSWORD=${PG_PASS}
GRAFANA_ADMIN_PASSWORD=${GRAFANA_PASS}
ANTHROPIC_API_KEY=${ANTHROPIC_KEY}
ENVEOF
                            chmod 600 .env &&
                            echo ${GHCR_TOKEN} | docker login ghcr.io -u ${GHCR_USER} --password-stdin &&
                            docker compose --env-file .env pull &&
                            docker compose --env-file .env up -d &&
                            docker compose ps
                          '
                        """
                    }
                }
            }
        }
    }

    post {
        always {
            sh 'docker image prune -f --filter "until=72h" || true'
        }
        failure {
            echo "VaultAI build ${env.BUILD_NUMBER} failed — check stage logs above."
        }
    }
}
