import { readFileSync } from "node:fs";
import { dirname, join as pathJoin } from "node:path";
import { fileURLToPath } from "node:url";

import {
  Location,
  ReturnType,
  CodeLanguage,
} from "@chainlink/functions-toolkit";

const __dirname = dirname(fileURLToPath(import.meta.url));

const requestConfig = {
  source: readFileSync(
    pathJoin(__dirname, "../sources/get-off-chain-collateral.mjs"),
    "utf-8"
  ),
  codeLocation: Location.Inline,
  secrets: {
    monoApiKey: process.env.MONOBANK_API_KEY,
    iban: process.env.MONOBANK_IBAN,
  },
  secretsLocation: Location.DONHosted,
  args: [],
  codeLanguage: CodeLanguage.JavaScript,
  expectedReturnType: ReturnType.uint256,
};

export default requestConfig;
