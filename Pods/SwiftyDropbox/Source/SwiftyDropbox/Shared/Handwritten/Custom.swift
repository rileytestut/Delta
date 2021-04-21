///
/// Copyright (c) 2016 Dropbox, Inc. All rights reserved.
///

import Foundation

/// Special custom response block for batch upload. The first argument is a mapping of client-side NSURLs to batch
/// upload result entries (each of which indicates the success / failure of the upload for the corresponding file). This
/// object will be nonnull if the final call to `/upload_session/finish_batch/check` is successful. The second argument
/// is the route-specific error from `/upload_session/finish_batch/check`, which is generally not able to be handled at
/// runtime, but instead should be used for debugging purposes. This object will be nonnull if there is a route-specific
/// error from the call to `/upload_session/finish_batch/check`. The third argument is the general request error from
/// `/upload_session/finish_batch/check`. This object will be nonnull if there is a request error from the call to
/// `/upload_session/finish_batch/check`. The fourth argument is a mapping of client-side NSURLs to general request
/// errors, which occured during the upload of the corresponding file.
public typealias BatchUploadResponseBlock = ([URL: Files.UploadSessionFinishBatchResultEntry]?, CallError<Async.PollError>?, [URL: CallError<Async.PollError>]) -> Void

public typealias ProgressBlock = (Progress) -> Void

///
/// Stores data for a particular batch upload attempt.
///
open class BatchUploadData {
    /// The queue on which most response handling is performed.
    let queue: DispatchQueue
    /// The dispatch group that pairs upload requests with upload responses so that we can wait for all request/response
    /// pairs to complete before batch committing. In this way, we can start many upload requests (for files under the chunk
    /// limit), without waiting for the corresponding response.
    let uploadGroup = DispatchGroup()
    /// A client-supplied parameter that maps the file urls of the files to upload to the corresponding commit info objects.
    let fileUrlsToCommitInfo: [URL: Files.CommitInfo]
    /// Mapping of urls for files that were unsuccessfully uploaded to any request errors that were encounted.
    var fileUrlsToRequestErrors: [URL: CallError<Async.PollError>]
    /// List of finish args (which include commit info, cursor, etc.) which the SDK maintains and passes to
    /// `upload_session/finish_batch`.
    var finishArgs: [Files.UploadSessionFinishArg]
    /// The progress block that is periodically executed once a file upload is complete.
    let progressBlock: ProgressBlock?
    /// The response block that is executed once all file uploads and the final batch commit is complete.
    let responseBlock: BatchUploadResponseBlock
    /// The total size of all the files to upload. Used to return progress data to the client.
    var totalUploadProgress: Progress?
    /// The flag that determines whether upload continues or not.
    var cancel: Bool = false
    /// The container object that stores all upload / download task objects for cancelling.
//    let taskStorage: DBTasksStorage!
    
    public init(fileCommitInfo fileUrlsToCommitInfo: [URL: Files.CommitInfo], progressBlock: ProgressBlock?, responseBlock: @escaping BatchUploadResponseBlock, queue: DispatchQueue) {
        // we specifiy a custom queue so that the main thread is not blocked
        self.queue = queue
        // we want to make sure all of our file data has been uploaded
        // before we make our final batch commit call to `/upload_session/finish_batch`,
        // but we also don't want to wait for each response before making a
        // succeeding upload call, so we used dispatch groups to wait for all upload
        // calls to return before making our final batch commit call
        self.fileUrlsToCommitInfo = fileUrlsToCommitInfo
        self.fileUrlsToRequestErrors = [:]
        self.finishArgs = []
        self.progressBlock = progressBlock
        self.responseBlock = responseBlock
        self.totalUploadProgress = nil
//        self.taskStorage = DBTasksStorage()
        
    }
}
