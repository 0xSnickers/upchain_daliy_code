// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin-upgradeable/contracts/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title 使用签名进行白名单铸造的可升级合约（UUPS）
 * @notice 通过 ReentrancyGuard nonReentrant 防止重入攻击（一个NFT被mint多次）
 */
contract ERC721WithSignatureV1 is 
    Initializable,
    UUPSUpgradeable,
    ERC721EnumerableUpgradeable, 
    OwnableUpgradeable, 
    EIP712Upgradeable, 
    ReentrancyGuardUpgradeable
{
    using ECDSA for bytes32;
    using Strings for uint256;

    uint256 public nextTokenId; // 下一个tokenId
    string private baseTokenURI; // 基础URI
    uint256 public constant MAX_SUPPLY = 10; // 最大供应量

    // 用于防止重放攻击的 nonce
    mapping(address => uint256) public nonces;

    // 签名类型哈希
    bytes32 public constant MINT_TYPEHASH =
        keccak256("Mint(address to,uint256 tokenId,uint256 nonce,uint256 deadline)");

    // 事件定义
    event MintWithSignature(address indexed to, uint256 indexed tokenId, address indexed signer);
    event MintWithSignatureError(address indexed to, uint256 indexed tokenId, string reason);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory _name,
        string memory _symbol,
        string memory _initBaseURI
    ) public initializer {
        __ERC721_init(_name, _symbol);
        __ERC721Enumerable_init();
        __Ownable_init(msg.sender);
        __EIP712_init(_name, "1");
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        
        baseTokenURI = _initBaseURI;
    }

    /// @notice 使用签名进行白名单铸造 （nonReentrant 确保在一个函数调用完成之前，不能再次进入该函数）
    /// @param to 接收NFT的地址
    /// @param tokenId NFT的ID
    /// @param deadline 签名过期时间
    /// @param signature 签名数据
    function mintWithSignature(
        address to,
        uint256 tokenId,
        uint256 deadline,
        bytes memory signature
    ) external nonReentrant {
        // 检查签名是否过期
        require(deadline >= block.timestamp, "PermitERC721: permit expired");
        require(to == msg.sender, "PermitERC721: invalid caller");
        require(tokenId < MAX_SUPPLY, "max supply reached");
      
        // 验证签名
        bytes32 structHash = keccak256(
            abi.encode(MINT_TYPEHASH, to, tokenId, nonces[to]++, deadline)
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = hash.recover(signature);

        // 检查签名者是否为合约拥有者
        require(signer == owner(), "invalid signature");

        // 铸造NFT
        _safeMint(to, tokenId);
        nextTokenId = tokenId + 1;

        emit MintWithSignature(to, tokenId, signer);
    }


    /// @notice 铸造一个 NFT 给指定地址
    function mint(address to) external onlyOwner {
        require(nextTokenId < MAX_SUPPLY, "PermitERC721: max supply reached");
        _safeMint(to, nextTokenId);
        nextTokenId++;
    }

    /// @notice 设置 baseURI（只有合约拥有者可以）
    function setBaseURI(string memory _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    /// @notice 返回 token 的元数据 URL(重写_baseURI)
    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }

    /// @notice 返回 EIP-712 域分隔符
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /// @notice 公共包装函数，便于测试 EIP-712 digest
    function hashTypedDataV4Public(bytes32 structHash) public view returns (bytes32) {
        return _hashTypedDataV4(structHash);
    }

    /// @notice 实现 UUPS 所需的升级授权函数
    // UUPS 的关键点：你必须定义 _authorizeUpgrade()，否则 upgradeTo() 方法将不可用
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
