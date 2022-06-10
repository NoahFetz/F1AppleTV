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
    
    static let challengeQuestion: String = "2.xYVJiYT8exKZEqLS3DLz0c3jFR107DPZSwuUiDbjtZ_-LcUHNhFC_jsIwKxXjuxPrgStluFmnHdAzlN4cXrrZGxypANVM9B5APjAswUgQPYuBM9GbpGreIBcvLkCVS_pLXWB3j_lYyAucr5HNOTljifFQt7uQq1SU_ggMaG4s2vs59HEDwZ1E6EtTzNSVI1wwPC5h48X4UNMc8J6QMB2hcb0zgtqkyfchkm_rLNx78s-cU6awjiMW4ex1FvADftUabZLbJf9tQd6CgH1_yQ-SkkGHtYeHNKVhta7F18wDCBbuRRmNYqENHYgL8RgHnRmvLhZhRGXSETkiSQDucKDUdZOX92PJfN9pZtN9huFthyOT-57XuCpbQdqezcqvZ3O5QJR3mJtxvLZaBCsRHbpUnLhAPphTgGzIBKJ2m7_wgtFY8k-hV8t9K48rgdh5CsbGqbE637HFgu0IlUg1l8pD8AoRag0aMUAVFyYZ51-xXZ9C18aUtEc30BVgUrJBIcIaKefQBzAc4Ukbg1TRw9kQBIkh9sQ-9sGzrPFFb21vtP5HNFzIgFiY6GvNbJZY3lWH3_qfzU3emTH1ewkL9Mvnol1lYYvkedxb_an11vTxdlMiFiPWwAloIJ0ydEyd6Wq7vUW51VV99G9GW73e0I_-pymYdBReofgedR8uT6ng_wHfq_S_UpRuWNDFNkjWXDk5G2Rs6ONmd-OQIXwJEkfKVl4YqlVZhyj5XjxtWOkCZdQurydTzGxkT96HwmTHGTIGCzPy3cXK9Qdy6PU453jxYYb2MnMrNIy3wIeymEDHcgCc8rbgtPK172ZW8gS9ygjEVtfvXL2m6YzLSzFfWnG2AbJqs6BWeXL8DVo2zEwXdCfydUxyIgW1og1s9lMizPO35Fp2F0mtct7K2nIjkuy2TVNaDMzIaKj4MS-oQTjz7WGUdaMl7qGmpdwiYpDrCDeOjKtJTMAFbgKafvvre5BxBBY7c416qwxNUFGMJdws6OXgCDeOjatJdv4FbjQZPvv64GOjQh20tHEdzPJMWRiyJiJWowPrs_ckePxxTKNcM4bwFnMRHTgj9b4yNHeESbJFlloMnIQuI4CuW6_RNyQ2bpIs7dkTwAODd9kyHWtWsxbF1rM6xm7MZEMucd8hB8iwDWmvUmpn9ykSLO3Zk8ADhN03oszkNPbtgRZzEwd8sZgr7XEqYVj8kuoNN_g7cTPZtYHIBjxpL1zKFWOOi69Htv4FbjQZPvv-_pejYHvwtEQUwLy0DEg35QxL_O_w7fYZIDRxusfcslIQUEysYA-uIKOUOXvd3CoJpNc5z4dPiPV9LXCsMThxIGMtcQ_h1zyJzfP0on75s7kQGTLON0pIxjxpL3rAFWOOia9Htv4FbjQZPvv-_pejR3kwtHNaiHJ3P7hxeuQoM4B7WDwkolamw0n6ts85wcgVILQ9Jj5Rbw6JoMd2_gVuNBk--_7-l6NHeTC0XXiAvJp0d_Si37ZjUZC2ZgXV_bcFLKZz2D8BCAkGtf0EAcXszomkx7b-BW40GT77_v6Xo1978LR6icwyTwn4sXVZdmNRkLZmBXBdecJh0LSYOgXIhjxpL2b8FWOOja9Htv4FbjQZPvv-_pejSHkwtGMGyHJExLhxVDE1PKZ-O7kFDN_0t8JPPJg8Dk03C8vi0Spn-KkSLO3Zk8ADhN03oszkNPbZk9E8OslpNJoDl3Ejj_u8v248pvjY96YPOMuNxjxpL3v5FWOOjK9Htv4FbjQZPvv-_pejc7kwtGjcRbOJlD8xiPZTfKYNAXksc5i5FwzwORm2hc0GPGkvSOYVY46Pr0eMwAVuApp---t7kHEKGFazsB9uzELHYUwNV1GMJdws6NHMCDeOiatJdv4FbgBYfvv1MPD8uLwwtIbbWTOkXLPy9B3H8iMGnOMjwLC0T1m_MRmBELE4YXPybpgs4y5xR3cPdU5I_qvN6NEpY_apEizt2ZPAA4TdN6LM5DT220kTcxBIA8g8fWIpsPnmow6IpMf2_gVuAFh--_Uw8Py4vDC0httZM6Rcs_L0HcfyIwac4z0q8LRnnNjydkIFs9xvfzGIjvA8h_RPOQt-Dk03C8vi0Spn-K6SLO3ZE8ADvLtZMhSEbsxQKW5x58-P86lF2TMZtIXIGh3T6xclx6jANCf4qRIs7dmTwAO1ubhyMfxEcxXjRbMVUT8xvl61M6_rAKPz5Dp2_6DHcubtyPILWrsxVDU0_Jfcj_kRSdp5FrnPjQoKO-miAgh5e93Sqsmk1zn2xQhI3FN1MjtkUrMKlVdyzrfZM_e7PHGeGBkyUIZssXVot_JRQZ8xQJQY8S3xvLE58mcyQJRHjLYdiCmRP6A2qRIs7dmTwAOE3TeizOQ09v4KHOPoV6zmDFE8JhPm8jR3191yWUydfPZIrnSs6MUIgl_pcjvd2Coh6Ae57cNCyM4fT7PMVKWMi4KY81a5wQgKCjvppZpl-Xvd3CrJpNc5zUdPiM2DDTPP8tzyGHhFs-P8Y2P1h3S0RghM8m9Sp2MZH4CmN85wdH2Al2NIYwSmH0y7tsfUm8xeBkIjvEMeb8hLx8MAHtkyDCEUMtiTT4jAANxo_AEUaC0MROYr952vxgUHKPDdMnRyVScpRO_hqCf8t6wvsjy3xkQrrNk43APKWk3o-Br1aAR9r6YdJ7HsDhEeg8GNyyLVyx7JpMjuabR2E6WLiHQ8Qi0AJPbtx43Hf8oJMYxRfQPjZibIvrH9MDk77kahDqJlxEhDzOZrcgthTogtktPrJtQeYTWLwmLpG69iGeIlumKiQ6lMFZkHqjmO6Mt8RGGKEv-jh1hK6Fn9fLRiokOpS9WZB4ejAWOxqzamB0rp7VHmd2hjHnvtdN5ZQ4zyFu9CeFfpka6rKPEiViAOcPqhMY5j-Agc1YxDjoFjhgWgb-ACt7qF0E1yde3HyOVAJuLJ0APN5OJdqxYdaOLOIRxD_N6daMXy1-grJkQN2lbrbeQjr3M"
    
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
