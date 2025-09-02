# 🌾 Farmland Token - Fractional Land Investment Platform

A Clarity smart contract enabling fractional ownership of farmland through tokenization, allowing investors to purchase shares in agricultural land and receive proportional profit distributions.

## 🚀 Features

- 🏞️ **Land Tokenization**: Convert farmland into tradeable tokens
- 💰 **Fractional Investment**: Purchase partial ownership of agricultural land
- 📈 **Profit Sharing**: Automatic distribution of farming profits to token holders
- 🔄 **Token Trading**: Transfer ownership tokens between investors
- 📊 **Transparent Tracking**: View ownership percentages and profit history

## 🛠️ Core Functions

### For Land Owners (Farmers)

#### `create-land-parcel`
Create a new tokenized land parcel for investment
```clarity
(contract-call? .farmland-token create-land-parcel "Iowa Corn Farm" u100 u1000 u50)
```

#### `distribute-profits`
Distribute farming profits to token holders
```clarity
(contract-call? .farmland-token distribute-profits u1 u10000)
```

#### `deactivate-land`
Deactivate a land parcel from trading
```clarity
(contract-call? .farmland-token deactivate-land u1)
```

### For Investors

#### `purchase-tokens`
Buy fractional ownership tokens in farmland
```clarity
(contract-call? .farmland-token purchase-tokens u1 u100)
```

#### `transfer-tokens`
Transfer ownership tokens to another investor
```clarity
(contract-call? .farmland-token transfer-tokens 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 u1 u50)
```

#### `claim-profits`
Claim your share of distributed profits
```clarity
(contract-call? .farmland-token claim-profits u1)
```

## 📖 Read-Only Functions

### `get-land-info`
Get detailed information about a land parcel
```clarity
(contract-call? .farmland-token get-land-info u1)
```

### `get-investor-holding`
Check an investor's token holdings for specific land
```clarity
(contract-call? .farmland-token get-investor-holding 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 u1)
```

### `calculate-ownership-percentage`
Calculate ownership percentage for an investor
```clarity
(contract-call? .farmland-token calculate-ownership-percentage 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 u1)
```

### `calculate-claimable-profits`
Check claimable profits for an investor
```clarity
(contract-call? .farmland-token calculate-claimable-profits 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 u1)
```

## 🎯 Usage Example

1. **Farmer creates land parcel**: 100-acre farm, 1000 tokens at 50 STX each
2. **Investor purchases tokens**: Buys 100 tokens (10% ownership) for 5000 STX
3. **Farmer distributes profits**: After harvest, distributes 10000 STX profit
4. **Investor claims profits**: Receives 1000 STX (10% of total profits)

## 🔧 Development Setup

```bash
clarinet new farmland-project
```

```bash
cd farmland-project
```

```bash
clarinet console
```

## 🧪 Testing

Deploy and test the contract in Clarinet console:

```clarity
::deploy_contracts
```

```clarity
(contract-call? .farmland-token create-land-parcel "Test Farm" u50 u500 u100)
```

```clarity
(contract-call? .farmland-token purchase-tokens u1 u50)
```

## 📋 Contract Details

- **Token Type**: Fungible Token (SIP-010 compatible)
- **Ownership Model**: Proportional to token holdings
- **Profit Distribution**: Based on ownership percentage
- **Access Control**: Land owners control their parcels
- **Transfer Mechanism**: Direct token transfers between investors

## 🔒 Security Features

- Owner-only land creation and profit distribution
- Balance validation for all transfers
- Ownership percentage calculations with precision
- Active status checks for land parcels
- Claim tracking to prevent double-spending profits

## 🌱 Future Enhancements

- Multi-signature land ownership
- Automated profit distribution triggers
- Land valuation updates
- Governance token for platform decisions
- Integration with agricultural data oracles
```

**Git Commit Message:**
```
feat: implement tokenized farmland ownership MVP with fractional investment and profit sharing
```

**GitHub Pull Request Title:**
```
🌾 Add Tokenized Farmland Investment Smart Contract MVP
```

**GitHub Pull Request Description:**
```
## Summary
Implements a complete MVP for tokenized farmland ownership enabling fractional investment in agricultural land with automated profit sharing.

## Features Added
- **Land Tokenization**: Farmers can create tokenized representations of their farmland
- **Fractional Investment**: Investors can purchase partial ownership through tokens
- **Profit Distribution**: Automated profit sharing based on ownership percentage  
- **Token Trading**: Transfer ownership tokens between investors
- **Ownership
