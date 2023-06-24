import { BigNumber, Contract, providers, ethers, utils } from "ethers";


var usdcTknAbi = require("../artifacts/contracts/USDCoin.sol/USDCoin.json").abi;
var miPrimerTknAbi = require("../artifacts/contracts/MiPrimerToken.sol/PC3TokenUpgradeable.json").abi;
var publicSaleAbi = require("../artifacts/contracts/PublicSale.sol/PublicSale.json").abi;
var nftTknAbi = require("../artifacts/contracts/NFT.sol/PC3NFTUpgradeable.json").abi;


window.ethers = ethers;

var provider, signer, account;
var usdcTkContract, miPrTokenContract, nftTknContract, pubSContract;

// REQUIRED
// Conectar con metamask
function initSCsGoerli() {
  provider = new providers.Web3Provider(window.ethereum);

  var usdcAddress = "0x818819B0802aB053f48169ca80Eb338C73Ba2a83";
  var miPrimerTknAddress = "0x4a700D40EbeBA29F8C1DFdbB1F0BB9926ae8A360";
  var publicSaleAddress = "0x70faFCFff21ed69b89Cc88a554307c193E1e7810";

  usdcTkContract = new Contract(usdcAddress, usdcTknAbi, signer); // = Contract...
  miPrTokenContract = new Contract(miPrimerTknAddress, miPrimerTknAbi, signer); // = Contract...
  pubSContract = new Contract(publicSaleAddress, publicSaleAbi, signer); // = Contract...
}

// OPTIONAL
// No require conexion con Metamask
// Usar JSON-RPC
// Se pueden escuchar eventos de los contratos usando el provider con RPC
function initSCsMumbai() {
  var providerMumbai = new ethers.providers.JsonRpcProvider("https://rpc-mumbai.maticvigil.com");
  var nftTknAddress = "0xeb85979E9eD109Da1b95A9C00622F7A086c6ff91";

  nftTknContract = new Contract(nftTknAddress, nftTknAbi, providerMumbai); // = new Contract...
}

async function chargeLastNFTsMinted() {
  // await nftTknContract.connect(account).safeMint(account,1);
  var nftTransferList = document.getElementById("nftList");
  nftTransferList.innerHTML = '';

  var filterFrom = nftTknContract.filters.Transfer(ethers.constants.AddressZero, null);

  var pastEvents = await nftTknContract.queryFilter(filterFrom, -500);

  pastEvents.forEach((event) => {
    var child = document.createElement("li");
    child.innerText = `Transfer from ${event.args[0]} to ${event.args[1]} tokenId ${event.args[2]}`;
    nftTransferList.appendChild(child);
  });
  console.log("Eventos cargados")
}

function setUpListeners() {
  // Connect to Metamask
  var bttn = document.getElementById("connect");
  bttn.addEventListener("click", async function () {
    if (window.ethereum) {
      [account] = await ethereum.request({
        method: "eth_requestAccounts",
      });
      console.log("Billetera metamask", account);

      provider = new providers.Web3Provider(window.ethereum);
      signer = provider.getSigner(account);
      window.signer = signer;
      initSCsGoerli();
      initSCsMumbai();
      setUpEventsContracts();
      await chargeLastNFTsMinted();
    }
  });

  var bttn = document.getElementById("usdcUpdate");
  bttn.addEventListener("click", async function () {
    var usdcBalance = document.getElementById("usdcBalance");
    try {
      var tx = await usdcTkContract
        .connect(signer)
        .balanceOf(account);
      usdcBalance.innerHTML = tx.toString();

    } catch (error) {
      console.log(error);
    }
  });

  var bttn = document.getElementById("miPrimerTknUpdate");
  bttn.addEventListener("click", async function () {
    var miPrimerTknBalance = document.getElementById("miPrimerTknBalance");
    try {
      var tx = await miPrTokenContract
        .connect(signer)
        .balanceOf(account);
        miPrimerTknBalance.innerHTML = tx.toString();

    } catch (error) {
      console.log(error);
    }
  });

  var bttn = document.getElementById("approveButton");
  bttn.addEventListener("click", async function () {
    var approveAmount = document.getElementById("approveInput");
    var approveError = document.getElementById("approveError");
    approveError.innerHTML = "";
    try {
      var tx = await miPrTokenContract
        .connect(signer)
        .approve(pubSContract.address, approveAmount.value);

    } catch (error) {
      console.log(error.reason);
      approveError.innerHTML = error.reason;
    }
  });

  var bttn = document.getElementById("purchaseButton");
  bttn.addEventListener("click", async function () {
    var purchaseId = document.getElementById("purchaseInput");
    var purchaseError = document.getElementById("purchaseError");
    purchaseError.innerHTML = "";
    try {
      var tx = await pubSContract
        .connect(signer)
        .purchaseNftById(purchaseId.value);

    } catch (error) {
      console.log(error.reason);
      purchaseError.innerHTML = error.reason;
    }
  });

  var bttn = document.getElementById("purchaseEthButton");
  bttn.addEventListener("click", async function () {
    var purchaseEthError = document.getElementById("purchaseEthError");
    purchaseEthError.innerHTML = "";
    try {

      var tx = await pubSContract
        .connect(signer)
        .depositEthForARandomNft({
          value: utils.parseEther("0.01")
        });

    } catch (error) {
      console.log(error);
      purchaseEthError.innerHTML = error.reason;
    }
  });

  var bttn = document.getElementById("sendEtherButton");
  bttn.addEventListener("click", async function () {
    
    var sendEtherError = document.getElementById("sendEtherError");
    sendEtherError.innerHTML = "";
    try {

      var tx = await signer.sendTransaction({
        to: pubSContract.address,
        value: utils.parseEther("0.01"),
      });

    } catch (error) {
      console.log(error);
      sendEtherError.innerHTML = error.reason;
    }
  });

  var bttn = document.getElementById("seeAvailableNFTsButton");
  bttn.addEventListener("click", async function () {
    
    var list = document.getElementById("availableNFTsList");
    list.innerHTML = "";
    try {

      var res = await pubSContract
        .connect(account)
        .getAvailableNFTs();

      var idsList = "";
      res.forEach((idNFT, ix) => {
        idsList+=idNFT.toString() + ", ";
      });
      list.innerHTML = idsList.slice(0, -2);

    } catch (error) {
      console.log(error);
    }
  });

}

function setUpEventsContracts() {
  //Se escucha el evento transfer del ERC721 en el contrato de NFT
  nftTknContract.on("Transfer", (adrressZer0,ownerNFT, idNFT) => {
    var nftTransferList = document.getElementById("nftList");
    var child = document.createElement("li");
    child.innerText = `Transfer from ${adrressZer0} to ${ownerNFT} tokenId ${idNFT}`;
    nftTransferList.appendChild(child);
  });

}

async function setUp() {
  
  await setUpListeners();
}

setUp()
  .then()
  .catch((e) => console.log(e));
