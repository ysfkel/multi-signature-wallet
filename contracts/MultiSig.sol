pragma solidity 0.7.5;

contract MultiSig{

    address private _admin;

    uint public constant quorum = 2;

    uint private nextTransactionId;

    uint[] private _pendingTransactions;

    enum Authorization {
        NONE,
        OWNER,
        DEACTIVATED
    }

    struct Transaction {
        uint id; 
        uint amount;
        address payable to;
        address createdBy;
        uint signatureCount;
        bool completed;
    }

    mapping(address => Authorization) private owners;

    mapping(uint => Transaction) transactions;

    mapping(uint => mapping(address => bool)) signatures;

    event TransactionCreated(uint nextTransactionId, address createdBy, address to,  uint amount);
    event TransactionCompleted(uint transactionId, address to, uint amount, address createdBy, address executedBy);
    event TransactionSigned(uint transactionId, address signer);
    event NewOwnerAdded(address newOwner);
    event FundsDeposited(address from, uint amount);

    constructor() 
      payable {
          _admin = msg.sender;
          owners[msg.sender] = Authorization.OWNER;
    }

    receive() external payable{
         emit FundsDeposited(msg.sender, msg.value);
    }

    function addOwner(address newOwner) isAdmin external {
          require(newOwner != address(0), "invalid address");
          require(owners[newOwner] == Authorization.NONE, "address already an owner");
          owners[newOwner] = Authorization.OWNER;
          emit NewOwnerAdded(newOwner);
    }

     function deactivateOwner(address addr) isAdmin external {
          require(addr != address(0), "invalid address");
          owners[addr] = Authorization.DEACTIVATED;
     }
     
     function activateOwner(address addr) isAdmin external {
          require(addr != address(0), "invalid address");
          owners[addr] = Authorization.OWNER;
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

    function getPendingTransactions() external view returns(uint[] memory){
        return _pendingTransactions;
    }

    function getTransactionSignatureCount(uint transactionId) external view returns(uint) {
        require(transactions[transactionId].to != address(0), "transaction does not exist");
        return transactions[transactionId].signatureCount;
    }

    function signTransation(uint id) isValidOwner external {
            require(transactions[id].to != address(0), "transaction does not exist");
            require(transactions[id].createdBy != msg.sender,"transaction creator cannot sign transaction");
            require(signatures[id][msg.sender] == false, "cannot sign transaction more than once");
            
            Transaction storage transaction = transactions[id];
            signatures[id][msg.sender] = true;
            transaction.signatureCount++; 
            emit TransactionSigned(id, msg.sender);
    }

    function executeTransaction(uint id) isValidOwner external {
         require(transactions[id].to != address(0), "transaction does not exist");
         require(transactions[id].completed == false, "transactions has already been completed");
         require(transactions[id].signatureCount >= quorum, "transaction requires more signatures");
         require(address(this).balance >= transactions[id].amount, "insufficient balance");

        transactions[id].completed = true;
        address payable to = transactions[id].to;
        uint amount = transactions[id].amount;
        to.transfer(amount);
        emit TransactionCompleted(id, to, amount, transactions[id].createdBy, msg.sender);
    }

    function getBalance() external view returns(uint) {
        return address(this).balance;
    }

    modifier isAdmin() {
        require(_admin == msg.sender);
        _;
    }

    modifier isValidOwner() {
        require(owners[msg.sender] == Authorization.OWNER, "you must have owner authorization to create transaction");
        _;
    }
}