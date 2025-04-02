// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
event TransactionSubmitted(address indexed to, uint value);
contract MultiSigWallet {
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public required;

    struct Transaction {
        address to;
        uint value;
        bool executed;
        uint confirmations;
    }

    Transaction[] public transactions;
    mapping(uint => mapping(address => bool)) public isConfirmed;

    modifier onlyOwners() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    constructor(address[] memory _owners, uint _required) {
        require(_owners.length > 0, "Owners required");
        require(_required > 0 && _required <= _owners.length, "Invalid required number of owners");

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }
        required = _required;
    }

    function submitTransaction(address _to, uint _value) public onlyOwners {
        require(_to != address(this), "Cannot send ETH to the contract itself"); // 新增检查
        
        transactions.push(Transaction({
            to: _to,
            value: _value,
            executed: false,
            confirmations: 0
        }));
        emit TransactionSubmitted(_to, _value);
    }

    function confirmTransaction(uint transactionId) public onlyOwners {
        require(!isConfirmed[transactionId][msg.sender], "Transaction already confirmed");
        isConfirmed[transactionId][msg.sender] = true;
        
        Transaction storage transaction = transactions[transactionId];
        transaction.confirmations += 1;

        if (transaction.confirmations >= required) {
            executeTransaction(transactionId);
        }
    }

    function executeTransaction(uint transactionId) internal {
        Transaction storage transaction = transactions[transactionId];
        require(transaction.confirmations >= required, "Not enough confirmations");
        require(!transaction.executed, "Transaction already executed");
        
        transaction.executed = true;
        payable(transaction.to).transfer(transaction.value);
    }

    function getTransactionCount() public view returns (uint) {
        return transactions.length;
    }
    
    function isContract(address _addr) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }

    function callAnotherContract(address _contract, bytes memory _data) public onlyOwners {
        require(isContract(_contract), "Not a contract");
        (bool success, ) = _contract.call(_data);
        require(success, "Call failed");
    }

    receive() external payable {}
}
