**Special Fee Contract**

The SFC (Special Fee Contract) maintains a list of validation stakers and delegators.
It distributes the rewards, based on information provided by Lachesis node.

SPV contract:
- SPV contract only maintains the list of delegators and validation stakers, and doesn’t calculate scores and validators group. The scores and validators group are written into SPV contract storage by consensus (i.e. golang code) for performance reasons. SPV calculates the rewards, depending on epoch snapshots written by consensus.
- Calculation of reward is O(1) for each epoch. Validator/staker may specify a range of epochs he claims reward for, but not lower than `prev reward epoch` and not higher than `current epoch snapshot`.
- Each delegation is a separate “object”. Delegator claims rewards for each delegation independently of other delegations. Validation staker has counter of delegated tokens to it.
- Validation staker cannot withdraw his stake any time. He must deactivate the stake (prepare to withdraw) in advance of N days.
- If validator is confirmed to be a cheater, then only a flag is written into SPV storage by consensus. SPV checks this flag and allows to withdraw only a portion of original stake during `withdraw` operation.
- Validation staker is allowed to increase his stake, but not decrease (only `prepare to withdraw` first and then `withdraw`).
