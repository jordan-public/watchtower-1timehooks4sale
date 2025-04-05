# Demo Video and Deployment Addresses

## The demo video is [here](./Watchtower720p.mov) and on [YouTube](https://youtu.be/KvgtkRz6jk0).

## Deployment Addresses

The Watchtower Hook Contract is deployed at the following addresses:

Base Sepolia: 0x2FF03631adB0a022Da831c932A1A3dB32b058040 (using Nodit)

Polygon Amboy: 0x817AC732901c39FC048A549243e3722321d44040 (using Nodit)

Polygon Cardona: 0xAC598dD78fa19DE38caC2E1647dc14A55CB18040 (using Cardona RPC)

Unichain Sepolia: 0xef048394F7752FDEc12bE3D0A22AcA746dcA4040 (via Unichain RPC)

## Known Bug

The `main` branch is not connecting the Watchtower to LoanPair for callbacks. This is implemented in the branch `loan-w` by commenting out a known issue in the callback. To see this working (with the workaround), check out the branch `loan-w` and run as follows (output shown as well):

```
% forge test Watchtower.t.sol -vv
[⠊] Compiling...
No files changed, compilation skipped

Ran 1 test for test/Watchtower.t.sol:WatchtowerTest
[PASS] testWatchtowerHooks() (gas: 1858020)
Logs:
  Calling target callback - liquidation

Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 6.68ms (877.83µs CPU time)

Ran 1 test suite in 151.39ms (6.68ms CPU time): 1 tests passed, 0 failed, 0 skipped (1 total tests)
```

Once the fix is completed, this branch will be merged into `main`.