// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/* Staking Contract
#  How to add reward
1. Owner can allow a user to add reward on the contract.
2. Allowed user can add a reward on the contract.
#  Stake
1. User deposits an amount of ERC20 tokens for a period.
2. User withdraws its balance with a reward of 2% of the amount.
*/
contract Staking is Ownable {
  // The IERC20 token
  IERC20 public _ierc20;

  // Last user's deposit time.
  mapping(address => uint256) private _lastDepositTime;
  // User's balance.
  mapping(address => uint256) private _balances;
  // User's reward allowance.
  mapping(address => uint256) private _rewardAllowances;

  // The staking reward percent.
  uint256 public _percentReward = 2;
  // The total reward.
  uint256 public rewardTotal = 0;
  // The total amount staked.
  uint256 public totalStaked = 0;
  // The duration of the staking period.
  uint256 public _duration = 4 weeks;

  constructor(IERC20 ierc20) {
    _ierc20 = ierc20;
  }

  event Duration(uint256 duration);
  event AddReward(address account, uint256 amount);
  event ApproveReward(address account, uint256 amount);
  event Deposit(address account, uint256 amount);
  event Withdraw(address account, uint256 amount);

  /// @notice Set staking duration.
  /// @param duration The duration to be set.
  function setDuration(uint256 duration) public onlyOwner {
    require(duration >= 1 weeks, "Duration should be at least 1 week.");
    _duration = duration;

    emit Duration(duration);
  }

  /// @notice Add a reward on the staking contract.
  /// @param amount The amount of the reward.
  function addReward(uint256 amount) public {
    require(
      _rewardAllowances[_msgSender()] >= amount,
      "Retrieval value exceed authorized limit."
    );
    _rewardAllowances[_msgSender()] = _rewardAllowances[_msgSender()] - amount;
    rewardTotal = rewardTotal + amount;
    _ierc20.transferFrom(_msgSender(), address(this), amount);

    emit AddReward(_msgSender(), amount);
  }

  /// @notice Approve a user for adding a reward on the staking contract.
  /// @param amount The amount approved for user.
  function approveReward(address _spender, uint256 amount) public onlyOwner {
    _rewardAllowances[_spender] = amount;

    emit ApproveReward(_msgSender(), amount);
  }

  /// @notice Get duration
  function getDuration() public view returns (uint256) {
    return _duration;
  }

  /// @notice Get last deposit timestamp
  function lastDepositTime(address account) public view returns (uint256) {
    return _lastDepositTime[account];
  }

  /// @notice Get user amount of ERC20
  function balanceOf(address account) public view returns (uint256) {
    return _balances[account];
  }

  /// @notice Deposit an amount of ERC20
  /// @param amount The amount to deposit.
  function deposit(uint256 amount) public {
    // compute previous staking reward.
    uint256 _reward = computeReward(_balances[_msgSender()], _msgSender());
    // We should be able to pay 2% reward to everyone.
    require(
      rewardTotal >=
        ((totalStaked + amount + _reward) * (100 + _percentReward)) / 100,
      "Not enough token to pay 2% reward."
    );
    totalStaked += amount + _reward;

    // update user's balance
    _balances[_msgSender()] += amount + _reward;
    // update user's last deposit time
    _lastDepositTime[_msgSender()] = block.timestamp;
    // transfer ERC20 tokens to contract
    _ierc20.transferFrom(address(tx.origin), address(this), amount);

    emit Deposit(_msgSender(), amount);
  }

  /// @notice Withdraw all user's ERC20
  function withdraw() public {
    // update user's balance
    uint256 amount = _balances[_msgSender()];
    _balances[_msgSender()] = 0;
    // update user's last deposit time
    _lastDepositTime[_msgSender()] = block.timestamp;
    // compute staking reward and send it to user
    uint256 _reward = computeReward(amount, _msgSender());
    totalStaked -= amount;
    require(totalStaked >= 0, "Missing ERC20 tokens on contract");
    rewardTotal -= _reward;
    require(rewardTotal >= 0, "Missing ERC20 tokens for reward on contract");
    _ierc20.transferFrom(address(this), _msgSender(), amount + _reward);

    emit Withdraw(_msgSender(), amount + _reward);
  }

  /// @notice Compute the reward
  /// @param amount The amount staked.
  /// @param account The address of the user that stake ERC20.
  function computeReward(uint256 amount, address account)
    internal
    view
    returns (uint256)
  {
    uint256 durationDelta = _duration;
    if (block.timestamp - _lastDepositTime[account] < _duration) {
      durationDelta = block.timestamp - _lastDepositTime[account];
    }
    return (durationDelta * _percentReward * amount) / (_duration * 100);
  }
}