mixin InitialAppMixins {
  List<String> visitedBottomNavBar = [];

  // just after login
  void fetchLoggedInData() {}

  // initial data for homescreen
  void fetchHomeInitialData() {}

  // initial data for document
  void fetchDocumentInitialData() {}

  // initial data for recent activities
  void fetchRecentInitialData() {}

  // initial data for setting
  void fetchSettingInitialData() {}
}
