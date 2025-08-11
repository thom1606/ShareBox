//
//  Errors.swift
//  ShareBox
//
//  Created by Thom van den Broek on 14/07/2025.
//

import Foundation

enum ShareBoxError: Error {
    case failedExecute(String)
    case helperNotInstalled
    case helperNotRunning
    case noHelperInDevelopment
    case fileNotFound
    case fileNotUploaded
}
