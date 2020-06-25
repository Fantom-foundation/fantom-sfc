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
> fantom-sfc@1.0.0 test fantom-sfc
> truffle test

Using network 'test'.


Compiling your contracts...
===========================
> Compiling ./contracts/SafeMath.sol
> Compiling ./contracts/Staker.sol



  Contract: SFC
    Delegation migration tests
        gas used for sfc deploying: 4915131
      ✓ should auto migrate legacy deposition to new model (1699ms)
      ✓ should manually migrate legacy deposition to new model (272ms)
      ✓ should not call calcDelegationRewards while delegation is in the legacy model (404ms)

  Contract: SFC
    Methods tests
      ✓ checking Staker parameters (127ms)
      ✓ checking createStake function (521ms)
      ✓ checking increaseStake function (316ms)
      ✓ checking createDelegation function (473ms)
      ✓ checking createDelegation function to several stakers (581ms)
      ✓ checking calcRawValidatorEpochReward function (385ms)
      ✓ checking epoch snapshot logic (148ms)
      ✓ checking calcValidatorEpochReward function (484ms)
      ✓ checking calcDelegationEpochReward function (462ms)
      ✓ checking claimDelegationRewards function (703ms)
      ✓ checking bonded ratio (107ms)
      ✓ checking claimValidatorRewards function (419ms)
      ✓ checking prepareToWithdrawStake function (272ms)
      ✓ checking withdrawStake function (903ms)
      ✓ checking prepareToWithdrawDelegation function (364ms)
      ✓ checking withdrawDelegation function (1498ms)
    Locked stake tests
      ✓ should start "locked stake" feature (352ms)
      ✓ should calc raw ValidatorEpochReward correctly after locked up started (980ms)
      ✓ should lock stake (2200ms)
      ✓ should lock stake with right duration (505ms)
      ✓ should not call prepareToWithdrawStake, until locked time is pass (441ms)
      ✓ should not call prepareToWithdrawStakePartial, until locked time is pass (447ms)


  25 passing (18s)

```
