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
        uint256 amount;
        address payable owner;
        uint32 creationTime;
        Tariff tariff;
    }

    uint256 constant private BASE_PERCENTAGE = 10000;
    // uint256 constant private SECONDS_PER_MINUTE = 60; // "minutes" alias

    uint256 public totalStakingBalance;
    uint256 public percentagePerMinute;
    uint256 public feePercentage;
    address payable public feeReceiver;

    mapping(Tariff => uint32) public tariffDuration;
    mapping(address => Deposit) public deposits;
    EnumerableSet.AddressSet private depositors;

    event Stake(Deposit deposit, uint256 amount);
    event Withdraw(Deposit deposit, uint256 amount, uint256 reward);

    constructor(
        uint32 _fastTariffDuration,
        uint32 _averageTariffDuration,
        uint32 _slowTariffDuration,
        uint256 _percentagePerMinute,
        uint256 _feePercentage,
        address _feeReceiver
    ) {
        tariffDuration[Tariff.Fast] = _fastTariffDuration;
        tariffDuration[Tariff.Average] = _averageTariffDuration;
        tariffDuration[Tariff.Slow] = _slowTariffDuration;
        percentagePerMinute = _percentagePerMinute;
        feePercentage = _feePercentage;
        feeReceiver = payable(_feeReceiver);
    }

    receive() external payable {
        // TODO: maybe call _checkOwner()
    }

    function configure(
        uint32 _fastTariffDuration,
        uint32 _averageTariffDuration,
        uint32 _slowTariffDuration,
        uint256 _percentagePerMinute,
        uint256 _feePercentage,
        address _feeReceiver
    )
        external
        onlyOwner
    {
        // TODO: maybe add checks
        tariffDuration[Tariff.Fast] = _fastTariffDuration;
        tariffDuration[Tariff.Average] = _averageTariffDuration;
        tariffDuration[Tariff.Slow] = _slowTariffDuration;
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
        uint256 amount = msg.value - fee;
        feeReceiver.transfer(fee); // 21000 gas cost
        Deposit memory deposit = Deposit(
            amount,
            payable(msg.sender),
            uint32(block.timestamp),
            tariff
        );
        deposits[msg.sender] = deposit;
        depositors.add(msg.sender);
        totalStakingBalance += amount;
        emit Stake(deposit, amount);
    }

    function withdraw() external nonReentrant {
        require(
            depositors.contains(msg.sender),
            "user is not a staker"
        );
        Deposit memory deposit = deposits[msg.sender];
        require(
            block.timestamp >=  deposit.creationTime + tariffDuration[deposit.tariff] * 1 minutes,
            "cannot withdraw before completion time"
        );
        address payable depositor = deposit.owner;
        // uint256 reward = calculateReward(deposit.amount, deposit.tariff); // reward = amount + amount * percentagePerMinute * duration
        uint256 reward = deposit.amount * (1 + percentagePerMinute * uint32(tariffDuration[deposit.tariff]) / BASE_PERCENTAGE);
        if (address(this).balance < reward) {
            reward = deposit.amount;
        }

        delete deposits[msg.sender];
        depositors.remove(msg.sender);
        totalStakingBalance -= deposit.amount;

        depositor.transfer(reward);
        emit Withdraw(deposit, deposit.amount, reward);
    }

    function getAmountOfDepositors() external view returns (uint256) {
        return depositors.length();
    }

    function getDepositor(uint256 _index) external view returns (address) {
        return depositors.at(_index);
    }
}
