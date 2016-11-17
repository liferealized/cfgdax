<cfscript>

  component output="false" {

    /*************************************************
      INIT METHOD
    **************************************************/

    public PublicClient function init(
      string url="https://api.gdax.com", string productId="BTC-USD") {

      // copy all of the arguments to the private variables scope
      structAppend(variables, arguments, true);

      // return our new object
      return this;
    }

    /*************************************************
      API PUBLIC METHODS
    **************************************************/

    public struct function getProducts() {
      return _get(paths=["products"]);
    }

    public struct function getProduct(string productId=productId) {
      return _get(paths=["products", productId]);
    }

    public struct function getProductOrderBook(
      numeric level=1, string productId=productId) {
      return _get(
          paths=["products", productId, "book"]
        , level=arguments.level
      );
    }

    public struct function getProductTicker(string productId=productId) {
      return _get(paths=["products", productId, "ticker"]);
    }

    public struct function getProductTrades(string productId=productId) {
      return _get(
          paths=["products", productId, "trades"]
        , argumentCollection=_buildPagination(argumentCollection=arguments)
      );
    }

    public struct function getProductHistoricRates(
      date start, date end, numeric granularity, string productId=productId) {

      arguments.start = isoDateTimeString(arguments.start);
      arguments.end = isoDateTimeString(arguments.end);

      return _get(
          paths=["products", productId, "candles"]
        , start=arguments.start
        , end=arguments.end
        , granularity=arguments.granularity
      );
    }

    public struct function getProduct24HrStats(string productId=productId) {
      return _get(paths=["products", productId, "stats"]);
    }

    public struct function getCurrencies() {
      return _get(paths=["currencies"]);
    }

    public struct function getTime() {
      return _get(paths=["time"]);
    }

    /*************************************************
      PUBLIC HELPER METHODS
    **************************************************/

    public string function isoDateTimeString(required date dt) {
      return dateFormat(arguments.dt, "yyyy-mm-dd")
        & "T"
        & timeFormat(arguments.dt, "HH:mm:ss")
        & "Z";
    }

    /*************************************************
      INTERNAL PRIVATE METHODS
    **************************************************/

    private struct function _get(required array paths) {

      local.endPoint = _buildRelativeUrl(arguments.paths);

      return _request(
          method="GET"
        , endPoint=local.endPoint
        , params=_buildParams(argumentCollection=arguments)
      );
    }

    private struct function _request(
        required string method
      , required string endPoint, string params, string body) {

      // gdax considers an endpoint to be both the path and query params that
      // are sent to the server......
      if (len(arguments.params))
        arguments.endPoint &= "?" & arguments.params

      // build our request object
      local.request = new http(
          method=arguments.method
        , url=_buildAbsoluteUrl(arguments.endPoint)
        , userAgent="cfgdax"
        , charset="utf-8"
      );

      _addHeaders(local.request, arguments.endPoint, arguments.body);

      if (!isNull(arguments.body) && arguments.method == "POST")
        local.request.addParam(type="body", value=arguments.body);

      local.result = local.request.send();
      local.response = local.result.getPrefix();

      local.answer = {
          "status" = {
              "code" = local.response["status_code"]
            , "text" = local.response["status_text"]
          }
        , "error" = {}
        , "data" = deserializeJSON(local.response.fileContent)
        , "success" = true
      };

      if (local.response["status_code"] != 200) {
        local.answer.success = false;
        local.answer.error = duplicate(local.answer.data);
        local.answer.data = {};
      }

      // we have a valid response, see if we have headers for pagination and add
      // them into the answer struct
      for (local.header in ["before", "after"])
        if (structKeyExists(local.response.responseheader, "cb-" & local.header))
          local.answer["cursor"][local.header] = local.response.responseheader["cb-" & local.header];

      return local.answer;
    }

    private struct function _buildPagination() {

      local.args = {};

      for (local.key in arguments)
        if (listFindNoCase("after,before,limit", local.key))
          local.args[local.key] = arguments[local.key];

      return local.args;
    }

    private string function _buildParams() {

      local.ignoreArgs = "paths";
      local.params = "";

      for (local.key in arguments)
        if (!listFindNoCase(local.ignoreArgs, local.key)
          && len(arguments[local.key]))
          local.params = listAppend(
              local.params
            , local.key & "=" & arguments[local.key]
            , "&"
          );

      return local.params;
    }

    private string function _buildRelativeUrl(required array paths) {
      return "/" & arrayToList(arguments.paths, "/");
    }

    private string function _buildAbsoluteUrl(required string relativeUrl) {
      return variables.url & arguments.relativeUrl;
    }

    private void function _addHeaders(required Http request) {

      arguments.request.addParam(
          type="header"
        , name="accept"
        , value="application/json"
      );

      if (arguments.request.getMethod() == "post")
        arguments.request.addParam(
            type="header"
          , name="content-type"
          , value="application/json"
        );
    }
  }
</cfscript>
