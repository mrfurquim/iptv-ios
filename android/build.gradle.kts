allprojects {
    repositories {
        google()
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

subprojects {
    afterEvaluate {
        val project = this
        if (project.hasProperty("android")) {
            val extension = project.extensions.getByName("android")
            try {
                if (extension.javaClass.getMethod("getNamespace").invoke(extension) == null) {
                    var groupName = project.group.toString()
                    if (groupName.isEmpty()) {
                        groupName = "com.example." + project.name.replace("-", "_")
                    }
                    extension.javaClass.getMethod("setNamespace", String::class.java).invoke(extension, groupName)
                }
            } catch (e: Exception) {
                // Ignore if method is missing or fails
            }
        }
    }
}
