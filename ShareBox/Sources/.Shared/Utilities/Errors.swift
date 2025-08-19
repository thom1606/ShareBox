//
//  Errors.swift
//  ShareBox
//
//  Created by Thom van den Broek on 14/07/2025.
//

import Foundation

enum PlatformError: String, Error {
    case unknown = "Error 1001: Unknown error occurred"
    case unauthorized = "Error 1002: Unauthorized to upload files"
    case limitReached = "Error 1003: Reached monthly upload limit"
    case noSubscription = "Error 1004: No active subscription"
    case groupNotFound = "Error 1005: Box was not found"
    case fileNotFound = "Error 1006: File was not found"
    case fileSizeZero = "Error 1007: File size is zero"
    case fileToBig = "Error 1008: File size too big"
    case noUrlProvided = "Error 1009: No pre-signed url available"
    case s3Failed = "Error 1010: Uploading to S3 failed"
    case hasExistingGroup = "Error 1011: Alreay a box open"
    case groupLimitReached = "Error 1012: Reached maximum number of active boxes"
}

enum ShareBoxError: Error, Equatable {
    case failedExecute(String)
    case appNotRunning
    case fileNotFound
    case fileNotUploaded
    case failed

    case noGroupCreated
    case hasExistingGroup
}

enum FileError: String, Error {
    case unknown = "Error 1001: Unknown error occurred"
    case unauthorized = "Error 1002: Unauthorized to upload files"
    case limitReached = "Error 1003: Reached monthly upload limit"
    case noSubscription = "Error 1004: No active subscription"
    case groupNotFound = "Error 1005: Box was not found"
    case fileNotFound = "Error 1006: File was not found"
    case fileSizeZero = "Error 1007: File size is zero"
    case fileToBig = "Error 1008: File size too big"
    case noUrlProvided = "Error 1009: No pre-signed url available"
    case s3Failed = "Error 1010: Uploading to S3 failed"
}
