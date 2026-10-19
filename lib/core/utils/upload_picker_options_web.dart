import 'package:file_picker_web/file_picker_web.dart';

// Window focus can arrive before the file input's change event. Only the
// browser's explicit cancel event should cancel a selection.
const uploadPickerOptions = FilePickerWebOptions(
  cancelUploadOnWindowBlur: false,
  withData: false,
);
