// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract StudentSavingsWallet {
    
    // ── STATE VARIABLES ─────────────────────────────────────────────────────

    // Tracks saved ETH per user
    mapping(address => uint256) public balances;

    // Transaction history per user
    struct Transaction {
        uint256 amount;
        uint256 timestamp;
        bool isDeposit;
    }
    mapping(address => Transaction[]) public transactionHistory;

    // Time-lock: user cannot withdraw until this timestamp
    mapping(address => uint256) public unlockTime;

    // Lock duration after deposit (default: 60 seconds for testing)
    uint256 public lockDuration = 60 seconds;

    // Contract owner (the deployer)
    address public immutable owner;

    // ── EVENTS ──────────────────────────────────────────────────────────────

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event LockDurationUpdated(uint256 newDurationInSeconds);

    // ── CONSTRUCTOR ─────────────────────────────────────────────────────────

    constructor() {
        owner = msg.sender;
    }

    // ── MODIFIER ────────────────────────────────────────────────────────────

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    // ── USER FUNCTIONS ──────────────────────────────────────────────────────

    /**
     * @dev Deposit ETH (minimum 0.01 ETH)
     * Resets the user's lock timer to current time + lockDuration
     */
    function deposit() external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        require(msg.value >= 0.01 ether, "Deposit too small - minimum is 0.01 ETH");

        balances[msg.sender] += msg.value;

        transactionHistory[msg.sender].push(Transaction({
            amount: msg.value,
            timestamp: block.timestamp,
            isDeposit: true
        }));

        // Reset lock timer
        unlockTime[msg.sender] = block.timestamp + lockDuration;

        emit Deposited(msg.sender, msg.value);
    }

    /**
     * @dev Withdraw your funds only after the lock period
     */
    function withdraw(uint256 amount) external {
        require(amount > 0, "Withdrawal amount must be greater than 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        require(block.timestamp >= unlockTime[msg.sender], "Funds are still locked");

        balances[msg.sender] -= amount;

        transactionHistory[msg.sender].push(Transaction({
            amount: amount,
            timestamp: block.timestamp,
            isDeposit: false
        }));

        emit Withdrawn(msg.sender, amount);

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Withdrawal failed");
    }

    // ── VIEW FUNCTIONS ──────────────────────────────────────────────────────

    function getBalance(address user) external view returns (uint256) {
        return balances[user];
    }

    function getTransactionHistory(address user)
        external
        view
        returns (Transaction[] memory)
    {
        return transactionHistory[user];
    }

    function getTransactionCount(address user) external view returns (uint256) {
        return transactionHistory[user].length;
    }

    function getRemainingLockTime(address user) external view returns (uint256) {
        if (block.timestamp >= unlockTime[user]) {
            return 0;
        }
        return unlockTime[user] - block.timestamp;
    }

    // ── OWNER FUNCTION ──────────────────────────────────────────────────────

    /**
     * @dev Owner can change the lock duration for all users
     * @param newDuration New lock time in seconds
     */
    function setLockDuration(uint256 newDuration) external onlyOwner {
        require(newDuration > 0, "Lock duration must be greater than 0 seconds");
        lockDuration = newDuration;
        emit LockDurationUpdated(newDuration);
    }
}
