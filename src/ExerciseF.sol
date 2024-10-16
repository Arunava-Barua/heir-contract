// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ExerciseF is Ownable {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint32 public constant GAP = 30 days; // withdraw window i.e. owner can withdraw within 1 month from last withdraw
    uint32 public s_lastWithdraw; // last time owner did withdraw from this contract
    address public s_heir; // authority address after owner if owner failed to withdraw within 1 month window

    /*//////////////////////////////////////////////////////////////
                            EVENTS & ERRORS
    //////////////////////////////////////////////////////////////*/
    event ETH_Withdraw(
        uint256 /* withdraw amount */
    );
    event Withdraw_Counter_Update(
        uint32 /* current timestamp */
    );
    event Heir_Update(
        address /* new heir address */
    );
    error NOT_Heir();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyHeir() {
        if (msg.sender != s_heir) {
            revert NOT_Heir();
        }
        _;
    }

    /*
     * @dev set the owner as msg.sender, s_heir as _heir address and s_lastWithdraw as current timestamp.
     * @param _heir Heir address
     */
    constructor(address _heir) Ownable(msg.sender) {
        s_heir = _heir;
        s_lastWithdraw = uint32(block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /*
     * @dev owner can withdraw eth from this contract or reset the withdraw counter.
     * @param _amount amount of eth to withdraw, if _amount == 0 reset the counter.
     * @notice can only be called by owner
     */
    function withdraw(uint256 _amount) external onlyOwner {
        require(_amount <= address(this).balance, "Invalid withdraw amount");
        require(block.timestamp <= s_lastWithdraw + GAP, "Withdraw Timeout");

        if (_amount != 0) {
            (bool success, ) = payable(owner()).call{value: _amount}("");
            require(success, "Falied to send ETH");
            emit ETH_Withdraw(_amount);
        }
        s_lastWithdraw = uint32(block.timestamp);
        emit Withdraw_Counter_Update(uint32(block.timestamp));
    }

    /*
     * @dev transfer ownership to current s_heir and update s_heir with new heir address
     * @param _newHeir new heir address.
     * @notice can only be called by s_heir
     */
    function updateHeir(address _newHeir) external onlyHeir {
        require(
            block.timestamp > s_lastWithdraw + GAP,
            "Withdraw is open for owner"
        );
        require(_newHeir != address(0), "Invalid new heir address");
        _transferOwnership(s_heir);

        s_heir = _newHeir;
        emit Heir_Update(_newHeir);

        s_lastWithdraw = uint32(block.timestamp);
        emit Withdraw_Counter_Update(uint32(block.timestamp));
    }

    receive() external payable {}
}