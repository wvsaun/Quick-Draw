//
//  Logger.swift
//  QuickDraw
//

import Foundation
import os

enum Log {
    static let network = Logger(subsystem: "com.quickdraw.app", category: "network")
    static let motion = Logger(subsystem: "com.quickdraw.app", category: "motion")
    static let game = Logger(subsystem: "com.quickdraw.app", category: "game")
    static let audio = Logger(subsystem: "com.quickdraw.app", category: "audio")
}
