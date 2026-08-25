# ZirakSwap — Single Contract

सिर्फ **एक contract**: `contracts/ZirakSwap.sol` — fixed USDT ↔ SHIB pool, standard
constant-product AMM (x*y=k), 0.3% trading fee। कोई Factory नहीं, कोई अलग Router नहीं —
सब कुछ इसी एक file में है।

## ⚠️ Security

- `.env` कभी GitHub पर push ना करें (`.gitignore` में पहले से protected है)
- Private key कभी chat/screenshot में share ना करें
- पहले Testnet पर टेस्ट करें, mainnet पर बाद में

## Steps

```bash
npm install
cp .env.example .env
nano .env          # PRIVATE_KEY aur BSCSCAN_API_KEY bharen
npx hardhat compile
npx hardhat run scripts/deploy.js --network bscTestnet
```

Deploy होने के बाद जो **contract address** मिलेगा, वही एक address है जो frontend में
`CONTRACT_ADDRESSES` में डालनी है।

## Contract के functions (frontend इन्हें call करेगा)

| Function | काम |
|---|---|
| `addLiquidity(usdtAmt, shibAmt, minUsdt, minShib, deadline)` | Pool में liquidity डालना |
| `removeLiquidity(liquidity, minUsdt, minShib, deadline)` | LP shares वापस भुनाना |
| `swapUSDTForSHIB(usdtIn, minShibOut, deadline)` | USDT देकर SHIB लेना |
| `swapSHIBForUSDT(shibIn, minUsdtOut, deadline)` | SHIB देकर USDT लेना |
| `quoteUSDTToSHIB(usdtIn)` | कितना SHIB मिलेगा, बिना transaction भेजे |
| `quoteSHIBToUSDT(shibIn)` | कितना USDT मिलेगा, बिना transaction भेजे |

Swap से पहले user को token approve करना होगा — सिर्फ उतना जितना swap करना है,
unlimited नहीं (ये MetaMask/wallet में normal दिखेगा, standard practice है)।

## Mainnet पर जाना

```bash
npx hardhat run scripts/deploy.js --network bscMainnet
npx hardhat verify --network bscMainnet <CONTRACT_ADDRESS> <USDT_ADDRESS> <SHIB_ADDRESS>
```
