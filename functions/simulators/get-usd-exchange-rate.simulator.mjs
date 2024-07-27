import { simulateScript, decodeResult } from "@chainlink/functions-toolkit";
import requestConfig from "../configs/get-usd-exchange-rate.config.mjs";

async function main() {
  const { responseBytesHexstring, errorString } = await simulateScript(
    requestConfig
  );

  if (responseBytesHexstring) {
    console.info(
      `Response returned by script ${decodeResult(
        responseBytesHexstring,
        requestConfig.expectedReturnType
      )}`
    );
  }

  if (errorString) {
    console.error(`Error returned by script: ${errorString}\n`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
