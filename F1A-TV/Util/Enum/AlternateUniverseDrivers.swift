//
//  AlternateUniverseDrivers.swift
//  F1A-TV
//
//  Created by Noah Fetz on 05.11.21.
//

import Foundation

enum AlternateUniverseDrivers: CaseIterable, Codable {
    case None
    case DanielRicciardo
    case LandoNorris
    case SebastianVettel
    case NicholasLatifi
    case KimiRäikkönen
    case NikitaMazepin
    case PierreGasly
    case SergioPerez
    case FernandoAlonso
    case CharlesLeclerc
    case LanceStroll
    case YukiTsunoda
    case EstebanOcon
    case MaxVerstappen
    case LewisHamilton
    case MickSchumacher
    case CarlosSainz
    case GeorgeRussell
    case ValtteriBottas
    case AntonioGiovinazzi
    
    init() {
        self = .None
    }
    
    static func fromOriginalName(originalName: String) -> AlternateUniverseDrivers {
        for type in AlternateUniverseDrivers.allCases {
            if(type.getOriginalName() == originalName) {
                return type
            }
        }
        return .None
    }
    
    func getOriginalName() -> String {
        switch self {
        case .None:
            return ""
            
        case .DanielRicciardo:
            return "Daniel Ricciardo"
            
        case .LandoNorris:
            return "Lando Norris"
            
        case .SebastianVettel:
            return "Sebastian Vettel"
            
        case .NicholasLatifi:
            return "Nicholas Latifi"
            
        case .KimiRäikkönen:
            return "Kimi Räikkönen"
            
        case .NikitaMazepin:
            return "Nikita Mazepin"
            
        case .PierreGasly:
            return "Pierre Gasly"
            
        case .SergioPerez:
            return "Sergio Perez"
            
        case .FernandoAlonso:
            return "Fernando Alonso"
            
        case .CharlesLeclerc:
            return "Charles Leclerc"
            
        case .LanceStroll:
            return "Lance Stroll"
            
        case .YukiTsunoda:
            return "Yuki Tsunoda"
            
        case .EstebanOcon:
            return "Esteban Ocon"
            
        case .MaxVerstappen:
            return "Max Verstappen"
            
        case .LewisHamilton:
            return "Lewis Hamilton"
            
        case .MickSchumacher:
            return "Mick Schumacher"
            
        case .CarlosSainz:
            return "Carlos Sainz"
            
        case .GeorgeRussell:
            return "George Russell"
            
        case .ValtteriBottas:
            return "Valtteri Bottas"
            
        case .AntonioGiovinazzi:
            return "Antonio Giovinazzi"
        }
    }
    
    func getAlternateName() -> String {
        switch self {
        case .None:
            return ""
            
        case .DanielRicciardo:
            return "Honey Badger"
            
        case .LandoNorris:
            return "twitch.tv/landonorris"
            
        case .SebastianVettel:
            return "Inspector Seb 🧐"
            
        case .NicholasLatifi:
            return "Nicholas GOATifi"
            
        case .KimiRäikkönen:
            return "Bwoah"
            
        case .NikitaMazepin:
            return "Nikita Mazes🅱️in"
            
        case .PierreGasly:
            return "Pierre \"WHAT DID WE JUST DO\" Gasly"
            
        case .SergioPerez:
            return "NoStopper Checo"
            
        case .FernandoAlonso:
            return "Fernando G I G A L O N S O"
            
        case .CharlesLeclerc:
            return "Sharl Leglerg"
            
        case .LanceStroll:
            return "Lance \"Rick\" Stroll"
            
        case .YukiTsunoda:
            return "Yuki **** Tsunoda"
            
        case .EstebanOcon:
            return "Esteban \"Who the hell is that?\" Ocon"
            
        case .MaxVerstappen:
            return "Max Max Max Super Max"
            
        case .LewisHamilton:
            return "Sir Lewis #blessed Hamilton"
            
        case .MickSchumacher:
            return "Mr. Gets a Haas into Q2"
            
        case .CarlosSainz:
            return "Smoooth Operator"
            
        case .GeorgeRussell:
            return "Mr. Saturday"
            
        case .ValtteriBottas:
            return "\"Valtteri it's James\" BottASS's Engine Shop"
            
        case .AntonioGiovinazzi:
            return "Italian Jesus"
        }
    }
}
