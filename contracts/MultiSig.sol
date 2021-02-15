pragma solidity 0.7.5;

contract MultiSig{

    address private _admin;

    uint public constant quorum = 2;

    uint private nextTransactionId;

    uint[] private _pendingTransactions;

    struct Transaction {
        uint id; 
        uint amount;
        address payable to;
        address createdBy;
        uint signatureCount;
        bool completed;
    }

    mapping(address => bool) private owners;

    mapping(uint => Transaction) transactions;

    mapping(uint => mapping(address => bool)) signatures;

    event TransactionCreated(uint nextTransactionId, address createdBy, address to,  uint amount);
    event TransactionCompleted(uint transactionId, address to, uint amount, address createdBy, address executedBy);
    event TransactionSigned(uint transactionId, address signer);
    event NewOwnerAdded(address newOwner);

    constructor() 
      payable {
          _admin = msg.sender;
          owners[msg.sender] = true;
    }

    function addOwner(address newOwner) isAdmin external {
          require(newOwner != address(0), "invalid address");
          require(owners[newOwner] == false, "address already an owner");
          owners[newOwner] = true;
          emit NewOwnerAdded(newOwner);
    }

    function createTransfer(uint amount, address payable to) isValidOwner external {

        nextTransactionId++;  
         
        transactions[nextTransactionId]= Transaction({
              id:nextTransactionId,
              amount: amount,
              to: to,
              createdBy: msg.sender,
              signatureCount: 0,
              completed: false
        });

        _pendingTransactions.push(nextTransactionId);
        emit TransactionCreated(nextTransactionId, msg.sender, to, amount);
    }

    function signTransation(uint id) isValidOwner external {
            require(transactions[id].to != address(0), "transaction does not exist");
            require(transactions[id].createdBy != msg.sender,"transaction creator cannot sign transaction");
            require(signatures[id][msg.sender] == false, "cannot sign transaction more than once");

            signatures[id][msg.sender] = true;
            emit TransactionSigned(id, msg.sender);
    }

    function executeTransaction(uint id) isValidOwner external {
         require(transactions[id].to != address(0), "transaction does not exist");
         require(transactions[id].completed != false, "transactions has already been completed");
         require(transactions[id].signatureCount >= quorum, "transaction requires more signatures");
         require(address(this).balance >= transactions[id].amount, "insufficient balance");

        transactions[id].completed = true;
        address payable to = transactions[id].to;
        uint amount = transactions[id].amount;
        to.transfer(amount);
        emit TransactionCompleted(id, to, amount, transactions[id].createdBy, msg.sender);
    }

    modifier isAdmin() {
        require(_admin == msg.sender);
        _;
    }

    modifier isValidOwner() {
        require(owners[msg.sender] == true);
        _;
    }
}