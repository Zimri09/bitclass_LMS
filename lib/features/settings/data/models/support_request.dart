enum SupportRequestType { feedback, bug }

extension SupportRequestTypeValue on SupportRequestType {
  String get databaseValue => switch (this) {
    SupportRequestType.feedback => 'feedback',
    SupportRequestType.bug => 'bug',
  };
}
