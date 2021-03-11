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
    
    //General
    static let authenticateUrl = "https://api.formula1.com/v2/account/subscriber/authenticate/by-password"
    static let apiKey = "fCUCjWrKPu9ylJwRAv8BpGLEgiAuThx7"
    static let identityProvider = "/api/identity-providers/iden_732298a17f9c458890a1877880d140f3/"
    static let tokenUrl = "https://f1tv-api.formula1.com/agl/1.0/unk/en/all_devices/global/authenticate"
    static let apiUrl = "https://f1tv.formula1.com"
    
    static let thumnailCardHeightMultiplier: CGFloat = 0.90
    
    //KeyValueStoreKeys
    static let jwtTokenKeyValueStorageKey = "F1ATV_JWTTokenKVSKey"
    static let userInfoKeyValueStorageKey = "F1ATV_UserInfoKVSKey"
    static let passwordKeyValueStorageKey = "F1ATV_PasswordKVSKey"

    
    //Controller
//    static let mainNavigationController = "MainNavigationController"
//    static let eventOverviewTableViewController = "EventOverviewTableViewController"
//    static let sessionOverviewTableViewController = "SessionOverviewTableViewController"
//    static let channelEpisodeTabBarController = "ChannelEpisodeTabBarController"
//    static let liveOverviewTableViewController = "LiveOverviewTableViewController"
//    static let seasonOverviewTableViewController = "SeasonOverviewTableViewController"
    static let accountOverviewViewController = "AccountOverviewViewController"
    static let loginViewController = "LoginViewController"
    static let seasonOverviewCollectionViewController = "SeasonOverviewCollectionViewController"
    static let vodOverviewCollectionViewController = "VodOverviewCollectionViewController"
    static let vodEpisodeCollectionViewController = "VodEpisodeCollectionViewController"
    static let liveOverviewCollectionViewController = "LiveOverviewCollectionViewController"
    static let eventOverviewCollectionViewController = "EventOverviewCollectionViewController"
    static let sessionOverviewCollectionViewController = "SessionOverviewCollectionViewController"
    static let channelAndEpisodeCollectionViewController = "ChannelAndEpisodeCollectionViewController"
    static let sideBarInfoViewController = "SideBarInfoViewController"
    
    //TableViewCells
    static let rightDetailTableViewCell = "RightDetailTableViewCell"
    static let thumbnailTitleTableViewCell = "ThumbnailTitleTableViewCell"
    static let thumbnailTitleSubtitleTableViewCell = "ThumbnailTitleSubtitleTableViewCell"
    static let noContentTableViewCell = "NoContentTableViewCell"
    static let thumbnailBackgroundTableViewCell = "ThumbnailBackgroundTableViewCell"
    
    //CollectionViewCells
    static let basicCollectionViewCell = "BasicCollectionViewCell"
    static let customHeaderCollectionReusableView = "CustomHeaderCollectionReusableView"
    static let thumbnailTitleCollectionViewCell = "ThumbnailTitleCollectionViewCell"
    static let thumbnailTitleSubtitleCollectionViewCell = "ThumbnailTitleSubtitleCollectionViewCell"
    static let noContentCollectionViewCell = "NoContentCollectionViewCell"
}
