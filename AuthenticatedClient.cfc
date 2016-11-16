<cfscript>

  component output="false" extends="PublicClient" {

    variables.auth = false;

    /*************************************************
      INIT METHOD
      store all arguments passed in, create
      Authentication object to use to authenticate
      requests
    **************************************************/

    public AuthenticatedClient function init(
        required string publicKey
      , required string secretKey, required string passPhrase
      , string url="https://api.gdax.com", string productId="BTC-USD") {

      super.init(url=arguments.url, productId=arguments.productId);

      // copy all of the arguments to the private variables scope
      structAppend(variables, arguments, true);

      // build our auth object here since users don't need to worry about impl
      variables.auth = new Authentication(argumentCollection=arguments);

      // return our new object
      return this;
    }

    /*************************************************
      API AUTHENTICATED METHODS
    **************************************************/

    // accounts

    public struct function getAccounts() {
      return _get(paths=["accounts"]);
    }

    public struct function getAccount(required string accountId) {
      return _get(paths=["accounts", arguments.accountId]);
    }

    public struct function getAccountHistory(required string accountId) {
      return _get(
          paths=["accounts", arguments.accountId, "ledger"]
        , argumentCollection=_buildPagination(argumentCollection=arguments)
      );
    }

    public struct function getAccountHolds(required string accountId) {
      return _get(
          paths=["accounts", arguments.accountId, "holds"]
        , argumentCollection=_buildPagination(argumentCollection=arguments)
      );
    }

    // orders

    public struct function getOrders(string status="all", string product_id=productId) {
      return _get(
          paths=["orders"]
        , status=arguments.status
        , product_id=arguments.product_id
        , argumentCollection=_buildPagination(argumentCollection=arguments)
      );
    }

    public struct function getOrder(required string orderId) {
      return _get(paths=["orders", arguments.orderId]);
    }

    public struct function buy() {
      arguments.side = "buy";
      return placeOrder(argumentCollection=arguments);
    }

    public struct function sell() {
      arguments.side = "sell";
      return placeOrder(argumentCollection=arguments);
    }

    public struct function createOrder(
      string type="limit", string product_id=productId) {

      local.requiredArgs = "size,side,product_id";

      if (arguments.type != "market")
        local.requiredArgs = listAppend(local.requiredArgs, "price");

      for (local.arg in arguments)
        if (!structKeyExists(arguments, local.arg))
          throw(
              type="cfgdax.missingArgument"
            , message="Argument #local.arg# is required!"
          );

      return _post(paths=["orders"], argumentCollection=arguments);
    }

    public struct function cancelOrder(required string orderId) {
      return _delete(paths=["orders", arguments.orderId]);
    }

    public struct function cancelAllOpenOrders() {
      return _delete(paths=["orders"]);
    }

    // fills

    public struct function getFills(string order_id, string product_id=productId) {
      return _get(
          paths=["fills"]
        , order_id=arguments.order_id
        , product_id=arguments.productId
        , argumentCollection=_buildPagination(argumentCollection=arguments)
      );
    }

    // user

    public struct function userTrailingVolume() {
      return _get(paths=["users", "self", "trailing-volume"]);
    }

    public struct function getCoinbaseAccounts() {
      return _get(paths=["coinbase-accounts"]);
    }

    // reports

    public struct function createReport(
      required string type, required date start_date, required date end_date) {

      // type can only be fills or accounts
      if (!listFindNoCase("accounts,fills", arguments.type))
        throw(
            type="cfgdax.invalidType"
          , message="Report type can only be `accounts` or `fills`."
        );

      if (arguments.type == "fills")
        if (!structKeyExists(arguments, "product_id"))
          arguments["product_id"] = productId;

      if (arguments.type == "accounts"
        && !structKeyExists(arguments, "account_id"))
        throw(
            type="cfgdax.missingArgument"
          , message="Argument account_id is required when type = `accounts`"
        );

      // format our dates properly for the api
      arguments.start_date = isoDateTimeString(arguments.start_date);
      arguments.end_date = isoDateTimeString(arguments.end_date);

      return _post(
          paths=["reports"]
        , argumentCollection=arguments
      );
    }

    public struct function getReport(required string reportId) {
      return _get(paths=["reports", arguments.reportId]);
    }

    /*************************************************
      INTERNAL PRIVATE METHODS
    **************************************************/

    private any function _post(required array paths) {

      local.endPoint = _buildRelativeUrl(arguments.paths);

      return _request(
          method="POST"
        , endPoint=local.endPoint
        , body=_buildBodyJson(argumentCollection=arguments)
      );
    }

    private any function _delete(required array paths) {

      local.endPoint = _buildRelativeUrl(arguments.paths);

      return _request(
          method="delete"
        , endPoint=local.endPoint
      );
    }

    private string function _buildBodyJson() {

      local.ignoreArgs = "paths";
      local.bodyParams = duplicate(arguments);

      for (local.key in local.bodyParams)
        if (listFindNoCase(local.ignoreArgs, local.key)
          || !len(arguments[local.key]))
          structDelete(local.bodyParams, local.key, false);

      return serializeJSON(local.bodyParams);
    }

    // Override
    private void function _addHeaders(
      required Http request, required string endPoint, string body) {
      auth.setHeaders(argumentCollection=arguments);
      super._addHeaders(arguments.request);
    }
  }
</cfscript>
