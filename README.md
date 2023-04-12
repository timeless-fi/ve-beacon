# VeBeacon

[![codecov](https://codecov.io/gh/timeless-fi/ve-beacon/branch/main/graph/badge.svg?token=VME1VE3HXH)](https://codecov.io/gh/timeless-fi/ve-beacon)

Beacon contract for broadcasting Curve-style voting escrow balances & total supply from Ethereum to other networks.

## Supported networks

- Arbitrum
- Optimism
- Polygon
- BSC
- Gnosis chain

## Usage

### VeBeacon

The `VeBeacon` contract lives on Ethereum and handles broadcasting data to other networks. To broadcast the balance of a user, use:

```solidity
uint256 requiredValue = beacon.getRequiredMessageValue(chainId, gasLimit, maxFeePerGas);
beacon.broadcastVeBalance{value: requiredValue}(user, chainId, gasLimit, maxFeePerGas);
```

`requiredValue` and `maxFeePerGas` may be set to 0 for networks other than Arbitrum, as currently only Arbitrum requires paying an ETH fee to pass a message.

### VeRecipient

`VeRecipient` lives on non-Ethereum networks and provides other contracts on the network with the vetoken balances of users & the total supply. Simply use `balanceOf()` and `totalSupply()` as you would with a regular voting escrow contract. Balances & total supply have the same time-decay behavior as regular voting escrow contracts.

There are two caveats:

1. If a user has updated their lock on Ethereum, `VeBeacon` must be called to broadcast the updated vetoken balance & total supply to other chains.
2. The total supply may diverge from the correct value if nobody broadcasts via `VeBeacon` for 8 epochs (~2 months). It can be fixed by making a broadcast.

## Installation

To install with [Foundry](https://github.com/gakonst/foundry):

```
forge install timeless-fi/ve-beacon
```

## Local development

This project uses [Foundry](https://github.com/gakonst/foundry) as the development framework.

Please create a `.env` file before testing/deploying. An example can be found in `.env.example`.

### Dependencies

```
forge install
```

### Compilation

```
forge build
```

### Testing

```
forge test -f mainnet
```

### Contract deployment

#### Dryrun

```
forge script script/DeployBeacon.s.sol -f mainnet
forge script script/DeployRecipient.s.sol -f [recipient-network]
```

### Live

```
forge script script/DeployBeacon.s.sol -f mainnet --verify --broadcast
forge script script/DeployRecipient.s.sol -f [recipient-network] --verify --broadcast
```
