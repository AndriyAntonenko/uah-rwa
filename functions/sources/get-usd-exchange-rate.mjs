const EXCHANGE_RATE_PRECISION = 10_000_000_000_000_000n;
const USD_CODE = 840;
const UAH_CODE = 980;

const currenciesRequest = Functions.makeHttpRequest({
  url: "https://api.monobank.ua/bank/currency",
  headers: {
    accept: "application/json",
  },
});

const [currencies] = await Promise.all([currenciesRequest]);

const rates = currencies.data.find(
  (currency) =>
    currency.currencyCodeA === USD_CODE && currency.currencyCodeB === UAH_CODE
);

const rate = (rates.rateBuy + rates.rateSell) / 2;
const rateInt = Math.round((rate + Number.EPSILON) * 100);

return Functions.encodeUint256(BigInt(rateRounded) * EXCHANGE_RATE_PRECISION);
