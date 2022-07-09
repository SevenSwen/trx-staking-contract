//SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./Ownable.sol";
import "./EnumerableSet.sol";
import "./ReentrancyGuard.sol";

contract Vault is Ownable, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;

    enum Tariff {
        Fast,
        Average,
        Slow
    }
    
    struct Deposit {
        address payable owner;
        uint256 amount;
        uint256 creationTime;
        uint256 completionTime;
        Tariff tariff;
    }
    
    uint256 constant private BASE_PERCENTAGE = 10000;
    uint256 constant private SECONDS_PER_MINUTE = 60;
    mapping(address => Deposit) public deposits;
    EnumerableSet.AddressSet private depositors;
    uint256 public fastTariffDuration;
    uint256 public averageTariffDuration;
    uint256 public slowTariffDuration;
    uint256 public totalStakingBalance;
    uint256 public percentagePerMinute;
    uint256 public feePercentage;
    address payable public feeReceiver;

    event Stake(Deposit deposit);
    event Withdraw(Deposit deposit, uint256 reward);
    
    constructor(
        uint256 _fastTariffDuration,
        uint256 _averageTariffDuration,
        uint256 _slowTariffDuration,
        uint256 _percentagePerMinute,
        uint256 _feePercentage,
        address _feeReceiver
    ) {
        fastTariffDuration = _fastTariffDuration;
        averageTariffDuration = _averageTariffDuration;
        slowTariffDuration = _slowTariffDuration;
        percentagePerMinute = _percentagePerMinute;
        feePercentage = _feePercentage;
        feeReceiver = payable(_feeReceiver);
    }
    
    receive() external payable {}
    
    function configure(
        uint256 _fastTariffDuration,
        uint256 _averageTariffDuration,
        uint256 _slowTariffDuration,
        uint256 _percentagePerMinute,
        uint256 _feePercentage,
        address _feeReceiver
    )
        external
        onlyOwner
    {
        fastTariffDuration = _fastTariffDuration;
        averageTariffDuration = _averageTariffDuration;
        slowTariffDuration = _slowTariffDuration;
        percentagePerMinute = _percentagePerMinute;
        feePercentage = _feePercentage;
        feeReceiver = payable(_feeReceiver);
    }
    
    function stake(Tariff tariff) external payable nonReentrant {
        require(
            msg.value > 0,
            "can not stake 0 TRX"
        );
        require(
            !depositors.contains(msg.sender),
            "user is already a staker"
        );
        uint256 fee = msg.value * feePercentage / BASE_PERCENTAGE;
        feeReceiver.transfer(fee);
        uint256 completionTime = getCompletionTime(tariff);
        Deposit memory deposit = Deposit(
            payable(msg.sender),
            msg.value - fee,
            block.timestamp,
            completionTime,
            tariff
        );
        deposits[msg.sender] = deposit;
        depositors.add(msg.sender);
        totalStakingBalance += msg.value - fee;
        emit Stake(deposit);
    }
    
    function withdraw() external nonReentrant {
        require(
            depositors.contains(msg.sender),
            "user is not a staker"
        );
        require(
            block.timestamp >= deposits[msg.sender].completionTime,
            "cannot withdraw before completion time"
        );
        Deposit memory deposit = deposits[msg.sender];
        address payable depositor = deposit.owner;
        uint256 reward = calculateReward(deposit.amount, deposit.tariff);
        if (address(this).balance < reward) {
            reward = deposit.amount;
            depositor.transfer(reward);
        } else {
            depositor.transfer(reward);
        }
        delete deposits[msg.sender];
        depositors.remove(msg.sender);
        totalStakingBalance -= deposit.amount;
        emit Withdraw(deposit, reward);
    }
    
    function getAmountOfDepositors() external view returns (uint256) {
        return depositors.length();
    }
    
    function getDepositor(uint256 _index) external view returns (address) {
        require(
            depositors.length() > 0,
            "empty set"
        );
        require(
            _index < depositors.length(),
            "invalid index"
        );
        return depositors.at(_index);
    }
    
    function calculateReward(uint256 _amount, Tariff tariff) public view returns (uint256) {
        require(
            _amount > 0,
            "invalid amount"
        );
        uint256 reward = _amount;
        if (tariff == Tariff.Fast) {
            reward += _amount * percentagePerMinute * fastTariffDuration / BASE_PERCENTAGE;
        } else if (tariff == Tariff.Average) {
            reward += _amount * percentagePerMinute * averageTariffDuration / BASE_PERCENTAGE;
        } else {
            reward += _amount * percentagePerMinute * slowTariffDuration / BASE_PERCENTAGE;
        }
        return reward;
    }
    
    function getCompletionTime(Tariff tariff) public view returns (uint256) {
        uint256 completionTime;
        if (tariff == Tariff.Fast) {
            completionTime = block.timestamp + fastTariffDuration * SECONDS_PER_MINUTE;
        } else if (tariff == Tariff.Average) {
            completionTime = block.timestamp + averageTariffDuration * SECONDS_PER_MINUTE;
        } else {
            completionTime = block.timestamp + slowTariffDuration * SECONDS_PER_MINUTE;
        }
        return completionTime;
    }
}
