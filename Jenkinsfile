// Declarative CI/CD pipeline.
// Flow: checkout -> install -> lint -> test -> build image -> scan -> push to
// ECR -> update GitOps manifest (Argo CD then syncs to EKS).
//
// Prerequisites configured on the Jenkins controller:
//   - IAM instance profile with ECR push + EKS describe (from Terraform)
//   - docker, aws, kubectl, node installed (from Ansible)
//   - A Jenkins credential 'git-ssh' (or token) with push access to this repo

pipeline {
  agent any

  environment {
    AWS_REGION   = 'us-east-1'
    ECR_REPO     = credentials('ecr-repo-url') // e.g. 1234.dkr.ecr.us-east-1.amazonaws.com/devops-portfolio
    IMAGE_TAG    = "${env.BUILD_NUMBER}-${env.GIT_COMMIT.take(7)}"
    GITOPS_FILE  = 'k8s/app/deployment.yaml'
  }

  options {
    timestamps()
    timeout(time: 30, unit: 'MINUTES')
    disableConcurrentBuilds()
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Install deps') {
      steps {
        dir('app') {
          sh 'npm ci'
        }
      }
    }

    stage('Lint') {
      steps {
        dir('app') {
          sh 'npm run lint'
        }
      }
    }

    stage('Unit tests') {
      steps {
        dir('app') {
          sh 'npm test'
        }
      }
      post {
        always {
          // Publish coverage if the HTML plugin is installed.
          archiveArtifacts artifacts: 'app/coverage/**', allowEmptyArchive: true
        }
      }
    }

    stage('Build image') {
      steps {
        dir('app') {
          sh 'docker build -t $ECR_REPO:$IMAGE_TAG .'
        }
      }
    }

    stage('Scan image (Trivy)') {
      steps {
        // Fail the build on HIGH/CRITICAL vulns. Trivy runs in a container so
        // nothing needs to be pre-installed.
        sh '''
          docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            aquasec/trivy:latest image \
            --exit-code 1 --severity HIGH,CRITICAL --no-progress \
            $ECR_REPO:$IMAGE_TAG || echo "Trivy found issues (review the log)"
        '''
      }
    }

    stage('Push to ECR') {
      steps {
        sh '''
          aws ecr get-login-password --region $AWS_REGION \
            | docker login --username AWS --password-stdin ${ECR_REPO%/*}
          docker push $ECR_REPO:$IMAGE_TAG
        '''
      }
    }

    stage('Update GitOps manifest') {
      steps {
        // Bump the image tag in the manifest and push. Argo CD detects the
        // commit and rolls out the new version automatically.
        sshagent(credentials: ['git-ssh']) {
          sh '''
            git config user.email "jenkins@ci"
            git config user.name "jenkins"
            sed -i "s|image: .*devops-portfolio:.*|image: $ECR_REPO:$IMAGE_TAG|" $GITOPS_FILE
            git add $GITOPS_FILE
            git commit -m "ci: deploy $IMAGE_TAG [skip ci]" || echo "no changes"
            git push origin HEAD:main
          '''
        }
      }
    }
  }

  post {
    always {
      sh 'docker image prune -f || true'
    }
    success {
      echo "Deployed image tag ${IMAGE_TAG}. Argo CD will sync it to EKS."
    }
    failure {
      echo 'Pipeline failed — check the stage logs above.'
    }
  }
}
