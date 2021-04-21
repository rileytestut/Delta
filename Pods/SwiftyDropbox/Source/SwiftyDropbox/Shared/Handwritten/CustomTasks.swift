///
/// Copyright (c) 2016 Dropbox, Inc. All rights reserved.
///

import Foundation

open class BatchUploadTask {
    let uploadData: BatchUploadData

    public init(uploadData: BatchUploadData) {
        self.uploadData = uploadData
        
    }
    
    public func cancel() {
        self.uploadData.cancel = true
//        self.uploadData.taskStorage.cancelAllTasks()
    }
}

