// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ConfidencePool} from "src/ConfidencePool.sol";

import {ConfidencePoolFactory} from "src/ConfidencePoolFactory.sol";

import {IConfidencePool} from "src/interfaces/IConfidencePool.sol";

import {PoolStates} from "src/libraries/PoolStates.sol";

import {MockERC20} from "test/mocks/MockERC20.sol";

import {IAgreement} from "@battlechain/interface/IAgreement.sol";

import {IAgreementFactory} from "@battlechain/interface/IAgreementFactory.sol";

import {IAttackRegistry} from "@battlechain/interface/IAttackRegistry.sol";

import {IBattleChainSafeHarborRegistry} from "@battlechain/interface/IBattleChainSafeHarborRegistry.sol";

import {

    Account as BCAccount,

    AgreementDetails,

    BountyTerms,

    Chain as BCChain,

    ChildContractScope,

    Contact,

    IdentityRequirements

} from "@battlechain/types/AgreementTypes.sol";

// The upstream BattleChain contracts compile under Solidity 0.8.34 while this test and the in-scope

// ConfidencePool compile under 0.8.26. The upstream contracts are deployed from separately built

// artifacts via vm.getCode, so these minimal initializer interfaces are all that is needed here.

interface IUpstreamSafeHarborRegistry is IBattleChainSafeHarborRegistry {

function initialize(

address owner,

string[] memory initialValidChains,

address agreementFactory,

address attackRegistry

    ) external;

function setAgreementFactory(address factory) external;

function setAttackRegistry(address attackRegistryAddr) external;

}

interface IUpstreamAgreementFactory is IAgreementFactory {

function initialize(address initialOwner, address registry, string memory battleChainCaip2ChainId) external;

}

interface IUpstreamAttackRegistry is IAttackRegistry {

function initialize(

address initialOwner,

address registryModerator,

address safeHarborRegistry,

address agreementFactory,

address battleChainDeployer,

address treasury

    ) external;

}

/// @notice Shows that the expiry-based CORRUPTED grace can fully elapse while the Agreement is still

///         UNDER_ATTACK, so CORRUPTED first appears only after the grace has already expired.

///

/// @dev When CORRUPTED finally appears, a permissionless caller can immediately finalize bad-faith

///      CORRUPTED without any additional delay, before the Pool moderator receives a post-CORRUPTED

///      window to apply the protocol's scope and good-faith classification. The complete Pool

///      balance can then move through the recovery branch.

///

///      The second test reverses only markCorrupted() and claimExpired(). This changes the live

///      Agreement state observed at resolution and therefore changes the selected Pool branch and

///      the destination of the complete Pool balance.

contract LateCorruptionPreemptsModeratorTest is Test {

uint256 internal constant ONE = 1e18;

uint256 internal constant PRINCIPAL = 100e18;

uint256 internal constant BONUS = 50e18;

uint256 internal constant FULL_POOL_CORPUS = PRINCIPAL + BONUS;

uint256 internal constant BASE_TIMESTAMP = 1_750_000_000;

uint256 internal constant POOL_DURATION = 90 days;

bytes32 internal constant AGREEMENT_SALT = keccak256("late-corruption-preempts-moderator");

string internal constant BATTLECHAIN_CAIP2 = "eip155:31337";

string internal constant AGREEMENT_FACTORY_ARTIFACT =

"out/battlechain-upstream/AgreementFactory.sol/AgreementFactory.json";

string internal constant ATTACK_REGISTRY_ARTIFACT = "out/battlechain-upstream/AttackRegistry.sol/AttackRegistry.json";

string internal constant SAFE_HARBOR_REGISTRY_ARTIFACT =

"out/battlechain-upstream/BattleChainSafeHarborRegistry.sol/BattleChainSafeHarborRegistry.json";

address internal protocolOwner;

address internal registryModerator;

address internal battleChainDeployer;

address internal treasury;

// The AttackRegistry treats the Agreement owner as its attack moderator, so this is the account

// used for markCorrupted(). It also sponsors the Pool bonus.

address internal agreementOwner;

address internal poolModerator;

address internal staker;

address internal recoveryAddress;

address internal coveredAccount;

address internal permissionlessResolver;

    MockERC20 internal token;

    IUpstreamSafeHarborRegistry internal safeHarborRegistry;

    IUpstreamAgreementFactory internal agreementFactory;

    IUpstreamAttackRegistry internal attackRegistry;

    ConfidencePoolFactory internal poolFactory;

struct PoolScenario {

address agreement;

        ConfidencePool pool;

    }

function setUp() public {

        vm.warp(BASE_TIMESTAMP);

        protocolOwner = makeAddr("protocolOwner");

        registryModerator = makeAddr("registryModerator");

        battleChainDeployer = makeAddr("battleChainDeployer");

        treasury = makeAddr("treasury");

        agreementOwner = makeAddr("agreementOwner");

        poolModerator = makeAddr("poolModerator");

        staker = makeAddr("staker");

        recoveryAddress = makeAddr("recoveryAddress");

        coveredAccount = makeAddr("coveredAccount");

        permissionlessResolver = makeAddr("permissionlessResolver");

        _deployBattleChainContracts();

        _deployConfidencePoolFactory();

    }

function test_LateCorruptionCanFinalizeBeforeModeratorClassificationWindow() public {

        PoolScenario memory scenario = _createFundedPoolUnderAttack();

// 1. The expiry-based grace elapses while the Agreement is still UNDER_ATTACK, and the Pool

//    moderator cannot yet classify a CORRUPTED state that does not exist.

        _assertModeratorCannotClassifyUnderAttack(scenario.pool);

uint256 stakerBefore = token.balanceOf(staker);

uint256 recoveryBefore = token.balanceOf(recoveryAddress);

uint256 corruptionTimestamp = block.timestamp;

// 2. CORRUPTED first appears now, after the expiry-based grace has elapsed.

        vm.prank(agreementOwner);

        attackRegistry.markCorrupted(scenario.agreement);

        _assertAgreementState(scenario.agreement, IAttackRegistry.ContractState.CORRUPTED, "late markCorrupted succeeds");

// 3. A non-staker immediately finalizes bad-faith CORRUPTED, with no time advance.

        vm.prank(permissionlessResolver);

        scenario.pool.claimExpired();

        assertEq(block.timestamp, corruptionTimestamp, "no time passes between corruption and resolution");

        assertEq(uint256(scenario.pool.outcome()), uint256(PoolStates.Outcome.CORRUPTED), "pool resolved corrupted");

        assertFalse(scenario.pool.goodFaith(), "mechanical resolution is bad-faith");

        assertTrue(scenario.pool.claimsStarted(), "resolution starts claims");

        assertEq(scenario.pool.corruptedReserve(), FULL_POOL_CORPUS, "full corpus reserved for recovery");

// 4. Finality prevents the Pool moderator from applying Pool-local judgment.

        vm.prank(poolModerator);

        vm.expectRevert(IConfidencePool.OutcomeAlreadySet.selector);

        scenario.pool.flagOutcome(PoolStates.Outcome.SURVIVED, false, address(0));

// 5. The complete Pool balance moves through the recovery branch.

        vm.prank(permissionlessResolver);

        scenario.pool.claimCorrupted();

        assertEq(token.balanceOf(recoveryAddress) - recoveryBefore, FULL_POOL_CORPUS, "recovery receives full corpus");

        assertEq(token.balanceOf(staker) - stakerBefore, 0, "staker receives nothing from the bad-faith branch");

    }

function test_ResolvingBeforeLateCorruptionUsesExpiredBranch() public {

        PoolScenario memory scenario = _createFundedPoolUnderAttack();

        _assertModeratorCannotClassifyUnderAttack(scenario.pool);

uint256 stakerBefore = token.balanceOf(staker);

uint256 recoveryBefore = token.balanceOf(recoveryAddress);

// Reverse only the decisive order: resolve first, while the Agreement is still UNDER_ATTACK.

// The live-state branch is EXPIRED, so the same full corpus returns to the staker.

        vm.prank(permissionlessResolver);

        scenario.pool.claimExpired();

        assertEq(uint256(scenario.pool.outcome()), uint256(PoolStates.Outcome.EXPIRED), "pool resolved expired");

        vm.prank(staker);

        scenario.pool.claimExpired();

        assertEq(token.balanceOf(staker) - stakerBefore, FULL_POOL_CORPUS, "staker receives full corpus");

        assertEq(token.balanceOf(recoveryAddress) - recoveryBefore, 0, "recovery receives nothing");

// The same late markCorrupted() still succeeds, but the already-resolved Pool stays EXPIRED.

        vm.prank(agreementOwner);

        attackRegistry.markCorrupted(scenario.agreement);

        _assertAgreementState(scenario.agreement, IAttackRegistry.ContractState.CORRUPTED, "markCorrupted still legal");

        assertEq(uint256(scenario.pool.outcome()), uint256(PoolStates.Outcome.EXPIRED), "resolved pool stays expired");

    }

/// @dev Builds a funded Pool over a real Agreement, drives it to UNDER_ATTACK, observes the risk

///      window, and warps just past expiry + MODERATOR_CORRUPTED_GRACE while the Agreement is

///      still UNDER_ATTACK and the Pool is still UNRESOLVED.

function _createFundedPoolUnderAttack() internal returns (PoolScenario memory scenario) {

uint256 poolExpiry = block.timestamp + POOL_DURATION;

        scenario.agreement = _createCommittedAgreement(poolExpiry);

        scenario.pool = _createAndFundPool(scenario.agreement, poolExpiry);

        assertGe(IAgreement(scenario.agreement).getCantChangeUntil(), scenario.pool.expiry(), "commitment covers expiry");

        _enterUnderAttack(scenario.agreement);

// The mechanical CORRUPTED branch requires an observed risk window (riskWindowStart != 0).

        scenario.pool.pokeRiskWindow();

        assertTrue(scenario.pool.riskWindowStart() != 0, "risk window observed before expiry");

        _advancePastCorruptedGrace(scenario.pool);

        _assertAgreementState(scenario.agreement, IAttackRegistry.ContractState.UNDER_ATTACK, "under attack after grace");

        assertEq(uint256(scenario.pool.outcome()), uint256(PoolStates.Outcome.UNRESOLVED), "pool unresolved after grace");

    }

/// @dev While the Agreement is UNDER_ATTACK the moderator cannot select the CORRUPTED-only

///      classifications. Permissionless claimExpired() stays available and is not used here.

function _assertModeratorCannotClassifyUnderAttack(ConfidencePool pool) internal {

        vm.prank(poolModerator);

        vm.expectRevert(IConfidencePool.InvalidOutcome.selector);

        pool.flagOutcome(PoolStates.Outcome.SURVIVED, false, address(0));

        vm.prank(poolModerator);

        vm.expectRevert(IConfidencePool.InvalidOutcome.selector);

        pool.flagOutcome(PoolStates.Outcome.CORRUPTED, false, address(0));

    }

function _advancePastCorruptedGrace(ConfidencePool pool) internal {

        vm.warp(uint256(pool.expiry()) + pool.MODERATOR_CORRUPTED_GRACE() + 1);

    }

function _createCommittedAgreement(uint256 cantChangeUntil) internal returns (address agreement) {

        vm.prank(agreementOwner);

        agreement = agreementFactory.create(_agreementDetails(), agreementOwner, AGREEMENT_SALT);

        vm.prank(agreementOwner);

        IAgreement(agreement).extendCommitmentWindow(cantChangeUntil);

    }

function _createAndFundPool(address agreement, uint256 poolExpiry) internal returns (ConfidencePool pool) {

address[] memory scope = new address[]\(1);

        scope[0] = coveredAccount;

        vm.prank(agreementOwner);

        pool = ConfidencePool(poolFactory.createPool(agreement, address(token), poolExpiry, ONE, recoveryAddress, scope));

        token.mint(staker, PRINCIPAL);

        vm.startPrank(staker);

        token.approve(address(pool), PRINCIPAL);

        pool.stake(PRINCIPAL);

        vm.stopPrank();

        token.mint(agreementOwner, BONUS);

        vm.startPrank(agreementOwner);

        token.approve(address(pool), BONUS);

        pool.contributeBonus(BONUS);

        vm.stopPrank();

        assertEq(token.balanceOf(address(pool)), FULL_POOL_CORPUS, "pool funded with the full corpus");

    }

function _enterUnderAttack(address agreement) internal {

        vm.prank(agreementOwner);

        attackRegistry.requestUnderAttackForUnverifiedContracts(agreement);

        vm.prank(registryModerator);

        attackRegistry.approveAttack(agreement);

        _assertAgreementState(agreement, IAttackRegistry.ContractState.UNDER_ATTACK, "agreement under attack");

    }

function _assertAgreementState(address agreement, IAttackRegistry.ContractState expected, string memory label)

internal

view

    {

        assertEq(uint256(attackRegistry.getAgreementState(agreement)), uint256(expected), label);

    }

// Real upstream deployment from the separately compiled 0.8.34 artifacts. Each initializer

// argument is passed explicitly so the deployment wiring is visible at each call site.

function _deployBattleChainContracts() internal {

address registryImpl = _deployArtifact(SAFE_HARBOR_REGISTRY_ARTIFACT);

address agreementFactoryImpl = _deployArtifact(AGREEMENT_FACTORY_ARTIFACT);

address attackRegistryImpl = _deployArtifact(ATTACK_REGISTRY_ARTIFACT);

string[] memory validChains = new string[]\(1);

        validChains[0] = BATTLECHAIN_CAIP2;

address placeholderFactory = makeAddr("placeholderAgreementFactory");

address placeholderRegistry = makeAddr("placeholderAttackRegistry");

        safeHarborRegistry = IUpstreamSafeHarborRegistry(

            _deployProxy(

                registryImpl,

abi.encodeCall(

                    IUpstreamSafeHarborRegistry.initialize,

                    (protocolOwner, validChains, placeholderFactory, placeholderRegistry)

                )

            )

        );

        agreementFactory = IUpstreamAgreementFactory(

            _deployProxy(

                agreementFactoryImpl,

abi.encodeCall(

                    IUpstreamAgreementFactory.initialize, (protocolOwner, address(safeHarborRegistry), BATTLECHAIN_CAIP2)

                )

            )

        );

        attackRegistry = IUpstreamAttackRegistry(

            _deployProxy(

                attackRegistryImpl,

abi.encodeCall(

                    IUpstreamAttackRegistry.initialize,

                    (

                        protocolOwner,

                        registryModerator,

address(safeHarborRegistry),

address(agreementFactory),

                        battleChainDeployer,

                        treasury

                    )

                )

            )

        );

        vm.startPrank(protocolOwner);

        safeHarborRegistry.setAgreementFactory(address(agreementFactory));

        safeHarborRegistry.setAttackRegistry(address(attackRegistry));

        vm.stopPrank();

    }

function _deployConfidencePoolFactory() internal {

        token = new MockERC20();

        ConfidencePool poolImplementation = new ConfidencePool();

        ConfidencePoolFactory factoryImplementation = new ConfidencePoolFactory();

        poolFactory = ConfidencePoolFactory(

            _deployProxy(

address(factoryImplementation),

abi.encodeCall(

                    ConfidencePoolFactory.initialize,

                    (address(safeHarborRegistry), address(poolImplementation), poolModerator)

                )

            )

        );

        poolFactory.setStakeTokenAllowed(address(token), true);

    }

function _deployProxy(address implementation, bytes memory initData) internal returns (address) {

return address(new ERC1967Proxy(implementation, initData));

    }

function _deployArtifact(string memory artifact) internal returns (address deployed) {

bytes memory creationCode = vm.getCode(artifact);

require(creationCode.length != 0, "missing artifact");

assembly {

            deployed := create(0, add(creationCode, 0x20), mload(creationCode))

        }

require(deployed != address(0), "artifact deploy failed");

    }

function _agreementDetails() internal view returns (AgreementDetails memory details) {

        BCAccount[] memory accounts = new BCAccount[]\(1);

        accounts[0] =

            BCAccount({accountAddress: _addressToString(coveredAccount), childContractScope: ChildContractScope.None});

        BCChain[] memory chains = new BCChain[]\(1);

        chains[0] = BCChain({

            assetRecoveryAddress: _addressToString(recoveryAddress), accounts: accounts, caip2ChainId: BATTLECHAIN_CAIP2

        });

        Contact[] memory contacts = new Contact[]\(1);

        contacts[0] = Contact({name: "Security", contact: "security@example.com"});

        BountyTerms memory bountyTerms = BountyTerms({

            bountyPercentage: 10,

            bountyCapUsd: 5_000_000,

            retainable: false,

            identity: IdentityRequirements.Anonymous,

            diligenceRequirements: "none",

            aggregateBountyCapUsd: 10_000_000

        });

        details = AgreementDetails({

            protocolName: "Late Corruption Grace Regression",

            contactDetails: contacts,

            chains: chains,

            bountyTerms: bountyTerms,

            agreementURI: "ipfs://late-corruption-grace-regression"

        });

    }

function _addressToString(address addr) internal pure returns (string memory) {

bytes memory alphabet = "0123456789abcdef";

bytes memory str = new bytes(42);

        str[0] = "0";

        str[1] = "x";

for (uint256 i; i < 20; ++i) {

            str[2 + i * 2] = alphabet[uint8(uint160(addr) >> (8 * (19 - i)) >> 4) & 0xf];

            str[3 + i * 2] = alphabet[uint8(uint160(addr) >> (8 * (19 - i))) & 0xf];

        }

return string(str);

    }

}