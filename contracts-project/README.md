# ZirakSwap Smart Contracts

ये असली AMM DEX contracts हैं (Factory + Pair + Router) — Uniswap V2 / PancakeSwap जैसा standard, battle-tested architecture, BNB Smart Chain के लिए बनाया गया।

## ⚠️ ज़रूरी सुरक्षा नियम

1. **`.env` फाइल कभी GitHub पर push ना करें** — इसमें आपकी private key होगी। `.gitignore` में पहले से add है, फिर भी हमेशा `git status` चेक करें push करने से पहले।
2. **Private key किसी के साथ शेयर ना करें** — ना मुझसे, ना किसी और चैट में, ना screenshot में।
3. **पहले हमेशा Testnet पर टेस्ट करें**, mainnet पर तभी जाएं जब सब कुछ सही से काम कर रहा हो।
4. ये contracts standard, well-understood AMM pattern पर बने हैं, फिर भी real यूज़र्स का पैसा handle करने से पहले किसी **independent security audit** की सलाह दी जाती है।

## Step 1 — VPS पर Node.js और project setup

```bash
cd /var/www
mkdir -p contracts-project && cd contracts-project
git clone git@github.com:sagarcrypto24/vps.git temp-clone
cp -r temp-clone/contracts-project/* .
rm -rf temp-clone

node --version   # Node 18+ होना चाहिए
npm install
```

## Step 2 — `.env` फाइल बनाएं (सिर्फ VPS पर, कभी push नहीं होगी)

```bash
cp .env.example .env
nano .env
```

इसमें भरें:
- `PRIVATE_KEY` — आपकी deployer wallet की private key (इसमें BNB gas के लिए होना चाहिए)
- `SHIB_TOKEN_ADDRESS` — अगर आपके पास पहले से SHIB-side का real token contract है, वो address यहाँ डालें। अगर नहीं है, तो पहले `deploy-token.js` चलाकर एक बना लें (नीचे देखें)
- `BSCSCAN_API_KEY` — [bscscan.com/myapikey](https://bscscan.com/myapikey) से free में मिल जाती है, verification के लिए

## Step 3 — Compile करें

```bash
npm run compile
```

## Step 4 — (सिर्फ अगर ज़रूरत हो) अपना खुद का SHIB token बनाएं

अगर आपके पास पहले से कोई real token contract नहीं है:

```bash
npx hardhat run scripts/deploy-token.js --network bscTestnet
```

Address मिलेगा, उसे `.env` में `SHIB_TOKEN_ADDRESS` में डाल दें।

## Step 5 — Testnet पर पहले टेस्ट करें

पहले testnet BNB लें: [testnet.bnbchain.org/faucet-smart](https://testnet.bnbchain.org/faucet-smart)

```bash
npm run deploy:testnet
```

आपको Factory और Router के addresses मिलेंगे — इन्हें note कर लें।

## Step 6 — Contract verify करें (BscScan पर source code दिखाने के लिए)

```bash
npx hardhat verify --network bscTestnet <FACTORY_ADDRESS> <YOUR_WALLET_ADDRESS>
npx hardhat verify --network bscTestnet <ROUTER_ADDRESS> <FACTORY_ADDRESS> <WBNB_ADDRESS>
```

## Step 7 — Testnet पर liquidity add करके टेस्ट करें

Hardhat console से या एक छोटी script से:
1. USDT और SHIB token दोनों को Router address को **approve** करें (सिर्फ उतना जितना add करना है, unlimited नहीं)
2. `router.addLiquidity()` कॉल करें दोनों token amounts के साथ
3. एक testnet wallet से `router.swapExactTokensForTokens()` टेस्ट करें

## Step 8 — सब सही चलने पर Mainnet पर deploy करें

```bash
npm run deploy:mainnet
npx hardhat verify --network bscMainnet <FACTORY_ADDRESS> <YOUR_WALLET_ADDRESS>
npx hardhat verify --network bscMainnet <ROUTER_ADDRESS> <FACTORY_ADDRESS> <WBNB_ADDRESS>
```

## Step 9 — Frontend में addresses जोड़ें

Mainnet Router address मिलने के बाद, मुझे भेज दें — मैं `index.html` में जो
`CONTRACT_ADDRESSES` वाला placeholder section है, वहाँ डालकर swap function
को असली router call से जोड़ दूंगा।

---

## Contracts का structure

| File | काम |
|---|---|
| `ZirakFactory.sol` | नए pairs बनाता है (CREATE2 से) |
| `ZirakPair.sol` | असली pool — reserves, mint/burn LP, swap logic, 0.3% fee |
| `ZirakRouter.sol` | User-facing entry — addLiquidity, swap, आदि |
| `ZirakERC20.sol` | LP token का base |
| `ZirakToken.sol` | Optional — नया BEP-20 token बनाने के लिए template |
| `libraries/ZirakLibrary.sol` | Price/amount calculation helpers |
