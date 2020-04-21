pragma solidity ^0.5.0;

interface Upgradability {
    function upgradeTo(address newImplementation) external;
}