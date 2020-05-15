
pragma solidity ^0.5.0;


contract ImplementationValidator {

    string[] methodsOfAContract;

    constructor(/*bytes32[] memory _methodsOfAContract*/) public {
        // TODO: find a way to do it
        // for (uint256 i = 0; i < _methodsOfAContract.length; i++) {
        //     bytes32 b32Method = _methodsOfAContract[i];
        //     string memory method = b32Method;
        //     methodsOfAContract.push(method);
        // }
        // string memory method = string(_methodsOfAContract);
        // methodsOfAContract.push(method);
    }

    function checkContractIsValid(address addr) public {
        address testAddr = address(0);

        require(isContract(addr), "address does not belong to a contract");
        // we assume that a fall won't happen if a zero address is passed
        for (uint i = 0; i<methodsOfAContract.length; i++) {
            string memory method = methodsOfAContract[i];
            bytes memory payload = abi.encodeWithSignature(method, testAddr);
            string memory errorMsg = string(abi.encodePacked(method, " is not implemented by contract"));
            (bool success, ) = addr.call(payload);
            require(success, errorMsg);
        }
    }

    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(account) }
        return size > 0;
    }
}