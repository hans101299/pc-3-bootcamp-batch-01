// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract PublicSale is
    Initializable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Mi Primer Token
    // Crear su setter
    IERC20Upgradeable pc3Token;

    // 17 de Junio del 2023 GMT
    uint256 constant startDate = 1686960000;

    // Maximo price NFT
    uint256 constant MAX_PRICE_NFT = 50000 * 10 ** 18;

    // Gnosis Safe
    // Crear su setter
    address gnosisSafeWallet;

    //Cuenta de tokens vendidos
    uint256 public numberNFTs;
    mapping(uint256 => bool) public soldNFTs;
    mapping(uint256 => uint256) positionAvailableArrayNFT;
    uint256[] availableNFTs;
    uint256 public numberAvailableNFTs;

    event DeliverNft(address winnerAccount, uint256 nftId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
    }

    function setNumberNFTs(uint256 _numNFTs) public onlyRole(DEFAULT_ADMIN_ROLE){
        //Se considera que la cantidad es el limite superior y que los ids de los NFTs son consecutivos
        numberAvailableNFTs = _numNFTs;
        for(uint i=0; i<_numNFTs; i++){
            availableNFTs.push(i);
            positionAvailableArrayNFT[i] = i;
        }
    }

    function purchaseNftById(uint256 _id) external {
        // 4 - el _id se encuentre entre 1 y 30
        require(_id<30, "NFT: Token id out of range");
        // Obtener el precio segun el id
        uint256 priceNft = _getPriceById(_id);
        // 1 - el id no se haya vendido. Sugerencia: llevar la cuenta de ids vendidos
        require(!soldNFTs[_id], "Public Sale: id not available");
        // 2 - el msg.sender haya dado allowance a este contrato en suficiente de MPRTKN
        require(pc3Token.allowance(msg.sender, address(this)) >=priceNft, "Public Sale: Not enough allowance");
        // 3 - el msg.sender tenga el balance suficiente de MPRTKN
        require(pc3Token.balanceOf(msg.sender) >=priceNft, "Public Sale: Not enough token balance");
        
        soldNFTs[_id] = true;
        numberAvailableNFTs--;
        _deleteAvailableId(_id);

        // Purchase fees
        // 10% para Gnosis Safe (fee)
        uint256 feeGnosis = priceNft * 10 / 100;
        
        // 90% se quedan en este contrato (net)

        // from: msg.sender - to: gnosisSafeWallet - amount: fee
        pc3Token.transferFrom(msg.sender, gnosisSafeWallet, feeGnosis);
        // from: msg.sender - to: address(this) - amount: net
        pc3Token.transferFrom(msg.sender, address(this), priceNft - feeGnosis);

        // EMITIR EVENTO para que lo escuche OPEN ZEPPELIN DEFENDER
        emit DeliverNft(msg.sender, _id);
    }

    function depositEthForARandomNft() public payable {
        // 1 - que el msg.value sea mayor o igual a 0.01 ether
        require(msg.value >= 0.01 ether, "Public Sale: Not enough ether");
        // 2 - que haya NFTs disponibles para hacer el random
        require(numberAvailableNFTs>0, "Public Sale: Not available NFTs");
        // Escgoer una id random de la lista de ids disponibles
        uint256 nftId = _getRandomNftId();

        soldNFTs[nftId] = true;
        numberAvailableNFTs--;
        _deleteAvailableId(nftId);

        // Enviar ether a Gnosis Safe
        // SUGERENCIA: Usar gnosisSafeWallet.call para enviar el ether
        // Validar los valores de retorno de 'call' para saber si se envio el ether correctamente
        (bool success, bytes memory error) = payable(gnosisSafeWallet).call{
            value: 0.01 ether
        }("");

        require(success);

        if (msg.value > 0.01 ether) {
            payable(msg.sender).transfer(msg.value - 0.01 ether);
        }

        // EMITIR EVENTO para que lo escuche OPEN ZEPPELIN DEFENDER
        emit DeliverNft(msg.sender, nftId);
    }

    function getAvailableNFTs() public view returns(uint256[] memory) {
        return availableNFTs;
    }

    function setPC3Token(address pc3TokenAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        pc3Token = IERC20Upgradeable(pc3TokenAddress);
    }

    function setGnosisWallet(address gnosisAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        gnosisSafeWallet = gnosisAddress;
    }

    // PENDING
    // Crear el metodo receive
    receive() external payable {
        depositEthForARandomNft();
    }

    ////////////////////////////////////////////////////////////////////////
    /////////                    Helper Methods                    /////////
    ////////////////////////////////////////////////////////////////////////

    //Elimina un id de los NFTs disponibles
    function _deleteAvailableId(uint256 _id) internal {
        uint256 indexToDelete = positionAvailableArrayNFT[_id];
        uint256 indexLastElement = availableNFTs.length-1;
        positionAvailableArrayNFT[availableNFTs[indexLastElement]] = indexToDelete;
        availableNFTs[indexToDelete] = availableNFTs[indexLastElement];
        availableNFTs.pop();
    }

    // Devuelve un id random de NFT de una lista de ids disponibles
    function _getRandomNftId() internal view returns (uint256) {
        uint256 indexRandomAvailable = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % numberAvailableNFTs;
        return availableNFTs[indexRandomAvailable];
    }

    // Según el id del NFT, devuelve el precio. Existen 3 grupos de precios
    function _getPriceById(uint256 _id) internal view returns (uint256) {
        uint256 priceGroupOne = 500 * 10 ** 18;
        uint256 priceGroupTwo = _id * 1000 * 10 ** 18;
        uint256 priceGroupThree = 10000 * 10 ** 18 + (((block.timestamp - startDate) / 1 hours) * 1000 * 10 ** 18);
        if (_id < 11) {
            return priceGroupOne;
        } else if (_id > 10 && _id < 21) {
            return priceGroupTwo;
        } else {
            return priceGroupThree<MAX_PRICE_NFT?priceGroupThree:MAX_PRICE_NFT;
        }
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}
}
