//
//  AuthDataLoadedProtocol.swift
//  F1A-TV
//
//  Created by Noah Fetz on 14.04.21.
//

import Foundation

protocol AuthDataLoadedProtocol {
    func didLoadAuthData(authResult: AuthResultDto)
    func didLoadToken(tokenResult: TokenResultDto)
}
