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
    pathJoin(__dirname, "../sources/get-usd-exchange-rate.mjs"),
    "utf-8"
  ),
  codeLocation: Location.Inline,
  args: [],
  codeLanguage: CodeLanguage.JavaScript,
  expectedReturnType: ReturnType.uint256,
};

export default requestConfig;
