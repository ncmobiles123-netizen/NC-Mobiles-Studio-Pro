# TFLite: keep the interpreter and GPU/NNAPI delegate classes so
# on-device background removal keeps working in the minified release
# build. Without these rules R8 can strip classes only referenced via
# JNI/reflection, causing a silent runtime crash on first inference.
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
-dontwarn org.tensorflow.lite.**

# image_picker / file_picker use platform channels reflectively in a
# couple of edge cases on OEM ROMs — keep their plugin registrants.
-keep class io.flutter.plugins.** { *; }
