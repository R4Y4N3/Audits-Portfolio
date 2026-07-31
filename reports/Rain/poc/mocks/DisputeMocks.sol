// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {
    ERC20
} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {
    IOracle
} from "../../src/interfaces/IOracle.sol";

contract MockERC20 is ERC20 {
    uint8 private immutable tokenDecimals;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_
    ) ERC20(name, symbol) {
        tokenDecimals = decimals_;
    }

    function decimals()
        public
        view
        override
        returns (uint8)
    {
        return tokenDecimals;
    }

    function mint(
        address to,
        uint256 amount
    ) external {
        _mint(to, amount);
    }
}

contract MockRainToken {
    function enter(uint256)
        external
        pure
        returns (uint256)
    {
        return 0;
    }
}

contract MockFactory {
    address public mockOracle;

    function setMockOracle(
        address oracle
    ) external {
        mockOracle = oracle;
    }

    function createOracle(
        uint256,
        uint256,
        uint256,
        address,
        uint256,
        uint256,
        string memory
    ) external view returns (address) {
        return mockOracle;
    }
}

contract MockOracle is IOracle {
    uint256 private selectedWinner;
    bool private extended;

    function winnerOption()
        external
        view
        returns (uint256)
    {
        return selectedWinner;
    }

    function winnerFinalized()
        external
        pure
        returns (bool)
    {
        return false;
    }

    function timeExtended()
        external
        view
        returns (uint256)
    {
        return extended ? 7 : 0;
    }

    function setWinner(
        uint256 winner
    ) external {
        selectedWinner = winner;
    }

    function setTimeExtended(
        bool value
    ) external {
        extended = value;
    }
}
