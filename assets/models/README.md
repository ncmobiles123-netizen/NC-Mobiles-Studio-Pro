Place u2netp.tflite here before building — see the main README's
"Get the background-removal model" section. This folder must exist
(even empty) for `flutter build` to succeed; the app itself checks for
the model file at runtime and fails gracefully with an on-screen error
if it's missing, rather than crashing.
