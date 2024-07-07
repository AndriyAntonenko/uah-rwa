const COLLATERAL_PRECISION = 10_000_000_000_000_000n;

if (!secrets.monoApiKey) {
  throw new Error("monoApiKey is not set");
}

if (!secrets.iban) {
  throw new Error("iban is not set");
}

const monoBankClientInfoRequest = Functions.makeHttpRequest({
  url: "https://api.monobank.ua/personal/client-info",
  headers: {
    accept: "application/json",
    "X-Token": secrets.monoApiKey,
  },
});

const [monoBankClientInfo] = await Promise.all([monoBankClientInfoRequest]);

const account = monoBankClientInfo.data.accounts.find(
  (account) => account.iban === secrets.iban
);

return Functions.encodeUint256(BigInt(account.balance) * precision);
