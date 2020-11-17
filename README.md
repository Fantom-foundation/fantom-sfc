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

# Prerequisite
1. Install `ganache-cli`

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
> fantom-sfc@1.0.0 test fantom-sfc
> truffle test

Using network 'test'.


Compiling your contracts...
===========================
> Compiling ./contracts/ownership/Ownable.sol
> Compiling ./contracts/sfc/Migrations.sol
> Compiling ./contracts/sfc/SafeMath.sol
> Compiling ./contracts/sfc/Staker.sol
> Compiling ./contracts/sfc/StakerConstants.sol
> Compiling ./contracts/test/TestStakeTokenizer.sol
> Compiling ./contracts/test/UnitTestStakers.sol
> Compiling ./contracts/upgradeability/Address.sol
> Compiling ./contracts/upgradeability/BaseUpgradeabilityProxy.sol
> Compiling ./contracts/upgradeability/Proxy.sol
> Compiling ./contracts/upgradeability/UpgradeabilityProxy.sol
> Compiling ./contracts/version/Version.sol



  Contract: SFC
    Locking stake tests
      ✓ should start "locked stake" feature (585ms)
      ✓ should calc ValidatorEpochReward correctly after locked up started (1218ms)
      ✓ should lock stake (2394ms)
      ✓ should lock stake with right duration (729ms)
      ✓ should lock delegation (1920ms)
      ✓ should lock delegation with right duration (834ms)
      ✓ should subtract penalty if prepareToWithdrawDelegation will be called earlier than lockup period is passed (1033ms)
      ✓ should subtract penalty if prepareToWithdrawStake will be called earlier than lockup period is passed (1241ms)
      ✓ should subtract penalty if prepareToWithdrawStakePartial will be called earlier than lockup period is passed (1248ms)
      ✓ should adjust penalty if penalty is bigger than delegated stake (612ms)
      ✓ should subtract penalty if prepareToWithdrawDelegationPartial is called earlier than lockup period is passed (1003ms)
      ✓ should claim lockup rewards (2598ms)
      ✓ should claim compound rewards (798ms)
      ✓ should claim compound rewards epoch-by-epoch (543ms)

  Contract: SFC
    Methods tests
      ✓ checking Staker parameters (124ms)
      ✓ checking createStake function (408ms)
      ✓ checking increaseStake function (240ms)
      ✓ checking createDelegation function (402ms)
      ✓ checking createDelegation function to several stakers (481ms)
      ✓ checking calcRawValidatorEpochReward function (304ms)
      ✓ checking epoch snapshot logic (158ms)
      ✓ checking calcValidatorEpochReward function (404ms)
      ✓ checking calcDelegationEpochReward function (354ms)
      ✓ checking claimDelegationRewards function (524ms)
      ✓ checking claimValidatorRewards function (318ms)
      ✓ checking prepareToWithdrawStake function (213ms)
      ✓ checking withdrawStake function (748ms)
      ✓ checking prepareToWithdrawDelegation function (279ms)
      ✓ checking withdrawDelegation function (1266ms)


  29 passing (26s)
```
