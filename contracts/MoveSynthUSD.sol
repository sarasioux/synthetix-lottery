// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import 'synthetix/contracts/interfaces/IAddressResolver.sol';
import 'synthetix/contracts/interfaces/IERC20.sol';

contract MoveSynthUSD is Ownable {

    IAddressResolver public synthetixResolver;
    address public synthAddress;

    event DebugEvent(bytes32 indexed debugType, uint256 indexed debugValue);

    constructor( address _resolver) payable {
        synthetixResolver = IAddressResolver(_resolver);
        synthAddress = synthetixResolver.getAddress('ProxyERC20sUSD');
        require(synthAddress != address(0), 'sUSD is missing from Synthetix resolver');
    }

    function sendSomething() external payable {
        // Call Immutable static call #1
        require(checkBalance(msg.sender) >= 1, "fromAccount does not have the required balance to spend");

        bool approvalResponse = IERC20(synthAddress).approve(address(this), 1);
        require(approvalResponse == true, "Approval was not granted");

        // Call Immutable static call #2
        require(
            checkAllowance(msg.sender, address(this)) >= 1,
            "I MoveSynthUSD, do not have approval to spend this guys tokens"
        );

        // Call Mutable call
        IERC20(synthAddress).transferFrom(msg.sender, address(this), 1);
    }

    function withdrawSomething() external onlyOwner {
        IERC20(synthAddress).transferFrom(address(this), msg.sender, 1);
    }

    function checkBalance(address account) public view returns (uint) {
        return IERC20(synthAddress).balanceOf(account);
    }

    function checkAllowance(address tokenOwner, address spender) public view returns (uint) {
        return IERC20(synthAddress).allowance(tokenOwner, spender);
    }

}
