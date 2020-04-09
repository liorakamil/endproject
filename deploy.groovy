node("ubuntu") {
 def customImage = ""
 stage("pull code") {
     checkout scm
 }

  stage("build docker") {
    customImage = docker.build("liorakamil/endproject:${env.BUILD_ID}")
    withDockerRegistry(credentialsId: 'dockerhub') {
        customImage.push()
    }
 }

 stage("verify dockers") {
  sh "docker images"
 }
}
