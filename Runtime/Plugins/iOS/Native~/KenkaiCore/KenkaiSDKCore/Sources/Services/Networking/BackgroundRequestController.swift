//
//  BackgroundRequestController.swift
//
//
//  Created by khushbu on 03/10/23.
//

import Foundation
import UIKit

private final class BackgroundRequest {
    let task: URLSessionTask
    var data: Data?
    let completion: BackgroundRequestController.Completion
    var errorOccurred: Bool

    init(task: URLSessionTask, completion: @escaping BackgroundRequestController.Completion) {
        self.task = task
        self.completion = completion
        self.errorOccurred = false
    }
}

class BackgroundRequestController: NSObject {
    
    typealias Completion = (Result<Data?, Error>) -> Void

    public enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
    }
    
    public static let shared = BackgroundRequestController()

    private let backgroundRequestsQueue = DispatchQueue(label: "thread-safe-obj", attributes: .concurrent)
    private var backgroundRequests = [BackgroundRequest]()
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: "BackgroundRequestController.configuration")
        configuration.allowsCellularAccess = true
        configuration.httpShouldSetCookies = true
        configuration.httpShouldUsePipelining = true
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.timeoutIntervalForRequest = 60.0
        configuration.sharedContainerIdentifier = "BackgroundRequestController.sharedContainer"
        //  configuration.urlCache = URLCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil)
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    override public init() {}

    public func request(url: URL, httpMethod: HTTPMethod, params: Any?, completionHandler: @escaping Completion) {
        let urlRequest = urlRequest(url: url, httpMethod: httpMethod, params: params)
        let task = session.dataTask(with: urlRequest)
        backgroundRequestsQueue.async(flags: .barrier) {
            let request = BackgroundRequest(task: task, completion: completionHandler)
            self.backgroundRequests.append(request)
        }
        task.resume()
    }

    private func urlRequest(url: URL, httpMethod: HTTPMethod, params: Any?) -> URLRequest {
        var urlRequest = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 3.0 * 1000)
        urlRequest.httpMethod = httpMethod.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(CoreConstants.shared.sdkKey, forHTTPHeaderField: "Authorization")
        if let params = params, let httpBody = try? JSONSerialization.data(withJSONObject: params, options: .prettyPrinted) {
            urlRequest.httpBody = httpBody
        }
        return urlRequest
    }
}

extension BackgroundRequestController: URLSessionDelegate {
    func urlSession(_: URLSession, didBecomeInvalidWithError error: Error?) {
        print("Session didBecomeInvalidWithError: \(error?.localizedDescription ?? "No error")")
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession _: URLSession) {
        // This method is called when all tasks have been completed for the background session.
        // Perform any necessary cleanup or UI updates.
        print("All tasks in the background session are complete.")
        backgroundRequestsQueue.async(flags: .barrier) {
            self.backgroundRequests.forEach { request in
                request.completion(.success(nil))
            }
            self.backgroundRequests.removeAll()
        }
    }

    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // This method is called when a task completes (both successfully or with an error).
        // Handle task completion here.
        print("Task \(task.originalRequest?.url?.absoluteString ?? "-") completed with error: \(error?.localizedDescription ?? "No error")")
        backgroundRequestsQueue.async(flags: .barrier) {
            if let index = self.backgroundRequests.firstIndex(where: { $0.task.taskIdentifier == task.taskIdentifier }) {
                let request = self.backgroundRequests[index]
                if let error = error {
                    ExceptionManager.throwAPIFailException(apiName: task.originalRequest?.url?.absoluteString ?? "", response: task.response as? HTTPURLResponse, responseBody: nil)
                    request.completion(.failure(error))
                } else {
                    
                    if request.errorOccurred {
                        let customError = NSError(domain: task.originalRequest?.url?.absoluteString ?? "-", code: 0, userInfo: [NSLocalizedDescriptionKey: "IngestAPIResponseError"])
                        request.completion(.failure(customError))
                        request.errorOccurred = false
                    }else{
                        request.completion(.success(request.data))
                    }
                }
                self.backgroundRequests.remove(at: index)
            }
        }
    }
}

extension BackgroundRequestController: URLSessionDataDelegate {
    func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        print("Task \(dataTask.originalRequest?.url?.absoluteString ?? "-") didReceive data: \(String(data: data, encoding: .utf8) ?? "-")")
        backgroundRequestsQueue.async(flags: .barrier) {
            if let index = self.backgroundRequests.firstIndex(where: { $0.task.taskIdentifier == dataTask.taskIdentifier }) {
                if self.backgroundRequests[index].data == nil {
                    self.backgroundRequests[index].data = data
                } else {
                    self.backgroundRequests[index].data! += data
                }
                if #available(iOS 13.0, *) {
                                        
                    if let url = dataTask.originalRequest?.url,
                       url.absoluteString.contains("ingest/log"),
                       let _ = String(data: data, encoding: .utf8) {
                        // Set error flag if data is received
                        self.backgroundRequests[index].errorOccurred = true
                        do {
                            if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                               let dataValue = jsonObject["data"] as? String {
                                    WorkerCaller.performSanitizedUpload(indexToRemove: Int(dataValue))
                            } else {
                                print("Failed to parse 'data' value.")
                            }
                        } catch {
                            print("Error parsing JSON:", error)
                        }
                    }
                }
            }
        }
    }
}
