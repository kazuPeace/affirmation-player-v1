#include <jni.h>

#include <cstdint>
#include <mutex>
#include <string>
#include <vector>

#include "voicevox_core.h"

namespace {

std::mutex g_mutex;
const VoicevoxOnnxruntime* g_onnxruntime = nullptr;
OpenJtalkRc* g_open_jtalk = nullptr;
VoicevoxSynthesizer* g_synthesizer = nullptr;
std::vector<VoicevoxVoiceModelFile*> g_voice_models;

std::string JStringToUtf8(JNIEnv* env, jstring value) {
  if (value == nullptr) {
    return {};
  }
  const char* chars = env->GetStringUTFChars(value, nullptr);
  std::string result(chars == nullptr ? "" : chars);
  if (chars != nullptr) {
    env->ReleaseStringUTFChars(value, chars);
  }
  return result;
}

void ThrowRuntimeException(JNIEnv* env, const std::string& message) {
  jclass exception_class = env->FindClass("java/lang/RuntimeException");
  if (exception_class != nullptr) {
    env->ThrowNew(exception_class, message.c_str());
  }
}

bool EnsureOk(JNIEnv* env, VoicevoxResultCode code, const char* action) {
  if (code == VOICEVOX_RESULT_OK) {
    return true;
  }

  std::string message(action);
  message += ": ";
  message += voicevox_error_result_to_message(code);
  ThrowRuntimeException(env, message);
  return false;
}

void CleanupLocked() {
  for (auto* model : g_voice_models) {
    if (model != nullptr) {
      voicevox_voice_model_file_delete(model);
    }
  }
  g_voice_models.clear();
  if (g_synthesizer != nullptr) {
    voicevox_synthesizer_delete(g_synthesizer);
    g_synthesizer = nullptr;
  }
  if (g_open_jtalk != nullptr) {
    voicevox_open_jtalk_rc_delete(g_open_jtalk);
    g_open_jtalk = nullptr;
  }
}

}  // namespace

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_affirmation_1player_MainActivity_nativeInitialize(
    JNIEnv* env,
    jobject /* this */,
    jstring onnxruntime_path,
    jstring open_jtalk_dict_dir) {
  std::lock_guard<std::mutex> lock(g_mutex);

  if (g_synthesizer != nullptr) {
    char* metas_json = voicevox_synthesizer_create_metas_json(g_synthesizer);
    if (metas_json == nullptr) {
      ThrowRuntimeException(env, "Failed to read VOICEVOX metas.");
      return nullptr;
    }
    jstring result = env->NewStringUTF(metas_json);
    voicevox_json_free(metas_json);
    return result;
  }

  std::string onnx_path = JStringToUtf8(env, onnxruntime_path);
  std::string dict_dir = JStringToUtf8(env, open_jtalk_dict_dir);

  VoicevoxLoadOnnxruntimeOptions load_options =
      voicevox_make_default_load_onnxruntime_options();
  load_options.filename = onnx_path.c_str();
  if (!EnsureOk(env, voicevox_onnxruntime_load_once(load_options, &g_onnxruntime),
                "Failed to load ONNX Runtime")) {
    return nullptr;
  }

  if (!EnsureOk(env, voicevox_open_jtalk_rc_new(dict_dir.c_str(), &g_open_jtalk),
                "Failed to initialize Open JTalk")) {
    CleanupLocked();
    return nullptr;
  }

  VoicevoxInitializeOptions initialize_options =
      voicevox_make_default_initialize_options();
  initialize_options.acceleration_mode = VOICEVOX_ACCELERATION_MODE_CPU;
  if (!EnsureOk(env,
                voicevox_synthesizer_new(g_onnxruntime, g_open_jtalk,
                                         initialize_options, &g_synthesizer),
                "Failed to create synthesizer")) {
    CleanupLocked();
    return nullptr;
  }

  char* metas_json = voicevox_synthesizer_create_metas_json(g_synthesizer);
  if (metas_json == nullptr) {
    CleanupLocked();
    ThrowRuntimeException(env, "Failed to read VOICEVOX metas.");
    return nullptr;
  }

  jstring result = env->NewStringUTF(metas_json);
  voicevox_json_free(metas_json);
  return result;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_affirmation_1player_MainActivity_nativeLoadModel(
    JNIEnv* env,
    jobject /* this */,
    jstring model_path) {
  std::lock_guard<std::mutex> lock(g_mutex);

  if (g_synthesizer == nullptr) {
    ThrowRuntimeException(env, "VOICEVOX is not initialized.");
    return nullptr;
  }

  std::string vvm_path = JStringToUtf8(env, model_path);
  auto* voice_model = static_cast<VoicevoxVoiceModelFile*>(nullptr);
  if (!EnsureOk(env, voicevox_voice_model_file_open(vvm_path.c_str(), &voice_model),
                "Failed to open voice model")) {
    return nullptr;
  }

  if (!EnsureOk(env,
                voicevox_synthesizer_load_voice_model(g_synthesizer, voice_model),
                "Failed to load voice model")) {
    voicevox_voice_model_file_delete(voice_model);
    return nullptr;
  }
  g_voice_models.push_back(voice_model);

  char* metas_json = voicevox_synthesizer_create_metas_json(g_synthesizer);
  if (metas_json == nullptr) {
    ThrowRuntimeException(env, "Failed to read VOICEVOX metas.");
    return nullptr;
  }

  jstring result = env->NewStringUTF(metas_json);
  voicevox_json_free(metas_json);
  return result;
}

extern "C" JNIEXPORT jbyteArray JNICALL
Java_com_example_affirmation_1player_MainActivity_nativeSynthesize(
    JNIEnv* env,
    jobject /* this */,
    jstring text,
    jint style_id) {
  std::lock_guard<std::mutex> lock(g_mutex);

  if (g_synthesizer == nullptr) {
    ThrowRuntimeException(env, "VOICEVOX is not initialized.");
    return nullptr;
  }

  std::string utf8_text = JStringToUtf8(env, text);
  char* audio_query_json = nullptr;
  if (!EnsureOk(env,
                voicevox_synthesizer_create_audio_query(
                    g_synthesizer, utf8_text.c_str(), static_cast<VoicevoxStyleId>(style_id),
                    &audio_query_json),
                "Failed to create audio query")) {
    return nullptr;
  }

  VoicevoxSynthesisOptions synthesis_options =
      voicevox_make_default_synthesis_options();
  uintptr_t wav_length = 0;
  uint8_t* wav_data = nullptr;
  VoicevoxResultCode synthesis_result = voicevox_synthesizer_synthesis(
      g_synthesizer, audio_query_json, static_cast<VoicevoxStyleId>(style_id),
      synthesis_options, &wav_length, &wav_data);
  voicevox_json_free(audio_query_json);

  if (!EnsureOk(env, synthesis_result, "Failed to synthesize speech")) {
    return nullptr;
  }

  jbyteArray result = env->NewByteArray(static_cast<jsize>(wav_length));
  if (result == nullptr) {
    voicevox_wav_free(wav_data);
    ThrowRuntimeException(env, "Failed to allocate WAV byte array.");
    return nullptr;
  }

  env->SetByteArrayRegion(result, 0, static_cast<jsize>(wav_length),
                          reinterpret_cast<const jbyte*>(wav_data));
  voicevox_wav_free(wav_data);
  return result;
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_affirmation_1player_MainActivity_nativeRelease(
    JNIEnv* /* env */,
    jobject /* this */) {
  std::lock_guard<std::mutex> lock(g_mutex);
  CleanupLocked();
}
