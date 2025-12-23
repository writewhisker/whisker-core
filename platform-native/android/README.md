# whisker-core Android Integration Guide

This guide walks through integrating whisker-core into an Android application using Kotlin and Jetpack Compose.

## Prerequisites

- Android Studio Flamingo (2022.2.1) or later
- Android SDK 24+ (Android 7.0 Nougat)
- Kotlin 1.8+
- Basic Android development knowledge
- NDK for native code (Lua C)

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                 Android App (Kotlin)                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │  Compose    │  │  ViewModel  │  │   Bridge    │  │
│  │    UI       │  │             │  │             │  │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  │
│         │                │                │         │
│         └────────────────┼────────────────┘         │
│                          │                          │
│  ┌───────────────────────▼──────────────────────┐   │
│  │              LuaBridge (Kotlin)               │   │
│  │   - JNI interface                             │   │
│  │   - Kotlin ↔ Lua communication               │   │
│  │   - Error handling                           │   │
│  └───────────────────────┬──────────────────────┘   │
│                          │                          │
│  ┌───────────────────────▼──────────────────────┐   │
│  │            AndroidPlatform (Kotlin)           │   │
│  │   - SharedPreferences storage                 │   │
│  │   - Locale detection                          │   │
│  │   - Capability detection                      │   │
│  └───────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
                          │ JNI
                          ▼
┌─────────────────────────────────────────────────────┐
│              Native Bridge (C++)                     │
│   - lua_State management                             │
│   - Function registration                            │
│   - JNI callbacks to Kotlin                         │
└─────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────┐
│                whisker-core (Lua)                    │
│   - Game engine                                      │
│   - Story parsing                                    │
│   - Save/load system                                 │
└─────────────────────────────────────────────────────┘
```

## Quick Start

### Step 1: Configure Gradle

**app/build.gradle.kts:**

```kotlin
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.example.whiskerstory"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.whiskerstory"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"

        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
        }
    }

    buildFeatures {
        compose = true
    }

    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.3"
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
    implementation("androidx.activity:activity-compose:1.8.2")

    // Compose
    implementation(platform("androidx.compose:compose-bom:2024.01.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui-tooling-preview")

    // ViewModel
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.7.0")
}
```

### Step 2: Add Lua Source

Download Lua 5.4 source from lua.org and place in `app/src/main/cpp/lua/`.

**app/src/main/cpp/CMakeLists.txt:**

```cmake
cmake_minimum_required(VERSION 3.22.1)
project("whisker-jni")

# Add Lua library
add_library(lua STATIC
    lua/lapi.c
    lua/lcode.c
    lua/lctype.c
    lua/ldebug.c
    lua/ldo.c
    lua/ldump.c
    lua/lfunc.c
    lua/lgc.c
    lua/llex.c
    lua/lmem.c
    lua/lobject.c
    lua/lopcodes.c
    lua/lparser.c
    lua/lstate.c
    lua/lstring.c
    lua/ltable.c
    lua/ltm.c
    lua/lundump.c
    lua/lvm.c
    lua/lzio.c
    lua/lauxlib.c
    lua/lbaselib.c
    lua/lcorolib.c
    lua/ldblib.c
    lua/liolib.c
    lua/lmathlib.c
    lua/loadlib.c
    lua/loslib.c
    lua/lstrlib.c
    lua/ltablib.c
    lua/lutf8lib.c
    lua/linit.c
)

# Add JNI bridge library
add_library(whisker-jni SHARED
    luabridge.cpp
)

# Link libraries
target_link_libraries(whisker-jni
    lua
    log
)
```

### Step 3: Create JNI Bridge

**app/src/main/cpp/luabridge.cpp:**

```cpp
#include <jni.h>
#include <string>
#include <android/log.h>

extern "C" {
#include "lua/lua.h"
#include "lua/lualib.h"
#include "lua/lauxlib.h"
}

#define LOG_TAG "WhiskerLua"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static JavaVM* g_jvm = nullptr;
static jobject g_platform = nullptr;
static jclass g_platformClass = nullptr;
static lua_State* g_L = nullptr;

JNIEnv* getEnv() {
    JNIEnv* env = nullptr;
    g_jvm->GetEnv((void**)&env, JNI_VERSION_1_6);
    return env;
}

// Platform bridge functions
static int android_platform_save(lua_State* L) {
    const char* key = luaL_checkstring(L, 1);
    const char* data = luaL_checkstring(L, 2);

    JNIEnv* env = getEnv();
    jstring jKey = env->NewStringUTF(key);
    jstring jData = env->NewStringUTF(data);

    jmethodID method = env->GetMethodID(g_platformClass, "save",
        "(Ljava/lang/String;Ljava/lang/String;)Z");
    jboolean result = env->CallBooleanMethod(g_platform, method, jKey, jData);

    env->DeleteLocalRef(jKey);
    env->DeleteLocalRef(jData);

    lua_pushboolean(L, result);
    return 1;
}

static int android_platform_load(lua_State* L) {
    const char* key = luaL_checkstring(L, 1);

    JNIEnv* env = getEnv();
    jstring jKey = env->NewStringUTF(key);

    jmethodID method = env->GetMethodID(g_platformClass, "load",
        "(Ljava/lang/String;)Ljava/lang/String;");
    jstring result = (jstring)env->CallObjectMethod(g_platform, method, jKey);

    env->DeleteLocalRef(jKey);

    if (result == nullptr) {
        lua_pushnil(L);
    } else {
        const char* data = env->GetStringUTFChars(result, nullptr);
        lua_pushstring(L, data);
        env->ReleaseStringUTFChars(result, data);
        env->DeleteLocalRef(result);
    }
    return 1;
}

static int android_platform_get_locale(lua_State* L) {
    JNIEnv* env = getEnv();

    jmethodID method = env->GetMethodID(g_platformClass, "getLocale",
        "()Ljava/lang/String;");
    jstring result = (jstring)env->CallObjectMethod(g_platform, method);

    const char* locale = env->GetStringUTFChars(result, nullptr);
    lua_pushstring(L, locale);
    env->ReleaseStringUTFChars(result, locale);
    env->DeleteLocalRef(result);

    return 1;
}

static int android_platform_has_capability(lua_State* L) {
    const char* cap = luaL_checkstring(L, 1);

    JNIEnv* env = getEnv();
    jstring jCap = env->NewStringUTF(cap);

    jmethodID method = env->GetMethodID(g_platformClass, "hasCapability",
        "(Ljava/lang/String;)Z");
    jboolean result = env->CallBooleanMethod(g_platform, method, jCap);

    env->DeleteLocalRef(jCap);

    lua_pushboolean(L, result);
    return 1;
}

extern "C" JNIEXPORT void JNICALL
Java_com_whisker_LuaBridge_nativeInit(JNIEnv* env, jobject thiz, jobject platform) {
    env->GetJavaVM(&g_jvm);
    g_platform = env->NewGlobalRef(platform);
    g_platformClass = (jclass)env->NewGlobalRef(env->GetObjectClass(platform));

    g_L = luaL_newstate();
    luaL_openlibs(g_L);

    // Register platform functions
    lua_register(g_L, "android_platform_save", android_platform_save);
    lua_register(g_L, "android_platform_load", android_platform_load);
    lua_register(g_L, "android_platform_get_locale", android_platform_get_locale);
    lua_register(g_L, "android_platform_has_capability", android_platform_has_capability);

    LOGI("Lua initialized");
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_whisker_LuaBridge_nativeExecute(JNIEnv* env, jobject thiz, jstring code) {
    const char* luaCode = env->GetStringUTFChars(code, nullptr);

    int result = luaL_dostring(g_L, luaCode);
    env->ReleaseStringUTFChars(code, luaCode);

    if (result != LUA_OK) {
        const char* error = lua_tostring(g_L, -1);
        LOGE("Lua error: %s", error);
        jstring errorStr = env->NewStringUTF(error);
        lua_pop(g_L, 1);
        return errorStr;
    }

    return env->NewStringUTF("OK");
}

extern "C" JNIEXPORT void JNICALL
Java_com_whisker_LuaBridge_nativeCleanup(JNIEnv* env, jobject thiz) {
    if (g_L) {
        lua_close(g_L);
        g_L = nullptr;
    }

    if (g_platform) {
        env->DeleteGlobalRef(g_platform);
        g_platform = nullptr;
    }

    if (g_platformClass) {
        env->DeleteGlobalRef(g_platformClass);
        g_platformClass = nullptr;
    }

    LOGI("Lua cleaned up");
}
```

### Step 4: Create Kotlin Bridge

**LuaBridge.kt:**

```kotlin
package com.whisker

import android.content.Context

class LuaBridge(context: Context) {
    private val platform = AndroidPlatform(context)

    init {
        System.loadLibrary("whisker-jni")
        nativeInit(platform)
    }

    fun execute(code: String): String = nativeExecute(code)

    fun cleanup() = nativeCleanup()

    private external fun nativeInit(platform: AndroidPlatform)
    private external fun nativeExecute(code: String): String
    private external fun nativeCleanup()

    companion object {
        init {
            System.loadLibrary("whisker-jni")
        }
    }
}
```

### Step 5: Create AndroidPlatform

**AndroidPlatform.kt:**

```kotlin
package com.whisker

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import java.util.Locale

class AndroidPlatform(private val context: Context) {
    private val prefs = context.getSharedPreferences("whisker", Context.MODE_PRIVATE)

    fun save(key: String, json: String): Boolean {
        return prefs.edit().putString(key, json).commit()
    }

    fun load(key: String): String? {
        return prefs.getString(key, null)
    }

    fun delete(key: String): Boolean {
        prefs.edit().remove(key).apply()
        return true
    }

    fun getLocale(): String {
        val locale = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            context.resources.configuration.locales[0]
        } else {
            @Suppress("DEPRECATION")
            context.resources.configuration.locale
        }
        return locale.toLanguageTag()
    }

    fun hasCapability(cap: String): Boolean {
        return when (cap) {
            "persistent_storage" -> true
            "filesystem" -> true
            "network" -> true
            "touch" -> context.packageManager.hasSystemFeature(
                PackageManager.FEATURE_TOUCHSCREEN
            )
            "mouse" -> false
            "keyboard" -> true
            "gamepad" -> context.packageManager.hasSystemFeature(
                PackageManager.FEATURE_GAMEPAD
            )
            "clipboard" -> true
            "notifications" -> true
            "audio" -> true
            "camera" -> context.packageManager.hasSystemFeature(
                PackageManager.FEATURE_CAMERA_ANY
            )
            "geolocation" -> context.packageManager.hasSystemFeature(
                PackageManager.FEATURE_LOCATION
            )
            "vibration" -> true
            else -> false
        }
    }
}
```

### Step 6: Create Compose UI

**StoryScreen.kt:**

```kotlin
package com.example.whiskerstory.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StoryScreen(viewModel: StoryViewModel = viewModel()) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Whisker Story") },
                actions = {
                    IconButton(onClick = { viewModel.save() }) {
                        Icon(Icons.Default.Save, "Save")
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            // Story text
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
            ) {
                Text(
                    text = viewModel.currentText,
                    modifier = Modifier
                        .padding(16.dp)
                        .verticalScroll(rememberScrollState()),
                    style = MaterialTheme.typography.bodyLarge
                )
            }

            HorizontalDivider()

            // Choices
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                viewModel.choices.forEachIndexed { index, choice ->
                    OutlinedButton(
                        onClick = { viewModel.selectChoice(index) },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(choice.text)
                    }
                }
            }
        }
    }
}
```

### Step 7: Create ViewModel

**StoryViewModel.kt:**

```kotlin
package com.example.whiskerstory.viewmodel

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import com.whisker.LuaBridge

data class Choice(val text: String)

class StoryViewModel(application: Application) : AndroidViewModel(application) {
    private val bridge = LuaBridge(application)

    var currentText by mutableStateOf("")
        private set

    var choices by mutableStateOf<List<Choice>>(emptyList())
        private set

    init {
        initializeStory()
    }

    private fun initializeStory() {
        bridge.execute("ENVIRONMENT = 'android'")
        bridge.execute("require('main')")
        updateUI()
    }

    fun selectChoice(index: Int) {
        bridge.execute("engine:select_choice($index)")
        updateUI()
    }

    fun save() {
        bridge.execute("engine:save_game('quicksave')")
    }

    fun load() {
        bridge.execute("engine:load_game('quicksave')")
        updateUI()
    }

    private fun updateUI() {
        val text = bridge.execute("return engine:get_current_text()")
        currentText = text
        // Parse choices from Lua (simplified)
        choices = listOf(Choice("Continue"))
    }

    override fun onCleared() {
        bridge.cleanup()
        super.onCleared()
    }
}
```

## App Lifecycle

Handle pausing to auto-save:

```kotlin
// MainActivity.kt
class MainActivity : ComponentActivity() {
    private lateinit var viewModel: StoryViewModel

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            WhiskerTheme {
                viewModel = viewModel()
                StoryScreen(viewModel)
            }
        }
    }

    override fun onPause() {
        super.onPause()
        viewModel.save()  // Auto-save
    }
}
```

## Best Practices

1. **Thread Safety**: Run Lua on background thread with proper synchronization
2. **Memory Management**: Call `cleanup()` in ViewModel's `onCleared()`
3. **Asset Loading**: Extract Lua files from assets to cache directory
4. **Material Design**: Use Material3 components and themes
5. **Back Button**: Handle back press for navigation
6. **Configuration Changes**: Use ViewModel to survive rotation

## Testing

```kotlin
// AndroidPlatformTest.kt
@RunWith(AndroidJUnit4::class)
class AndroidPlatformTest {
    @Test
    fun testSaveLoad() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val platform = AndroidPlatform(context)

        assertTrue(platform.save("test", "{\"value\":42}"))
        assertEquals("{\"value\":42}", platform.load("test"))
        assertTrue(platform.delete("test"))
        assertNull(platform.load("test"))
    }
}
```

## Resources

- [Android Developer Documentation](https://developer.android.com/)
- [JNI Guide](https://developer.android.com/training/articles/perf-jni)
- [Jetpack Compose](https://developer.android.com/jetpack/compose)
- [Material Design 3](https://m3.material.io/)
