pragma solidity ^0.5.0;

import "./SafeMath.sol";

// LRC - "least resistant consesus". more detailed description can be taken from docs
library LRC {
    using SafeMath for uint256;

    uint256 constant OptionsNum = 5;
    uint256 constant rebaseScale = 10000;
    uint256 constant levelOfDissagnation = OptionsNum - 1; //
    uint256 constant maxScale = 5;
    // mapping(uint256 => uint256) scales;

    struct Opinion {
        string description;
        uint256 totalVotes;
    }

    struct LrcOption {
        string description;
        uint256 arc;
        uint256 dw;
        Opinion[OptionsNum] opinions;
        uint256 resistance;
        uint256 totalVotes;
        uint256 maxPossibleVotes;
    }

    struct LRCChoise {
        string[] choises;
        uint256 power;
    }

    // function addScale(uint256 scale, uint256 idx) public {
    //    scales[idx] = scale;
    // }

    function recalculate(LrcOption storage self) public {
        calculateARC(self);
        calculateDW(self);
    }

    function calculateARC(LrcOption storage self) public {
        uint256 maxPossibleResistance = self.totalVotes * maxScale;
        uint256 rebasedActualResistance = self.resistance * rebaseScale;
        self.arc = rebasedActualResistance / maxPossibleResistance;
    }

    function calculateDW(LrcOption storage self) public {
        uint256 totalDessignation;
        for (uint256 i = levelOfDissagnation; i < OptionsNum; i++) {
            totalDessignation += self.opinions[i].totalVotes;
        }

        uint256 dessignationRebased = totalDessignation * rebaseScale;
        self.dw = dessignationRebased / self.totalVotes;
    }

    function calculateRawCount(LrcOption storage self) public {
        
    }

    function addVote(LrcOption storage self, uint256 opinionId, uint256 power) public {
        require(opinionId < OptionsNum, "inappropriate opinion id");
        self.opinions[opinionId].totalVotes += power;

        uint256 scale;
        if (opinionId == OptionsNum - 1) {
            scale = OptionsNum;
        }
        scale = opinionId;

        self.totalVotes += power;
        self.resistance += power * scale;
    }

    function removeVote(LrcOption storage self, uint256 opinionId, uint256 power) public {
        require(opinionId < OptionsNum, "inappropriate opinion id");
        self.opinions[opinionId].totalVotes -= power;

        uint256 scale;
        if (opinionId == OptionsNum - 1) {
            scale = OptionsNum;
        }
        scale = opinionId;

        self.totalVotes -= power;
        self.resistance -= power * scale;
    }
}