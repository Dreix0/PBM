// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PBM is ERC1155, Ownable, ERC1155Burnable {
    // A struct to represent a "WrappedCoin" with blacklisting or whitelisting functionality
    struct WrappedCoin {
        bool itsABlacklist; // Determines if it's a blacklist (true) or whitelist (false) 
        mapping(address => bool) isListed; // Maps addresses to whether they are blacklist or whitelist
        mapping(address => bool) isIssuer; // Maps addresses to whether they are authorized issuers
    }

    WrappedCoin[] private coinsList; // An array to store all WrappedCoins created
    IERC20 public originalStablecoin; // The original stablecoin (ERC20 token) to be wrapped

    constructor(
        address _erc20Address,
        string memory _uri
    ) ERC1155(_uri) Ownable(msg.sender) {
        originalStablecoin = IERC20(_erc20Address);
    }

    // Fonctions ERC 1155
    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    // Fonctions getters

    // Returns whether the WrappedCoin at a specific ID is a blacklist or a whitelist
    function itsABlacklist(uint256 id) public view returns(bool) {
        return coinsList[id].itsABlacklist;
    }

    // Checks if a given address is listed in the blacklist/whitelist for a specific WrappedCoin ID
    function isListed(uint256 id, address _address) public view returns(bool) {
        return coinsList[id].isListed[_address];
    }

    // Checks if a given address is an authorized issuer for a specific WrappedCoin ID
    function isIssuer(uint256 id, address _issuer) public view returns(bool) {
        return coinsList[id].isIssuer[_issuer];
    }

    // Fonctions PBM

    // Function to create a new WrappedCoin
    function createWrappedCoin(bool _itsABlacklist, address[] memory _list, address[] memory _allowedIssuer) public onlyOwner {  
        coinsList.push();
        WrappedCoin storage newWrappedCoin = coinsList[coinsList.length - 1];

        // Set whether this coin uses a blacklist or whitelist
        newWrappedCoin.itsABlacklist = _itsABlacklist;

        // Loop through the list of addresses to update the `isListed` mapping
        for (uint i = 0; i < _list.length; i++) {
            newWrappedCoin.isListed[_list[i]] = true;
        }

        // Loop through the allowed issuers to update the `isIssuer` mapping
        for (uint i = 0; i < _allowedIssuer.length; i++) {
            newWrappedCoin.isIssuer[_allowedIssuer[i]] = true;
        }
    }

    // Function to change the status (add/remove) of an address in the blacklist/whitelist for a specific WrappedCoin ID
    function changeList(address addressToChange, uint256 id) public onlyOwner {
        if(coinsList[id].isListed[addressToChange] == true) {
            coinsList[id].isListed[addressToChange] = false;
        } 
        else {
            coinsList[id].isListed[addressToChange] = true;
        }
    }

    // Function to "wrap" coins: authorized users (issuers) send stablecoins to receive an equivalent amount of wrapped tokens
    function wrapCoin(uint256 id, uint256 amount) public{
        require(coinsList[id].isIssuer[msg.sender] == true, "You must be an authorized issuer to wrap a coin");
        require(originalStablecoin.transferFrom(msg.sender, address(this), amount), "Payment failed");
        _mint(msg.sender, id, amount, "");
    }

    // Function to "unwrap" coins: users (in the whitelist or not in the blacklist) burn their wrapped tokens to receive an equivalent amount of stablecoins
    function unwrapCoin(uint256 id, uint256 amount) public {
        require(balanceOf(msg.sender, id) >= amount, "Insufficient balance");
        if(coinsList[id].itsABlacklist == true) {
            require(coinsList[id].isListed[msg.sender] == false, "Is blacklist");
        } 
        else {
            require(coinsList[id].isListed[msg.sender] == true, "Is not whitelist");
        }
        require(originalStablecoin.transfer(msg.sender, amount), "Payment failed");
        _burn(msg.sender, id, amount);
    }
}