class AppConstants {
  static const String baseUrl = 'https://kbd.thecodersadda.com';
  // Production: 'http://103.211.202.131/apis'
  //http://192.168.0.109:3000
  //last version version: 1.0.1+2, 1.0.2+3

  // Auth
  static const String loginEndpoint = '/auth/auth/login';
  static const String googleAuthEndpoint = '/auth/google';
  static const String registerEndpoint = '/auth/auth/register';
  static const String profileEndpoint = '/auth/auth/profile';

  // Weighing machines
  static const String weighingMachines = '/weighing-machines';
  static const String registerMachine = '/weighing-machines';
  static const String registerManyMachines = '/weighing-machines/bulk';
  static const String getUserMachines = '/weighing-machines';

  static String getMachinesByEsp(String espId) =>
      '/weighing-machines/esp/$espId';
  static String updateMachine(String sensorId) =>
      '/weighing-machines/$sensorId';
  static String deleteMachine(String sensorId) =>
      '/weighing-machines/$sensorId';
  static String setTare(String sensorId) => '/weighing-machines/$sensorId/tare';
  static String linkInventory(String sensorId) =>
      '/weighing-machines/$sensorId/link';

  // Manual inventory
  static const String manualInventory = '/manual-inventory';
  static const String parseReceipt = '/manual-inventory/receipt/parse';
  static const String parseReceiptSession =
      '/manual-inventory/receipt/parse-session';

  static String manualInventoryRemaining(int id) =>
      '/manual-inventory/$id/remaining';
  static String manualInventoryThreshold(int id) =>
      '/manual-inventory/$id/threshold';
  static String manualInventoryPrice(int id) => '/manual-inventory/$id/price';
  static String manualInventorySensor(int id) => '/manual-inventory/$id/sensor';
  static String manualInventoryDelete(int id) => '/manual-inventory/$id';

  // Scheduled meals
  static const String scheduledMealsSuggest = '/scheduled-meals/suggest';
  static const String scheduledMeals = '/scheduled-meals';
  static String scheduledMealSingle(int id) => '/scheduled-meals/$id';
  static String scheduledMealDelete(int id) => '/scheduled-meals/$id';
  static String scheduledMealReschedule(int id) =>
      '/scheduled-meals/$id/reschedule';
  static String scheduledMealRecipeMissing(int recipeId) =>
      '/scheduled-meals/recipes/$recipeId/missing';

  //Waitlist
  static const String waitlistJoin = '/waitlist/join';
  static const String waitlistStatus = '/waitlist/status';

  // Cook
  static const String cookSuggest = '/cook/suggest';

  // Categories
  static const List<String> categories = [
    'All',
    'Grains',
    'Spices',
    'Dairy',
    'Oils',
    'Pulses',
    'Beverages',
    'Flour',
    'Sugar',
    'Snacks',
    'Other',
  ];

  // Units
  static const List<String> units = ['g', 'kg', 'ml', 'L', 'pcs', 'packs'];
}
