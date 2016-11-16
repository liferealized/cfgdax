<cfscript>
  component output="false" {

    public Authentication function init(
        string publicKey="", string secretKey="", string passPhrase="") {

      structAppend(variables, arguments, true);
      variables.mac =
         createObject("java", "javax.crypto.Mac")
         .getInstance("HmacSHA256");
      return this;
    }

    public string function generateSignature(
        required string timestamp
      , required string method, required string endPoint, required string body) {

      local.base64 = createObject("java", "java.util.Base64");
      local.secretSpec = createObject("java", "javax.crypto.spec.SecretKeySpec");

      local.prehash = arguments.timestamp
        & uCase(arguments.method)
        & arguments.endPoint
        & arguments.body;

      local.decodedSecret = local.base64.getDecoder().decode(secretKey);
      local.keySpec = local.secretSpec.init(local.decodedSecret, "HmacSHA256");

      // clone our local mac instance and init it with the keySpec
      local.sha256 = mac.clone();
      local.sha256.init(local.keySpec);

      // get the final output from encrypting the prehash
      local.final = local.sha256.doFinal(local.prehash.getBytes());

      // return our encrypted value as a string
      return local.base64.getEncoder().encodeToString(local.final);
    }

    public void function setHeaders(
        required Http request, required string endPoint, string body="") {

      local.timestamp = _getTimestamp();
      local.signature = generateSignature(
          local.timestamp
        , arguments.request.getMethod()
        , arguments.endpoint
        , arguments.body
      );

      arguments.request.addParam(
          type="header"
        , name="CB-ACCESS-KEY"
        , value=publicKey
      );

      arguments.request.addParam(
          type="header"
        , name="CB-ACCESS-SIGN"
        , value=local.signature
      );

      arguments.request.addParam(
          type="header"
        , name="CB-ACCESS-TIMESTAMP"
        , value=local.timestamp
      );

      arguments.request.addParam(
          type="header"
        , name="CB-ACCESS-PASSPHRASE"
        , value=passPhrase
      );
    }

    private numeric function _getTimestamp(date dt=now()) {
      arguments.dt = dateConvert("local2utc", arguments.dt);
      return dateDiff("s", createDateTime(1970, 1, 1, 0, 0, 0), arguments.dt);
    }
  }
</cfscript>
