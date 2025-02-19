//
//  ConstantsUtil.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import UIKit

struct ConstantsUtil {
    static var darkStyle = false
    
    //Colors
    static let brandingBackgroundColor = UIColor(rgb: 0x15151e)
    static let brandingItemColor = UIColor(rgb: 0x1f1f27)
    static let brandingRed = UIColor(rgb: 0xE10600)
    
    //General
    static let authenticateUrl = "https://api.formula1.com/v2/account/subscriber/authenticate/by-password"
    static let deviceRegistrationUrl = "https://api.formula1.com/v1/account/Subscriber/RegisterDevice"
    static let deviceUnregistrationUrl = "https://api.formula1.com/v1/account/Subscriber/UnregisterDevice"
    static let deviceAuthenticationUrl = "https://api.formula1.com/v2/account/subscriber/authenticate/by-device"
    static let challengeUrl = "https://api.formula1.com/6657193977244c13/rSa9Vzy3KajA9f9m/v1/challenge"
    static let apiKey = "fCUCjWrKPu9ylJwRAv8BpGLEgiAuThx7"
    static let deviceRegistrationApiKey = "BPhVa4xbZoebPNdxRor9rouq6gzMoPyZ"
    static let deviceRegistrationSystemId = "60a9ad84-e93d-480f-80d6-af37494f2e22"
    static let deviceRegistrationDistributionChannel = "40500b92-005d-4e10-972f-b41850d6125b"
    static let identityProvider = "/api/identity-providers/iden_732298a17f9c458890a1877880d140f3/"
    static let tokenUrl = "https://f1tv-api.formula1.com/agl/1.0/unk/en/all_devices/global/authenticate"
    static let apiUrl = "https://f1tv.formula1.com"
    static let imageResizerUrl = "https://f1tv.formula1.com/image-resizer/image"
    
    static let thumnailCardHeightMultiplier: CGFloat = 0.90
    
    //KeyValueStoreKeys
    static let userInfoKeyValueStorageKey = "F1ATV_UserInfoKVSKey"
    static let passwordKeyValueStorageKey = "F1ATV_PasswordKVSKey"
    static let playerSettingsKeyValueStorageKey = "F1ATV_PlayerSettingsKVSKey"
    static let deviceRegistrationKeyValueStorageKey = "F1ATV_DeviceRegistrationKVSKey"

    
    //Controller
    static let accountOverviewViewController = "AccountOverviewViewController"
    static let loginViewController = "LoginViewController"
    static let pageOverviewCollectionViewController = "PageOverviewCollectionViewController"
    static let sideBarInfoViewController = "SideBarInfoViewController"
    static let playerCollectionViewController = "PlayerCollectionViewController"
    static let playerInfoOverlayViewController = "PlayerInfoOverlayViewController"
    static let channelSelectorOverlayViewController = "ChannelSelectorOverlayViewController"
    static let controlStripOverlayViewController = "ControlStripOverlayViewController"
    
    //TableViewCells
    static let rightDetailTableViewCell = "RightDetailTableViewCell"
    static let noContentTableViewCell = "NoContentTableViewCell"
    static let templateTableViewCell = "TemplateTableViewCell"
    
    //CollectionViewCells
    static let basicCollectionViewCell = "BasicCollectionViewCell"
    static let customHeaderCollectionReusableView = "CustomHeaderCollectionReusableView"
    static let thumbnailTitleSubtitleCollectionViewCell = "ThumbnailTitleSubtitleCollectionViewCell"
    static let noContentCollectionViewCell = "NoContentCollectionViewCell"
    static let channelPlayerCollectionViewCell = "ChannelPlayerCollectionViewCell"
}
