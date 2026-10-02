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
    static let imageResizerUrl = "https://f1tv.formula1.com/image-resizer/image"
    
    static let thumnailCardHeightMultiplier: CGFloat = 0.90
    
    //KeyValueStoreKeys
    static let userInfoKeyValueStorageKey = "F1ATV_UserInfoKVSKey"
    static let passwordKeyValueStorageKey = "F1ATV_PasswordKVSKey"
    static let playerSettingsKeyValueStorageKey = "F1ATV_PlayerSettingsKVSKey"
    static let deviceRegistrationKeyValueStorageKey = "F1ATV_DeviceRegistrationKVSKey"

    //KeychainKeys
    static let keychainPasswordKey = "F1ATV_Password"
    static let keychainDeviceRegistrationKey = "F1ATV_DeviceRegistration"


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
