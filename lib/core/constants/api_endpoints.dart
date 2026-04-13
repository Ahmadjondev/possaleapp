/// All API endpoint paths used by the POS terminal.
class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const login = '/api/auth/token/';
  static const tokenRefresh = '/api/auth/token/refresh/';
  static const verifyPin = '/api/auth/verify-pin/';
  static const setPin = '/api/auth/set-pin/';
  static const me = '/api/users/me/';
  static const validateTenant = '/api/tenant/validate/';

  // POS
  static const posSearch = '/api/pos/search/';
  static const posScan = '/api/pos/scan/';
  static const posCheckout = '/api/pos/checkout/';
  static const posDashboard = '/api/pos/dashboard/';
  static const posExchangeRate = '/api/pos/exchange-rate/';
  static const posQuickSale = '/api/pos/quick-sale/';
  static const posReturn = '/api/pos/return/';
  static const posAddBackorder = '/api/pos/add-backorder/';
  static String posReceipt(int saleId) => '/api/pos/receipt/$saleId/';
  static String posReceiptPrinted(int saleId) =>
      '/api/pos/receipt/$saleId/printed/';
  static const posSaveDraft = '/api/pos/save-draft/';
  static const posDrafts = '/api/pos/drafts/';
  static String posDraft(int draftId) => '/api/pos/drafts/$draftId/';
  static String posDraftDelete(int draftId) =>
      '/api/pos/drafts/$draftId/delete/';

  // Sales
  static const sales = '/api/sales/';

  // Customers
  static const customers = '/api/customers/';
  static String customerBalance(int id) => '/api/customers/$id/balance/';

  // Products
  static const products = '/api/products/';
  static const categories = '/api/categories/';
  static const featuredProducts = '/api/featured-products/';
  static String featuredProductDetail(int id) => '/api/featured-products/$id/';

  // Warehouses
  static const warehouses = '/api/warehouses/';
}
