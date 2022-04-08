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
    static let challengeUrl = "https://api.formula1.com/6657193977244c13/rSa9Vzy3KajA9f9m/v1/challenge"
    static let apiKey = "fCUCjWrKPu9ylJwRAv8BpGLEgiAuThx7"
    static let identityProvider = "/api/identity-providers/iden_732298a17f9c458890a1877880d140f3/"
    static let tokenUrl = "https://f1tv-api.formula1.com/agl/1.0/unk/en/all_devices/global/authenticate"
    static let apiUrl = "https://f1tv.formula1.com"
    static let imageResizerUrl = "https://f1tv.formula1.com/image-resizer/image"
    
    static let thumnailCardHeightMultiplier: CGFloat = 0.90
    
    static let challengeQuestion: String = "2.YxZaSJgMCQMAaTDP3DLz0c3jFR107DPZSwuUiERBzreJwLNGleOI9Lrmp6nNtNwIy0rJi33Lx2auM_J0orLQY5ezr4ZBEseYOhQgSEyn8S92Og7HhTIsLCjy8pBL8FPGDOAaXcKzT8vBosa9s2SBR3LxzE_WTs1PMSoLrrPLOW34Wnk2BVgsXNqpQ5fC68j4pUDJIROCi1lF4qIYL7oEWVk91cIBWwbEXG72IleEEKdtlvaqhMTzIZNPRaiTtl9XnWIsOXkJc3TH2wa4TIuwMezH87bK9_ZamYKkcls4C2GcPrAcAKCid9AOOXFOuBkYVl4lfApEPW3SnW1NeF_qY-GJ7r3T8lszwIv8BSwU_SaiRuB0zkaYaWA2ftxwsRCHfM5YfCRMTGF0NtAst63vGY-VBTY3SqJA3w5ZdP5e2GoZ2bzBNTqt8QPf21HDIU8n3OM3jzqXtrdyuKzHFUoWaxiJxUzxjwIQ5PKHUG7VRCKwIp17LuU7JFAj07Gm2QYQJrhSLty248InSewB3VQ4V7WoXPem9G4Y2D8sw_D3hAgBXOE9guZR_znk_kuyDayNlanq0z3xhZyrliabL9MjiYl1lYYvkedxb_an11vTxdlMiFiPWwAloCh0ydHTUrvORKzl0oE_lJHhtumYGkG-z4U67ssRpGuQh9UirkZix8qyntXMefzOLvGD_8ppyYPUw-iu7_P7ZbNjraONJHdqH1l4YqlVZhyj5XjxtWOkCZdQurydTzGxkT96HwkNaqXTotqJ2T3rosn6ZnfbaTloxKWt7dA-jsIxNitbzfuNK9eXwcXTPzje2O__Vsst2ik_EVtfvXL2m6YzLSzFfWnG2Hxi8skynQ3IMaVzzzY_U9hH8_stoScW2eNsedqQLBPJ2Dz225StO9c8Y53FLbeIzjVJVjEzIaKj4MS-oQTjz7WGUdaM8rqGmnIQgqcCuW6_RNyQ2bpIs7dkTwAODd9kyGYvWsxIX7sxvuWFMDsgHc18hDUgojWmvQepn9ykSLO3Zk8ADhN03oszkNPbpmpKzJN_H8sEeR7I7MnixYk8io32KTjbpEbP8HyEDzTANaa9Samf3KRIs7dmTwAOE3TeizOQ09u6u7XLZYQFjNSZEphG0fLRKkrZjRVZZNxpIGPPfIQPINs1pr1KqZ_cpEizt2ZPAA4TdN6LM5DT265bRPA4zjzYleNJzKztcPB5DgXkXuVN0khNezOxgD64lwhb4u93Sqsmk1znPh0-I9X0tcJS1eHEOP-gzj9u7cuWCT_zEhTh39TjwsXHcQLyXX9WJdHMYqYPRabj73dgqCaTXOc-HT4j1fS1wrYu0sSG5gLyMNHh31Kh8YwB7F2YD6bC0Qjlm8ldSR4yNNJMuAxV-uXvd2CoJpNc5z4dPiPV9LXCVEDSxBHa8cl3-mPFT5vyxHfAoM4ffEfwKT9F2HyENSDWNaa9S6mf3KRIs7dmTwAOE3TeizOQ09t5LlzLleehz2iYTY-xn4zRmxXSxK6aLI0hTXsmthhOpjomvR7b-BW40GT77_v6Xo1378LR0l_ejWhPK5j-Kv3nUBIo2FjV_MZy7HLySFlGJbGAPriJae3i73dwqyaTXOc-HT4j1fS1wi6A4cTpD3XJTTJwz-Igf8ZAu0nO9fLyxutvWsRIXXszsYA-uHGLpOLvdxerJpNc5z4dPiPV9LXCBy7SxOqHM8kWaLbPbTrfxtWYdfINlZybZfQENxjxpL3rAFWOOia9Htv4FbjQZPvv-_pejYHvwtF4GkLEFu7-8lBEwtLmPzPJmp_xzy6Dact8hDUjpzWmvQapn9ykSLO3Zk8ADhN03oszkNPbSVnuy5WBYIzztIzRPzvhxCVayI1bHcDnbdnC33yEDyPWNaa9BzOf5e93YKgmk1znPh0-I9X0tcIbrNLEzvohycCsXPNuDgLk9Wkj38yvPIzQa5DbfIQlIE41pr0DqZ_cpEizt2ZPAA4TdN6LM5DT2xkn7vAgDXzSGPnfznGb-8ZTCw7Oft1OzD22bsuzoz4jCX-lyO93YKgmk1znPh0-I9X0tcJ98NLESF1GM7GAPri-n0blOiKDMTMAFbgKafvvre5BxChhWs7AfbsxCx2FMCFdRjC2GE6mOia9HjMAFbgKafvvre5BxC1hWs66I7sxP5WtzYS4BcwCf0YxIGgepjomrR4zABW4Cmn7730xFc4QctPMSU6sMQJdRjDYdiCmRP6A2qRIs7dmTwAOE3TeizOQ09sjeN_LV11dyI1A3oz_QtmYMSDH53bdEpsJSgs3HNEyJDZzwKbrfJuJCgyj6fwA_8llhRAjxjFF9A-NmJuKYSzF5YR2uU3c2qAdI_i1qFE-DuMr96M1GKmIf_37lg2fXuX1hC65AklkGGO_-vHwiJ-tXYZrplJio5jdaNbR8aJhpe1RPg99JqW9NIr5i3Skm4k4RHoP8Fjk3FB_HC1bIou4EVsJjh0FDKDxDHm_IS8fDKdvHch3_oYxNU1GMN3FPqOWhYKJ6UXm3wcdzbZHmd2hjHnvtUv7ZQ45l7TWyV45uZI4sIgAnDqIR5ndoIx577XTeWUO4BRB9Oz245uMTXo3WDTT9MMLZZv3RqWY3flmv4tVHwwxYzYkcs6Vi8ZEADe4BTPPzc8tI3F1TKx5rDOVCoub75cIirE02v2MPJ4RoKFKxtG2zFzm0DBbvxxNQR6nq_rxOCcfNLJ7NiSggoLj"
    
    //KeyValueStoreKeys
    static let userInfoKeyValueStorageKey = "F1ATV_UserInfoKVSKey"
    static let passwordKeyValueStorageKey = "F1ATV_PasswordKVSKey"
    static let playerSettingsKeyValueStorageKey = "F1ATV_PlayerSettingsKVSKey"

    
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
