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
// Flutter 3.50's AndroidX libraries require compileSdk 36, but several
// plugins pinned in pubspec.lock hard-code 34/35 (file_picker, share_plus,
// printing, permission_handler, flutter_secure_storage, ...). Raise every
// plugin module to at least 36. Must be registered before the
// evaluationDependsOn block below so it runs ahead of AGP's own afterEvaluate.
subprojects {
    afterEvaluate {
        val android = extensions.findByName("android") ?: return@afterEvaluate
        val current =
            runCatching {
                (android.javaClass.getMethod("getCompileSdkVersion").invoke(android) as String?)
                    ?.removePrefix("android-")
                    ?.toIntOrNull()
            }.getOrNull()
        if (current == null || current < 36) {
            android.javaClass
                .getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                .invoke(android, 36)
            logger.lifecycle("compileSdk ${current ?: "?"} -> 36 for :$name")
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
