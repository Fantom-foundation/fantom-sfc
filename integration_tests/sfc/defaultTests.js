const Web3 = require('web3');
const LachesisRpc = require('./lachesisRpc');
const SfcTransactions = require('./sfcTransactions');
const {AccountsHandler} = require('./testaccounts');
const {TransactionStorage} = require('./transactionStorage');
const lachesisContract = require('./lachesis');
const {prevContractBin, newContractBin, smallBin} = require('./bin')
const {abi, upgradabilityProxyAbi, oldContractAbi} = require('./abi');
const chai = require('chai');
chai.use(require('chai-bignumber')());
chai.use(require('chai-as-promised'));
const expect = chai.expect;
const txStorage = new TransactionStorage();

const BN = Web3.utils.BN;
const zeroInt = new BN(0);


class DefaultTests {
    constructor(endpoint, contractAddress, payer) {
        this.endpoint= endpoint;
        this.web3 = new Web3(new Web3.providers.HttpProvider(endpoint));
        this.contractAddress = contractAddress;
        this._sfc = new this.web3.eth.Contract(oldContractAbi, this.contractAddress); // abi
        this.upgradabilityProxy = new this.web3.eth.Contract(upgradabilityProxyAbi, this.contractAddress);
        this.rpc = new LachesisRpc.rpc();
        this.accounts = new AccountsHandler(this.web3, payer);
        this.lachesis = new lachesisContract.lachesis(this.web3, this._sfc, this.contractAddress, this.upgradabilityProxy, txStorage);
    };

    async createStakes(num) {
        let validator = await this.accounts.getPayer();
        const stakers = [];
    
        let stkrNumPrev = new BN(await this.lachesis.transactions.getStakersNum(validator.address));
        for (let i=0;i<num;i++) {
            // let newAcc = accounts.getAccountAtId(101);
            let accValue = "6350000"; // this.web3.utils.toWei("3", 'ether');
            let ethValue = "3175000"; // this.web3.utils.toWei("2", 'ether');
            console.log("ethValue", accValue);
            let newAcc = await this.accounts.createAccountWithBalance(validator, accValue);
            console.log("newAcc", newAcc)
            let tx = await this.lachesis.transactions.createStake(newAcc, ethValue, "0x"); //31750000
            console.log("tx submitted", tx.transactionHash);
    
            let stId = await this.lachesis.transactions.getStakerId(validator.addr, newAcc.address);
            console.log("stId", stId);
            newAcc.stakerId = stId;
            stakers.push(newAcc)
        }
        let stkrNumNew = new BN(await this.lachesis.transactions.getStakersNum(validator.address));
        let expectedStkrNum = new BN(num).add(stkrNumPrev);
        expect(stkrNumNew).to.eql(expectedStkrNum);
        expect(stakers.length).to.eql(num);
        return stakers;
    };
    
    async createStakesAndPrepareToWithdraw(num, numToWithdraw) {
        expect(num).to.be.above(numToWithdraw);
    
        let validator = await this.accounts.getPayer();
        let prevStrNum = new BN(await this.lachesis.transactions.stakersNum(validator.address));
        let stakers = await this.createStakes(num);
        let newStrNum = new BN(await this.lachesis.transactions.stakersNum(validator.address));
        expect(prevStrNum.add(new BN(num))).to.eql(newStrNum);

        await this.forceNewEpochs(stakers[0], 4);
        // await this.sleep(60000); // for withdrowstaker requirements
        
        
        for (let i=0; i < numToWithdraw; i++) {
            console.log("prepare to claimValidatorRewards");
            // await this.collectRewardsAndPrepareWithdrawStake(stakers[i]); // fails here!
            // stakers[i].preparedToWithdraw = true;

            let tx = await this.lachesis.transactions.claimValidatorRewards(stakers[i], 100);
            console.log("tx claimValidatorRewards", tx);
        }

        // await this.forceNewEpochs(stakers[0], 4);

        for (let i=0; i<numToWithdraw; i++) {
            console.log("prepare to  prepareToWithdrawStake");
            // await this.collectRewardsAndPrepareWithdrawStake(stakers[i]); // fails here!
            // stakers[i].preparedToWithdraw = true;
            let accountFrom = stakers[i];

            let stakerId = new BN(await this.lachesis.transactions.sfcAddressToStakerID(accountFrom.address));
            let stkr = await this.lachesis.transactions.getStaker(accountFrom.address, stakerId.toString());
            console.log("prepare to withdraw staker", stkr);

            let cse = await this.lachesis.transactions.currentSealedEpoch(accountFrom.address);
            console.log("currentSealedEpoch", cse);

            let tx = await this.lachesis.transactions.prepareToWithdrawStake(accountFrom);
            console.log("tx prepareToWithdrawStake", tx);
        }
    
        return stakers;
    };
    
    async runNewEpoch() {
        let validator = await this.accounts.getPayer();
    
        const privKey = "0x163f5f0f9a621d72fedd85ffca3d08d131ab4e812181e0d30ffd1c885d20aac7";
        let tx = await this.lachesis.transactions.advanceEpoch(validator.address);
        console.log("tx submitted", tx.transactionHash);
        return this.rpc.currentEpoch();
    };
    
    async collectRewardsAndPrepareWithdrawStake(accountFrom) {
        console.log("start prepareToWithdrawStake for", accountFrom);
        const stakerId = new BN(await this.lachesis.transactions.sfcAddressToStakerID(accountFrom.address));
        console.log("stakerId for addr", accountFrom.address, ":", stakerId.toString());
        expect(stakerId).not.to.eql(zeroInt);

        let tx = await this.lachesis.transactions.claimValidatorRewards(accountFrom, 100);
        console.log("tx claimValidatorRewards", tx);

        await this.forceNewEpochs(accountFrom, 4);

        let stkr = await this.lachesis.transactions.getStaker(accountFrom.address, stakerId.toString());
        console.log("prepare to withdraw staker", stkr);

        let cse = await this.lachesis.transactions.currentSealedEpoch(accountFrom.address);
        console.log("currentSealedEpoch", cse);

        tx = await this.lachesis.transactions.prepareToWithdrawStake(accountFrom);
        console.log("tx prepareToWithdrawStake", tx);
        return tx;
    };
    
    async runTests() {
        let createdData = await this.testsBeforeUpdate();
        await this.updateContract();
        let stakers = await this.testsAfterUpdate(createdData);
        await finalTests(stakers);
    };
    
    async createDelegation(accountFrom = null, to, amt) {
        let validator = await this.accounts.getPayer();
        let newAcc = await this.accounts.createAccountWithBalance(validator, "3175000");
        console.log("prepare to createDelegation");
        console.log("newAcc for validation", newAcc);

        let tx = await this.lachesis.transactions.createDelegation(to, newAcc, amt);
        console.log("newDelegation tx", tx);
        return newAcc;
    };
    
    async createDelegations(stakers, delegatorsForEachStaker) {
        let delegatorsMap = {};
        for (let i=0;i<stakers.length;i++){
            delegatorsMap[stakers[i]] = [];
            for(let j=0;j<delegatorsForEachStaker;j++) {
                let delegator = await this.createDelegation(stakers[i]);
                delegatorsMap[stakers[i]].push(delegator)
            }
        }
        return delegatorsMap;
    };
    
    // withdraws "withdrawNum" delegations from each given staker
    async prepareToWithdrawDelegations(stakers, delegatorsMap, maxWithdrawNum) {
        for (let i=0; i<stakers.length;i++) {
            let delegators = delegatorsMap[stakers[i]];
            if (!delegators || delegators.length > 0)
                throw("incorrect delegators map passed")
            
            let numToWithdraw = delegators.length <= maxWithdrawNum ? delegators.length : maxWithdrawNum;
            for (j=0; j<numToWithdraw; j++) {
                let tx = await this.lachesis.transactions.prepareToWithdrawDelegation(delegators[j].address)
                console.log("prepareToWithdrawDelegations tx", tx);
            }
        }
    };
    
    async createDelegationsAndPrepareToWithdraw(stakers, delegatorsForEachStaker) {
        const delegatorsMap = await this.createDelegations(stakers, delegatorsForEachStaker);
        const maxWithdrawNum = delegatorsForEachStaker; // default logic is to prepare to withdraw every created delegator
        await this.prepareToWithdrawDelegations(stakers, delegatorsMap, maxWithdrawNum)
    
        return delegatorsMap
    };
    
    async testsBeforeUpdate() {
        const stakersToCreate = 1; // expected 3 or more in prod
        const delegatorsForEachStaker = 1;
    
        const stakers = await this.createStakesAndPrepareToWithdraw(stakersToCreate);
        const delegatorsMap = await this.createDelegationsAndPrepareToWithdraw(stakers, delegatorsForEachStaker)
    
        return {stakers: stakers, delegatorsMap: delegatorsMap};
    };

    // this is a temprorary and incomplete set of test cases.
    // it is assumed that complete tests will run inside runTests() func
    // running basicTests() leads to a following logic:
    // 1) creates two stakers, withdraws first before update and second after update.
    // 2) creates two delegations. withdraws first before update and second after update.
    //
    // It doesnt
    async basicTests() {
        let validator = await this.accounts.getPayer();
        let stakersNumAtStart = new BN(await this.lachesis.transactions.stakersNum(validator.address));
        let stkrs = await this.createStakes(2);
        let stakersNum = new BN(await this.lachesis.transactions.stakersNum(validator.address));
        let expectedStakersNum = stakersNumAtStart.add(new BN("2"));
        expect(stakersNum).to.eql(expectedStakersNum);

        console.log("prepare to createAndWithdrawDelegation");
        try {
            await this.createAndWithdrawDelegation(stkrs[0]);
        } catch (e) {
            console.log("contract is old")
        };

        let stakerId = await this.lachesis.transactions.sfcAddressToStakerID(stkrs[0].address);
        expect(parseInt(stakerId)).to.be.above(0);
        await this.forceNewEpochs(stkrs[0], 1);

        // await this.collectRewardsAndPrepareWithdrawStake(stkrs[0]);
        // await this.collectRewardsAndPrepareWithdrawStake(stkrs[1]);

        let numToWithdraw = stkrs.length;
        for (let i=0; i < numToWithdraw; i++) {
            try {
                console.log("prepare to claimValidatorRewards");
                // await this.collectRewardsAndPrepareWithdrawStake(stakers[i]); // fails here!
                // stakers[i].preparedToWithdraw = true;

                let tx = await this.lachesis.transactions.claimValidatorRewards(stkrs[i], 100);
                console.log("tx claimValidatorRewards", tx);
            } catch(e) {
                console.log("contract is old")
            };
        };

        // await this.forceNewEpochs(stakers[0], 4);

        for (let i=0; i<numToWithdraw; i++) {
            console.log("prepare to  prepareToWithdrawStake");
            // await this.collectRewardsAndPrepareWithdrawStake(stakers[i]); // fails here!
            // stakers[i].preparedToWithdraw = true;
            let accountFrom = stkrs[i];

            let stakerId = new BN(await this.lachesis.transactions.sfcAddressToStakerID(accountFrom.address));
            let stkr = await this.lachesis.transactions.getStaker(accountFrom.address, stakerId.toString());
            console.log("prepare to withdraw staker", stkr);

            let cse = await this.lachesis.transactions.currentSealedEpoch(accountFrom.address);
            console.log("currentSealedEpoch", cse);

            let tx = await this.lachesis.transactions.prepareToWithdrawStake(accountFrom);
            console.log("tx prepareToWithdrawStake", tx);
        };

        await this.sleep(60000); // for withdrowstaker requirements
        await this.forceNewEpochs(stkrs[0], 4);

        await this.withdrawStaker(stkrs[1]);
        stakersNum = new BN(await this.lachesis.transactions.stakersNum(validator.address));
        expectedStakersNum = stakersNumAtStart.add(new BN("1"));
        expect(stakersNum).to.eql(expectedStakersNum);

        console.log("--------------");
        console.log("E. Upgrade SFC");
        await this.updateContract();
        console.log("updated contract");

        this.web3 = new Web3(new Web3.providers.HttpProvider(this.endpoint));
        this._sfc = new this.web3.eth.Contract(abi, this.contractAddress); // abi
        let lachesis = new lachesisContract.lachesis(this.web3, this._sfc, this.contractAddress, this.upgradabilityProxy, txStorage);

        // return;
        try {
            await this.upgradeStakersStorage(lachesis)
        } catch (e) {
            console.log("upgradeStakersStorage error:", e);
            console.log("new contract may possibly be the same as previous");
        }
        // await this.withdrawStakerNew();
        let accountFrom = stkrs[0]
        await this._testsAfterUpdate(accountFrom, lachesis);
        stakersNum = new BN(await lachesis.transactions.stakersNum(validator.address));
        expectedStakersNum = stakersNumAtStart;
        expect(stakersNum).to.eql(expectedStakersNum);
    };

    async _testsAfterUpdate(accountFrom, newLachesis) {
        // let accountFrom = stkrs[1]
        console.log("prepare to withdraw staker");
        // console.log("new sfc 1", this._sfc);
        // console.log("new sfc 2", lachesis.sfc);

        let stakerId = new BN(await newLachesis.transactions.sfcAddressToStakerIDNew(accountFrom.address));
        console.log("withdrawStaker stakerId", stakerId.toString());

        // let tx = await newLachesis.transactions.claimValidatorRewards(accountFrom, 100);
        // console.log("tx claimValidatorRewards", tx);

        console.log("prepare to get staker info");
        const stakerInfo = await newLachesis.transactions.getStaker(accountFrom.address, stakerId.toString());
        console.log("checking requirements");
        const stakeLockPeriodTime = await newLachesis.transactions.stakeLockPeriodTime();
        const stakeLockPeriodEpochs = await newLachesis.transactions.stakeLockPeriodEpochs();
        console.log("stakeLockPeriodTime", stakeLockPeriodTime);
        console.log("stakeLockPeriodEpochs", stakeLockPeriodEpochs);
        console.log("stakerInfo of withdrawer", stakerInfo);

        const currentSealedEpoch = await newLachesis.transactions.currentSealedEpoch(accountFrom.address);
        console.log("currentSealedEpoch", currentSealedEpoch);

        let tx = await newLachesis.transactions.withdrawStake(accountFrom);
        console.log("withdrawStaker tx:", tx);
    };

    async createStakersAndUpdate() {
        let stkrs = await this.createStakes(2);
        this.createDelegation();
        await this.updateContract(stkrs);
    };

    async createStakersAndDelegations() {
        let stkrs = await this.createStakes(1);
        let rawStkrId = await this.lachesis.transactions.sfcAddressToStakerID(stkrs[0].address);
        console.log("rawStkrId", rawStkrId);

        let stakerInfo = await this.lachesis.transactions.getStaker(stkrs[0].address, rawStkrId);
        console.log("stakerInfo", stakerInfo);

        let delegator = await this.createDelegation(stkrs[0], rawStkrId, "2");
        console.log("delegator", delegator);
    };

    async createAndWithdrawDelegation(stkr) {
        let rawStkrId = await this.lachesis.transactions.sfcAddressToStakerID(stkr.address);
        console.log("rawStkrId", rawStkrId);

        let stakerInfo = await this.lachesis.transactions.getStaker(stkr.address, rawStkrId);
        console.log("stakerInfo", stakerInfo);

        let delegators = await this.createDelegations(stkr, rawStkrId, "2", 1);
        console.log("delegator", delegators[0]);

        await this.collectRewardsAndWithdrawDelegation(delegators[0], stkr);
    };

    async createDelegations(stkr, stkrId, val, num) {
        let delegators = [];
        for(let i=0; i<num; i++) {
            let delegator = await this.createDelegation(stkr, stkrId, val);
            delegators.push(delegator);
            console.log("delegator", delegator);
        }
        return delegators;
    };

    async collectRewardsAndWithdrawDelegation(accountFrom, epochUpdater) {
        // let stkr = await this.lachesis.transactions.getStaker(accountFrom.address, stakerId.toString());
        // console.log("prepare to withdraw staker", stkr);

        let delegator = await this.lachesis.transactions.getDelegation(accountFrom.address, accountFrom.address);
        console.log("withdrawing delegator", delegator);

        await this.forceNewEpochs(epochUpdater, 1);

        await this.mustPrepareToWithdrawDelegation(accountFrom)

        await this.forceNewEpochs(epochUpdater, 3);
        await this.sleep(60000); // for withdrowstaker requirements

        let tx = await this.lachesis.transactions.withdrawDelegation(accountFrom);
        console.log("tx withdrawDelegation", tx);
    };

    async mustPrepareToWithdrawDelegation(accountFrom) {
        let tx = await this.lachesis.transactions.claimDelegationRewards(accountFrom, 2);
        console.log("tx claimValidatorRewards", tx);

        tx = await this.lachesis.transactions.prepareToWithdrawDelegation(accountFrom);
        console.log("tx prepareToWithdrawDelegation", tx);
    };

    async createDelegationAndCheck() {

    };

    async forceNewEpochs(sender, n, recoursive) {
        for(let i=0;i<n;i++) {// setting proper epochs
            try {
                await this.lachesis.forceNewEpoch(sender);
            } catch (e) {
                console.log("forceNewEpochs error:", e);
                if (recoursive) {
                    let epochsToForce = n - i;
                    console.log("forcing to continue epoch advancing. new epochs to run:", epochsToForce);
                    await this.forceNewEpochs(sender, epochsToForce, true);
                }
            }
        }    
    };

    async sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    };    

    async _findLastTx() {
        let num = 100;
        let b = await this.lachesis.findLastTransaction(num)
        console.log("b", b)
    };
    
    async updateContract() {
        let validator = await this.accounts.getPayer();
        let implementation = await this.lachesis.proxyImplementation(validator.address);
        console.log("implementation at start", implementation);
        let tx = await this.lachesis.updateContract(validator, newContractBin);
        if (tx != null && tx != undefined) {
            console.log("contract tx!!!!!!", tx)
        }

        let depth = 100;
        let lastTransactionsHashes = await this.lachesis.findLastTransaction(depth);
        if (!lastTransactionsHashes)
            throw('last tx hash is undefined');
        if (lastTransactionsHashes.length > 1)
            throw('cannot handle multiple transactions');

        let updateContractTxHash = lastTransactionsHashes[0];
        console.log("updateContract tx hash", updateContractTxHash);
        let updateContractTxReceipt = await this.lachesis.rpc.getTransactionReceipt(updateContractTxHash);
        console.log("updateContractTxReceipt", updateContractTxReceipt);
        const newContractAddress = updateContractTxReceipt.result.contractAddress;
        if (!newContractAddress)
            throw("no contract address found")

        await this.lachesis.upgradeTo(validator, newContractAddress);
        implementation = await this.lachesis.proxyImplementation(validator.address);
        console.log("implementation at the end", implementation);
    };

    async upgradeStakersStorage(newLachesis) {
        let validator = await this.accounts.getPayer();
        let stakersNumRaw = await newLachesis.transactions.stakersNum();
        let stakersNum = parseInt(stakersNumRaw);

        for (let i=1; i<=stakersNum; i++) {
            console.log("prepare to update staker with id", i)
            await newLachesis.transactions.upgradeStakerStorage(validator, i.toString());
        }
        // for (let i=0; stakers && i<stakers.length; i++) {
        //     let rawStkrId = await this.lachesis.transactions.sfcAddressToStakerID(stakers[i].address);
        //     console.log("rawStkrId", rawStkrId);
        //     let stakerId = new BN(rawStkrId);
        //     console.log("prepare to upgrade storage of staker", stakerId.toString());
        //     let stkr = await this.lachesis.transactions.getStaker(validator.address, stakerId.toString());
        //     console.log("stkr", stkr);
        //     await this.lachesis.transactions.upgradeStakerStorage(validator, stakerId.toString());
        // }
    };

    async testsBeforeUpdateOnly() {
        console.log("prepare to start tests before update");
        let validator = await this.accounts.getPayer();
        let stakersNumAtStart = new BN(await this.lachesis.transactions.stakersNum(validator.address));
        let stkrs = await this.createStakes(2);
        let stakersNum = new BN(await this.lachesis.transactions.stakersNum(validator.address));
        let expectedStakersNum = stakersNumAtStart.add(new BN("2"));
        expect(stakersNum).to.eql(expectedStakersNum);

        console.log("prepare to createAndWithdrawDelegation");
        await this.createAndWithdrawDelegation(stkrs[0]);

        let stakerId = await this.lachesis.transactions.sfcAddressToStakerID(stkrs[0].address);
        expect(parseInt(stakerId)).to.be.above(0);
        await this.forceNewEpochs(stkrs[0], 1);

        await this.collectRewardsAndPrepareWithdrawStake(stkrs[0]);
        await this.collectRewardsAndPrepareWithdrawStake(stkrs[1]);
        await this.sleep(60000); // for withdrowstaker requirements
        await this.forceNewEpochs(stkrs[0], 4);

        await this.withdrawStaker(stkrs[0]);
        stakersNum = new BN(await this.lachesis.transactions.stakersNum(validator.address));
        expectedStakersNum = stakersNumAtStart.add(new BN("1"));
        expect(stakersNum).to.eql(expectedStakersNum);

        console.log("staker to use after updates", stkrs[0]);
    };

    async testsAfterUpdateOnly() {
        console.log("tests after update");
    };
    
    async deployContract() {
        // console.log(web3.eth.coinbase);
        let tx = await this.lachesis.transactions.deployContract(abi, newContractBin);
        console.log("deployContract tx:", tx);
    };
    
    async withdrawStakerNew(accountFrom) {
        console.log("prepare to withdraw staker");
        console.log("new sfc", this.lachesis.sfc);
        const stakerId = new BN(await this.lachesis.transactions.sfcAddressToStakerIDNew(accountFrom.address));
        console.log("withdrawStaker stakerId", stakerId.toString());
        const stakerInfo = await this.lachesis.transactions.getStaker(accountFrom.address, stakerId.toString());
        console.log("checking requirements");
        const stakeLockPeriodTime = await this.lachesis.transactions.stakeLockPeriodTime();
        const stakeLockPeriodEpochs = await this.lachesis.transactions.stakeLockPeriodEpochs();
        console.log("stakeLockPeriodTime", stakeLockPeriodTime);
        console.log("stakeLockPeriodEpochs", stakeLockPeriodEpochs);
        console.log("stakerInfo of withdrawer", stakerInfo);

        const currentSealedEpoch = await this.lachesis.transactions.currentSealedEpoch(accountFrom.address);
        console.log("currentSealedEpoch", currentSealedEpoch);

        let tx = await this.lachesis.transactions.withdrawStake(accountFrom);
        console.log("withdrawStaker tx:", tx);
    };

    async withdrawStaker(accountFrom) {
        console.log("prepare to withdraw staker");
        const stakerId = new BN(await this.lachesis.transactions.sfcAddressToStakerID(accountFrom.address));
        console.log("withdrawStaker stakerId", stakerId.toString());
        const stakerInfo = await this.lachesis.transactions.getStaker(accountFrom.address, stakerId.toString());
        console.log("checking requirements");
        const stakeLockPeriodTime = await this.lachesis.transactions.stakeLockPeriodTime();
        const stakeLockPeriodEpochs = await this.lachesis.transactions.stakeLockPeriodEpochs();
        console.log("stakeLockPeriodTime", stakeLockPeriodTime);
        console.log("stakeLockPeriodEpochs", stakeLockPeriodEpochs);
        console.log("stakerInfo of withdrawer", stakerInfo);

        const currentSealedEpoch = await this.lachesis.transactions.currentSealedEpoch(accountFrom.address);
        console.log("currentSealedEpoch", currentSealedEpoch);

        let tx = await this.lachesis.transactions.withdrawStake(accountFrom);
        console.log("withdrawStaker tx:", tx);
    };
    
    async withdrawDelegation(from) {
        let tx = await this.lachesis.transactions.withdrawDelegation(from);
        console.log("withdrawDelegation tx:", tx);
    };
    
    async testIncreaseStake(from, amount) {
        const stakerId = await this.lachesis.transactions.sfcAddressToStakerID(from);
        expect(stakerId).to.be.above(0);
    
        let staker = await this.lachesis.transactions.stakers(stakerId);
        let prevStakeAmount = new BN(staker.stakeAmount);
        let tx = await this.lachesis.transactions.increaseStake(from, amount);
        console.log("testIncreaseStake tx:", tx);
    
        staker = await this.lachesis.transactions.stakers(stakerId);
        let newStakeAmount = new BN(staker.stakeAmount);
        expect(newStakeAmount).to.eql(prevStakeAmount.add(new BN(amount)))
    };
    
    // change to new address and then change again to previous
    async testChangeStakerAddress(from) {
        let newAcc = accounts.getNextAccount();
        let stakerId = await this.lachesis.transactions.sfcAddressToStakerID(from);
        expect(stakerId).to.be.above(0);
        const startStakerId = stakerId;
        let staker = await this.lachesis.transactions.stakers(stakerId);
    
        let tx = await this.lachesis.transactions.updateStakerSfcAddress(from, newAcc.address)
        console.log("updateStakerSfcAddress tx:", tx);
        stakerId = await this.lachesis.transactions.sfcAddressToStakerID(newAcc.address);
        const intermediateStakerId = stakerId;
        expect(stakerId).to.be.above(0);
        expect(intermediateStakerId).to.eql(startStakerId);
        
        tx = await this.lachesis.transactions.updateStakerSfcAddress(newAcc.address, from);
        console.log("updateStakerSfcAddress tx:", tx);
        stakerId = await this.lachesis.transactions.sfcAddressToStakerID(from);
        const lastStakerId = stakerId;
        expect(stakerId).to.be.above(0);
        expect(lastStakerId).to.eql(intermediateStakerId);
        expect(lastStakerId).to.eql(startStakerId);
    };
    
    // didnt run yet
    async testMarkAsCheater(from) {
        const cheaterMetadata = "0x1" // not sure if it works
        let stakerId = await this.lachesis.transactions.sfcAddressToStakerID(from);
        let metadata = await this.lachesis.transactions.sfc.stakerMetadata(stakerId);
        let tx = await this.lachesis.transactions.updateStakerMetadata(stakerId, cheaterMetadata);
        metadata = await this.lachesis.transactions.sfc.stakerMetadata(stakerId);
        // check metadata == cheaterMetadata;
        console.log("updateStakerSfcAddress tx:", tx);
    };
    
    async punishCheater(from) {
        this.withdrawStaker(from) // error here?
    };
    
    async markStakerAsCheaterAndPunish(stakerAddress) {
        let stakerId = await this.lachesis.transactions.sfcAddressToStakerID(stakerAddress);
        expect(stakerId).to.be.above(0); // staker exists
        await this.testMarkAsCheater(stakerAddress);
        await this.punishCheater(stakerAddress);
    };
    
    async testsAfterUpdate(createdData) {
        let stakers = createdData.stakers;
        let delegatorsMap = createdData.delegatorsMap;
        let increaseStakeDefaultAmt = 2; // min stake amt is currently = 1
        for (let i=0; i<stakers.length; i++) {
            if (stakers[i].preparedToWithdraw) {
                await this.withdrawStaker(stakers[i].address);
            }
            if (delegatorsMap[stakers[i]] && delegatorsMap[stakers[i]].length > 0) {
                let stakerDelegations = delegatorsMap[stakers[i]];
                for (let i=0; i<stakerDelegations.length; i++) {
                    const delegation = stakerDelegations[i];
                    await this.withdrawDelegation(delegation.address)
                }
            }
        }
    
        let notWithdrawnStakers = stakers.filter((item) => {
            return !item.preparedToWithdraw;
        })
    
        for (let i=0; i<notWithdrawnStakers.length; i++) {
            let staker = notWithdrawnStakers[i];
            await this.testIncreaseStake(staker.address, increaseStakeDefaultAmt);
            await this.testChangeStakerAddress(staker.address);
        }
    
        return notWithdrawnStakers;
    };
    
    async finalTests(stakers) {
        return // temprorary turn function off
        for (let i=0; i<stakers.length; i++) {
            await this.testMarkAsCheater(stakers[i]);
        }
        const connectedNodesNum = await this.getConnectedNodesNum();
        expect(connectedNodesNum).to.eql(0);
    };
    
    // this should return 0 at the end of tests
    // calls RPC method (but what method?)
    async getConnectedNodesNum() {
        // temprorary mock
        return 0;
    };
    
};

module.exports.DefaultTests = DefaultTests;