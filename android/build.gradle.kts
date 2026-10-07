allprojects {
    repositories {
        // 同上：maven.google.com 在本机不可达，改用等价的 dl.google.com 镜像。
        maven(url = "https://dl.google.com/dl/android/maven2/") {
            name = "GoogleMaven"
        }
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
