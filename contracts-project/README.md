# ZirakSwap — PancakeSwap-Routed (कोई अपनी liquidity नहीं चाहिए)

एक contract: `contracts/ZirakSwap.sol`। ये अपना pool नहीं रखता — हर swap उसी
transaction में PancakeSwap के **असली, पहले से भरे हुए** router को forward हो जाता है।
आपको खुद USDT या SHIB liquidity कहीं भी जमा नहीं करनी।

## कैसे काम करता है

```
User → ZirakSwap.swapUSDTForSHIB() 
      → contract user se USDT khींचता है
      → PancakeSwap Router ko exact amount approve karta hai
      → PancakeSwap Router se swap करता है
      → SHIB seedha user ke wallet mein wapas
```

सब कुछ **एक ही transaction** में — कहीं भी पैसा रुकता नहीं, ना contract के पास, ना किसी और के पास।

## ⚠️ Security

- `.env` कभी GitHub पर push ना करें
- Private key कभी chat/screenshot में share ना करें
- पहले Testnet पर टेस्ट करें (नोट: testnet पर real SHIB token मौजूद नहीं है — testnet सिर्फ contract logic टेस्ट करने के लिए, USDT/WBNB जैसी pair से)

## Steps

```bash
npm install
cp .env.example .env
nano .env          # PRIVATE_KEY aur BSCSCAN_API_KEY bharen
npx hardhat compile
npx hardhat run scripts/deploy.js --network bscMainnet
```

चूंकि real SHIB सिर्फ mainnet पर है, असली टेस्ट **mainnet पर छोटी amount से** करनी होगी (जैसे $1-2 का swap करके देखें कि सही से काम कर रहा है)।

## Contract के functions

| Function | काम |
|---|---|
| `swapUSDTForSHIB(usdtIn, minShibOut, deadline)` | USDT देकर SHIB लेना (PancakeSwap के ज़रिए) |
| `swapSHIBForUSDT(shibIn, minUsdtOut, deadline)` | SHIB देकर USDT लेना |
| `quoteUSDTToSHIB(usdtIn)` | अभी कितना SHIB मिलेगा — बिना transaction भेजे |
| `quoteSHIBToUSDT(shibIn)` | अभी कितना USDT मिलेगा — बिना transaction भेजे |

Swap से पहले user को token approve करना होगा — सिर्फ उतना जितना swap करना है।

## Verify करना

```bash
npx hardhat verify --network bscMainnet <CONTRACT_ADDRESS> <PANCAKE_ROUTER> <USDT_ADDRESS> <SHIB_ADDRESS>
```
