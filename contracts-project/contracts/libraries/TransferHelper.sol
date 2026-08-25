// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @notice Safe wrappers for ERC20 calls, since some tokens (like USDT on some
/// chains) don't strictly follow the standard return-bool convention.
library TransferHelper {
    function safeTransfer(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(bytes4(keccak256(bytes("transfer(address,uint256)"))), to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "ZirakSwap: TRANSFER_FAILED");
    }

    function safeTransferFrom(address token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(bytes4(keccak256(bytes("transferFrom(address,address,uint256)"))), from, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "ZirakSwap: TRANSFER_FROM_FAILED");
    }

    function safeTransferBNB(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, "ZirakSwap: BNB_TRANSFER_FAILED");
    }
}
