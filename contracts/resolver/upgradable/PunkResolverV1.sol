// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../../interfaces/IBasePunkTLDFactory.sol";
import "../../interfaces/IBasePunkTLD.sol";
import "../../lib/strings.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

/// @title Punk Domains Resolver v1
/// @author Tempe Techie
/// @notice This contract resolves all punk domains and TLDs on the particular blockchain where it is deployed
contract PunkResolverV1 is Initializable, OwnableUpgradeable {
  using strings for string;

  mapping (address => bool) public isTldDeprecated; // deprecate an address, not TLD name
  address[] public factories;

  event FactoryAddressAdded(address user, address fAddr);
  event DeprecatedTldAdded(address user, address tAddr);
  event DeprecatedTldRemoved(address user, address tAddr);

  // initializer (only for V1!)
  function initialize() public initializer {
    __Context_init_unchained();
    __Ownable_init_unchained();
  }

  // READ

  // reverse resolver: get user's default name for a given TLD
  function getDefaultDomain(address _addr, string calldata _tld) public view returns(string memory) {
    uint256 fLength = factories.length;
    for (uint256 i = 0; i < fLength;) {
      address tldAddr = IBasePunkTLDFactory(factories[i]).tldNamesAddresses(_tld);

      if (tldAddr != address(0) && !isTldDeprecated[tldAddr]) {
        return string(IBasePunkTLD(tldAddr).defaultNames(_addr));
      }

      unchecked { ++i; }
    }

    return "";
  }

  // reverse resolver: get user's default names (all TLDs)
  function getDefaultDomains(address _addr) public view returns(string memory) {
    bytes memory result;

    uint256 fLength = factories.length;
    for (uint256 i = 0; i < fLength;) {
      string[] memory tldNames = IBasePunkTLDFactory(factories[i]).getTldsArray();

      for (uint256 j = 0; j < tldNames.length; ++j) {
        string memory tldName = tldNames[j];
        address tldAddr = IBasePunkTLDFactory(factories[i]).tldNamesAddresses(tldName);
        string memory defaultName = IBasePunkTLD(tldAddr).defaultNames(_addr);

        if (
          strings.len(strings.toSlice(defaultName)) > 0 && 
          !isTldDeprecated[tldAddr]
        ) {
          if (j == (tldNames.length-1)) { // last TLD (do not include space at the end)
            result = abi.encodePacked(result, defaultName, tldName);
          } else {
            result = abi.encodePacked(result, defaultName, tldName, " ");
          }
        }
      }

      unchecked { ++i; }
    }

    return string(result);
  }

  /// @notice domain resolver
  function getDomainHolder(string calldata _domainName, string calldata _tld) public view returns(address) {
    uint256 fLength = factories.length;
    for (uint256 i = 0; i < fLength;) {
      address tldAddr = IBasePunkTLDFactory(factories[i]).tldNamesAddresses(_tld);

      if (tldAddr != address(0) && !isTldDeprecated[tldAddr]) {
        return address(IBasePunkTLD(tldAddr).getDomainHolder(_domainName));
      }

      unchecked { ++i; }
    }

    return address(0);
  }
  
  /// @notice fetch domain data for a given domain
  function getDomainData(string calldata _domainName, string calldata _tld) public view returns(string memory) {
    uint256 fLength = factories.length;
    for (uint256 i = 0; i < fLength;) {
      address tldAddr = IBasePunkTLDFactory(factories[i]).tldNamesAddresses(_tld);

      if (tldAddr != address(0) && !isTldDeprecated[tldAddr]) {
        return string(IBasePunkTLD(tldAddr).getDomainData(_domainName));
      }

      unchecked { ++i; }
    }

    return "";
  }

  /// @notice fetch domain metadata for a given domain (tokenURI)
  function getDomainTokenUri(string calldata _domainName, string calldata _tld) public view returns(string memory) {
    uint256 fLength = factories.length;
    for (uint256 i = 0; i < fLength;) {
      address tldAddr = IBasePunkTLDFactory(factories[i]).tldNamesAddresses(_tld);

      if (tldAddr != address(0) && !isTldDeprecated[tldAddr]) {
        (, uint256 _tokenId, , ) = IBasePunkTLD(tldAddr).domains(_domainName);
        return IERC721Metadata(tldAddr).tokenURI(_tokenId);
      }

      unchecked { ++i; }
    }

    return "";
  }

  function getFactoriesArray() public view returns(address[] memory) {
    return factories;
  }

  /// @notice reverse resolver: get single user's default name, the first that comes (all TLDs)
  function getFirstDefaultDomain(address _addr) public view returns(string memory) {
    uint256 fLength = factories.length;
    for (uint256 i = 0; i < fLength;) {
      string[] memory tldNames = IBasePunkTLDFactory(factories[i]).getTldsArray();

      for (uint256 j = 0; j < tldNames.length; ++j) {
        string memory tldName = tldNames[j];
        address tldAddr = IBasePunkTLDFactory(factories[i]).tldNamesAddresses(tldName);
        string memory defaultName = IBasePunkTLD(tldAddr).defaultNames(_addr);

        if (
          strings.len(strings.toSlice(defaultName)) > 0 && 
          !isTldDeprecated[tldAddr]
        ) {
          return string(abi.encodePacked(defaultName, tldName));
        }
      }

      unchecked { ++i; }
    }

    return "";
  }

  /// @notice get the address of a given TLD name
  function getTldAddress(string calldata _tldName) public view returns(address) {
    uint256 fLength = factories.length;
    for (uint256 i = 0; i < fLength;) {
      address tldAddr = IBasePunkTLDFactory(factories[i]).tldNamesAddresses(_tldName);

      if (tldAddr != address(0) && !isTldDeprecated[tldAddr]) {
        return tldAddr;
      } else if (isTldDeprecated[tldAddr]) {
        return address(0);
      }

      unchecked { ++i; }
    }

    return address(0);
  }

  /// @notice get the address of the factory contract through which a given TLD was created
  function getTldFactoryAddress(string calldata _tldName) public view returns(address) {
    uint256 fLength = factories.length;
    for (uint256 i = 0; i < fLength;) {
      address tldAddr = IBasePunkTLDFactory(factories[i]).tldNamesAddresses(_tldName);

      if (tldAddr != address(0) && !isTldDeprecated[tldAddr]) {
        return factories[i];
      } else if (isTldDeprecated[tldAddr]) {
        return address(0);
      }

      unchecked { ++i; }
    }

    return address(0);
  }

  /// @notice get a stringified CSV of all active TLDs (name,address) across all factories
  function getTlds() public view returns(string memory) {
    bytes memory result;

    uint256 fLength = factories.length;
    for (uint256 i = 0; i < fLength;) {
      string[] memory tldNames = IBasePunkTLDFactory(factories[i]).getTldsArray();

      for (uint256 j = 0; j < tldNames.length; ++j) {
        string memory tldName = tldNames[j];
        address tldAddr = IBasePunkTLDFactory(factories[i]).tldNamesAddresses(tldName);
        

        if (!isTldDeprecated[tldAddr]) {
          result = abi.encodePacked(
            result, 
            abi.encodePacked(tldName, ',', Strings.toHexString(uint256(uint160(tldAddr)), 20), '\n')
          );
        }
      }

      unchecked { ++i; }
    }

    return string(result);
  }

  // OWNER
  function addFactoryAddress(address _factoryAddress) external onlyOwner {
    factories.push(_factoryAddress);
    emit FactoryAddressAdded(_msgSender(), _factoryAddress);
  }
  
  function addDeprecatedTldAddress(address _deprecatedTldAddress) external onlyOwner {
    isTldDeprecated[_deprecatedTldAddress] = true;
    emit DeprecatedTldAdded(_msgSender(), _deprecatedTldAddress);
  }

  function removeFactoryAddress(uint _addrIndex) external onlyOwner {
    factories[_addrIndex] = factories[factories.length - 1];
    factories.pop();
  }

  function removeDeprecatedTldAddress(address _deprecatedTldAddress) external onlyOwner {
    isTldDeprecated[_deprecatedTldAddress] = false;
    emit DeprecatedTldRemoved(_msgSender(), _deprecatedTldAddress);
  }
}