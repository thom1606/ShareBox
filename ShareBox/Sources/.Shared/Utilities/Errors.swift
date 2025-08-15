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
    case noGroupCreated
}

enum FileError: String, Error {
    case unknown = "Error 1001: Unknown error occurred"
    case unauthorized = "Error 1002: Unauthorized to upload files"
    case limitReached = "Error 1003: Reached monthly upload limit"
    case noSubscription = "Error 1004: No active subscription"
    case fileNotFound = "Error 1005: File was not found"
    case fileSizeZero = "Error 1006: File size is zero"
    case fileToBig = "Error 1007: File size too big"
    case noUrlProvided = "Error 1008: No pre-signed url available"
    case s3Failed = "Error 1009: Uploading to S3 failed"
}
