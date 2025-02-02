//
//  CreationTask.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 21/09/2021.
//

import Foundation

/// `CreationTask` Prepares the server for a file upload.
/// The server will return a path to upload to.
final class CreationTask: IdentifiableTask {
    
    var completionHandler: () -> Void
    
    // MARK: - IdentifiableTask
    
    var id: UUID {
        metaData.id
    }
    
    weak var progressDelegate: ProgressDelegate?
    let metaData: UploadMetadata
    
    private let api: TUSAPI
    private let files: Files
    private let chunkSize: Int?
    private var didCancel: Bool = false
    private weak var sessionTask: URLSessionDataTask?

    init(metaData: UploadMetadata, api: TUSAPI, files: Files, chunkSize: Int? = nil, completionHandler: @escaping () -> Void) throws {
        self.metaData = metaData
        self.api = api
        self.files = files
        self.chunkSize = chunkSize
        self.completionHandler = completionHandler
    }
    
    func run(completed: @escaping TaskCompletion) {
        
        if didCancel { return }
        sessionTask = api.create(metaData: metaData) { [weak self] result in
            guard let self = self else { self?.completionHandler()
                return
                
            }
            // File is created remotely. Now start first datatask.
            
            // Getting rid of self. in this closure
            let metaData = self.metaData
            let files = self.files
            let chunkSize = self.chunkSize
            let api = self.api
            let progressDelegate = self.progressDelegate

            do {
                let remoteDestination = try result.get()
                metaData.remoteDestination = remoteDestination
                try files.encodeAndStore(metaData: metaData)
                let task: UploadDataTask
                if let chunkSize = chunkSize {
                    let newRange = 0..<min(chunkSize, metaData.size)
                    task = try UploadDataTask(api: api, metaData: metaData, files: files, range: newRange, completionHandler: completionHandler)
                } else {
                    task = try UploadDataTask(api: api, metaData: metaData, files: files, completionHandler: completionHandler)
                }
                task.progressDelegate = progressDelegate
                if self.didCancel {
                    self.completionHandler()
                    completed(.failure(TUSClientError.couldNotCreateFileOnServer))
                } else {
                    completed(.success([task]))
                }
            } catch let error as TUSClientError {
                self.completionHandler()
                completed(.failure(error))
            } catch {
                self.completionHandler()
                completed(.failure(TUSClientError.couldNotCreateFileOnServer))
            }
           
            
        }
    }
    
    func cancel() {
        didCancel = true
        sessionTask?.cancel()
    }
}
