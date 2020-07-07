# Special Fee Contract

The SFC (Special Fee Contract) maintains a list of validation stakers and delegators.
It distributes the rewards, based on information written into contract by Lachesis node.

The essential:
- SFC contract only maintains the list of delegators and stakers, and doesn’t calculate reward weights or validators groups. The reward weights and validators group are written into SFC contract storage by consensus (i.e. golang code) for performance reasons. SFC calculates the rewards, depending on epoch snapshots written by consensus.
- Calculation of reward is O(1) for each epoch. Staker/delegator may specify a range of epochs he claims reward for, but not lower than `prev reward epoch + 1` and not higher than `last sealed epoch snapshot`.
- Each delegation is a separate object. Delegator claims rewards for each delegation independently of other delegations and stakers. Staker has a counter of delegated tokens to it.
- Staker/delegator cannot withdraw his stake any time. He must deactivate the stake (prepare to withdraw) in advance of N days.
- If validator is confirmed to be a cheater, then only a flag is written into SFC storage by consensus. SFC checks this flag and doesn't withdraw stake/delegation during `withdraw` operation if flag is set.
- Validation staker is allowed to increase his stake, but not decrease (only allowed to withdraw the whole stake).

# Compile

1. Install solc 0.5.12
2. `solc -o $PWD/build --optimize --optimize-runs=2000 --abi --bin-runtime --allow-paths $PWD/contracts --overwrite $PWD/contracts/sfc/Staker.sol` # compilation. don't forget --bin-runtime flag, if contract is pre-deployed!
3. `cat build/TestStakers.bin-runtime` # paste this into GetTestContractBinV1 in go-lachesis repo
4. `cat build/TestStakers.abi` # use this ABI to call contract methods

# Test

1. Install nodejs 10.5.0
2. `npm install -g truffle@v5.1.4` # install truffle v5.1.4
3. `npm update`
4. `npm test`

If everything is allright, it should output something along this:
```
> fantom-sfc@2.0.1-rc2 test fantom-sfc
> truffle test

Using network 'test'.


Compiling your contracts...
===========================
> Compiling ./contracts/ownership/Ownable.sol
> Compiling ./contracts/sfc/Migrations.sol
> Compiling ./contracts/sfc/SafeMath.sol
> Compiling ./contracts/sfc/Staker.sol
> Compiling ./contracts/sfc/StakerConstants.sol
> Compiling ./contracts/test/LegacyStaker.sol
> Compiling ./contracts/test/UnitTestStakers.sol
> Compiling ./contracts/upgradeability/Address.sol
> Compiling ./contracts/upgradeability/BaseUpgradeabilityProxy.sol
> Compiling ./contracts/upgradeability/Proxy.sol
> Compiling ./contracts/upgradeability/UpgradeabilityProxy.sol
> Compiling ./contracts/version/Version.sol
> Artifacts written to /tmp/test-202067-9209-1pixzg8.lv3f
> Compiled successfully using:
   - solc: 0.5.16+commit.9c3226ce.Emscripten.clang



  Contract: SFC
    Delegation migration tests
        gas used for sfc deploying: 4897877
      ✓ should auto migrate legacy deposition to new model (1829ms)
      ✓ should manually migrate legacy deposition to new model (277ms)
      ✓ should not call calcDelegationRewards while delegation is in the legacy model (422ms)

  Contract: SFC
    Locking stake tests
      ✓ should start "locked stake" feature (428ms)
      ✓ should calc raw ValidatorEpochReward correctly after locked up started (1090ms)
      ✓ should lock stake (2413ms)
      ✓ should lock stake with right duration (498ms)
      ✓ should not call prepareToWithdrawStake, until locked time is pass (445ms)
      ✓ should not call prepareToWithdrawStakePartial, until locked time is pass (452ms)
      ✓ should lock delegation (3443ms)
      ✓ should lock delegation with right duration (799ms)
      ✓ should subtract penalty if prepareToWithdrawDelegation will call earlier than locked time is pass (780ms)
      ✓ should subtract penalty if prepareToWithdrawDelegationPartial will call earlier than locked time is pass (825ms)

  Contract: SFC
    Methods tests
      ✓ checking Staker parameters (123ms)
      ✓ checking createStake function (505ms)
      ✓ checking increaseStake function (297ms)
      ✓ checking createDelegation function (456ms)
      ✓ checking createDelegation function to several stakers (568ms)
      ✓ checking calcRawValidatorEpochReward function (367ms)
      ✓ checking epoch snapshot logic (149ms)
      ✓ checking calcValidatorEpochReward function (493ms)
      ✓ checking calcDelegationEpochReward function (445ms)
      ✓ checking claimDelegationRewards function (720ms)
      ✓ checking bonded ratio (101ms)
      ✓ checking claimValidatorRewards function (386ms)
      ✓ checking prepareToWithdrawStake function (212ms)
      ✓ checking withdrawStake function (938ms)
      ✓ checking prepareToWithdrawDelegation function (338ms)
      ✓ checking withdrawDelegation function (1563ms)


  29 passing (25s)

```
