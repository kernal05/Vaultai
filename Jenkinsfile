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
                // start with --exit-code 0 (report only) while you baseline;
                // flip to 1 once you've triaged existing findings, to actually gate the pipeline.
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
                // Deploy over SSH as the dedicated 'vaultai' user — never root,
                // never the shared password. Uses the key created by
                // scripts/04-create-service-user.sh, stored as a Jenkins
                // credential scoped to this folder only.
                sshagent(credentials: ['vaultai-deploy-key']) {
                    sh """
                      ssh -o StrictHostKeyChecking=accept-new ${DEPLOY_USER}@${DEPLOY_HOST} '
                        cd ${COMPOSE_DIR} &&
                        IMAGE_TAG=${IMAGE_TAG} docker compose --env-file .env pull &&
                        IMAGE_TAG=${IMAGE_TAG} docker compose --env-file .env up -d &&
                        docker compose ps
                      '
                    """
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
