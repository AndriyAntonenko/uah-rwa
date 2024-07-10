import { createPromptModule } from "inquirer";
import { SecretsManager } from "@chainlink/functions-toolkit";
import { Wallet, providers } from "ethers";
import { config } from "dotenv";

config();

const SECRETS_EXPIRATION_MINUTES = 1440 * 3; // 3 days
const SEPOLIA_ROUTER_ADDRESS = "0xb83E47C2bC239B3bf370bc41e1459A34b41238D0";
const SEPOLIA_DON_ID = "fun-ethereum-sepolia-1";
const TESTNET_CHAINLINK_GATEWAYS = [
  "https://01.functions-gateway.testnet.chain.link/",
  "https://02.functions-gateway.testnet.chain.link/",
];

async function main() {
  const privateKeyPrompt = createPromptModule();

  const { privateKey } = await privateKeyPrompt({
    type: "input",
    name: "privateKey",
    message: "Pls, enter your private key:",
    validate: (answer) => {
      return /^0x[0-9a-fA-F]{64}$/.test(answer);
    },
  });

  const provider = new providers.JsonRpcProvider(process.env.RPC_URL);
  const wallet = new Wallet(privateKey);
  const signer = wallet.connect(provider);

  const secretsManager = new SecretsManager({
    functionsRouterAddress: SEPOLIA_ROUTER_ADDRESS,
    signer,
    donId: SEPOLIA_DON_ID,
  });

  await secretsManager.initialize();

  const secrets = {
    monoApiKey: process.env.MONOBANK_API_KEY,
    iban: process.env.MONOBANK_IBAN,
  };

  const { encryptedSecrets } = await secretsManager.encryptSecrets(secrets);
  console.info("Encrypted secrets: ", encryptedSecrets);

  const secretsSlotId = +process.env.CHAINLINK_SECRET_SLOT_ID;

  const uploadResult = await secretsManager.uploadEncryptedSecretsToDON({
    encryptedSecretsHexstring: encryptedSecrets,
    slotId: secretsSlotId,
    gatewayUrls: TESTNET_CHAINLINK_GATEWAYS,
    minutesUntilExpiration: SECRETS_EXPIRATION_MINUTES,
  });

  if (!uploadResult.success) {
    throw new Error("Failed to upload secrets to the DON");
  }

  console.info(
    "Secrets uploaded successfully, response from the DON: ",
    uploadResult
  );

  const donHostedSecretsVersion = uploadResult.version;

  console.info("DON hosted secrets version: ", donHostedSecretsVersion);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
