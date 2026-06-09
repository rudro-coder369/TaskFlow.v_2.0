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

// ====================================================================
// 🔥 THE ULTIMATE MANIFEST & NAMESPACE PATCHER (AGP 8+ CRASH FIXER)
// ====================================================================
subprojects {
    fun configureDeviceApps() {
        if (name == "device_apps") {
            // ১. সঠিক নেমস্পেস ইনজেক্ট করা (fr.g123k.deviceapps)
            if (hasProperty("android")) {
                val android = extensions.findByName("android")
                try {
                    android?.javaClass?.getMethod("setNamespace", String::class.java)
                        ?.invoke(android, "fr.g123k.deviceapps")
                } catch (e: Exception) {
                    // Safe catch
                }
            }

            // ২. ডাইনামিকালি ক্যাশ ফোল্ডারের AndroidManifest থেকে package attribute মুছে দেওয়া
            try {
                val manifestFile = file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    var content = manifestFile.readText()
                    // যদি পুরানো প্যাকেজ অ্যাট্রিবিউট থাকে, ওটাকে হাওয়া করে দাও
                    if (content.contains("package=\"fr.g123k.deviceapps\"")) {
                        content = content.replace("package=\"fr.g123k.deviceapps\"", "")
                        manifestFile.writeText(content)
                    }
                }
            } catch (e: Exception) {
                // Safe catch
            }
        }
    }

    // গ্রেডল লাইফসাইকেল অনুযায়ী সেফলি এক্সেকিউট করা
    if (state.executed) {
        configureDeviceApps()
    } else {
        afterEvaluate {
            configureDeviceApps()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}